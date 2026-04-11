# N E M E S I S — Raw Findings

## Scope
- Repo: `project-handles-v6`
- Solidity files in scope:
  - `src/JBProjectHandles.sol`
  - `src/interfaces/IJBProjectHandles.sol`
  - `script/Deploy.s.sol`
  - `script/helpers/ProjectHandlesDeploymentLib.sol`

## Phase 0 — Nemesis Recon

**Language:** Solidity 0.8.28

**Attack goals:**
1. Break setter isolation so one address can overwrite another setter’s ENS record.
2. Break verification correctness so `handleOf` returns a false positive or misses a valid handle.
3. Abuse the trusted forwarder boundary to spoof `_msgSender()` outside the intended ERC2771 path.
4. Corrupt deployment wiring so runtime meta-tx semantics differ from the rest of `core-v6`.

**Novel code:**
- `src/JBProjectHandles.sol` — custom ENS name-part validation, handle formatting, and EIP-137 namehash plumbing.
- `script/Deploy.s.sol` — repo-specific deployment wiring from `core-v6` into this runtime.

**Value stores + coupling hypothesis:**
- `_ensNamePartsOf` holds the only mutable project-handle state.
  - Outflows: none.
  - Suspected coupled state: effective sender identity, ENS resolver text record, formatted handle, computed namehash.
- Deployment `core.trustedForwarder`.
  - Outflows: constructor argument into `JBProjectHandles`.
  - Suspected coupled state: ERC2771 `_msgSender()` behavior after deployment.

**Complex paths:**
- `setEnsNamePartsFor` -> `_msgSender()` -> storage write -> later `handleOf` -> `_namehash` -> `ENS_REGISTRY.resolver()` -> `ITextResolver.text()`.
- `Deploy.run` -> `CoreDeploymentLib.getDeployment()` -> deployment JSON -> `deploy()` -> `new JBProjectHandles(core.trustedForwarder)`.

**Priority order:**
1. `JBProjectHandles.setEnsNamePartsFor` + `handleOf` + `_namehash`
2. ERC2771 forwarder boundary
3. Sphinx/core deployment wiring

## Phase 1 — Unified Nemesis Map
| Function | Writes A | Writes B | A↔B Pair | Sync Status |
|----------|----------|----------|----------|-------------|
| `setEnsNamePartsFor` | `_ensNamePartsOf[...]` | effective setter key implicit in slot selection | storage ↔ `_msgSender()` | synced |
| `handleOf` | none | none | stored parts ↔ ENS text record | checked on read |
| `Deploy.deploy` | deployment side effect | constructor trusted forwarder binding | script config ↔ runtime meta-tx semantics | synced |

## Pass 1 — Feynman Raw Suspects
1. **Raw suspect:** `setEnsNamePartsFor` assumes provided ENS labels are already canonical ENS labels.
   - Evidence: only empty-string and ASCII-dot validation before storage.
   - Downstream path: `_namehash` hashes raw label bytes with no normalization.
   - Candidate consequence: valid ENS names supplied in non-canonical form may never verify.

2. **Cleared suspect:** non-forwarder calldata suffix spoofing.
   - Cleared by OpenZeppelin `isTrustedForwarder(msg.sender)` gate.

3. **Cleared suspect:** cross-setter pollution.
   - Cleared by sole write path to `_ensNamePartsOf[...][_msgSender()]`.

4. **Cleared suspect:** deployment script miswires an arbitrary forwarder.
   - Cleared by direct load from `@bananapus/core-v6` deployment JSON for the current chain.

## Pass 2 — State Raw Output
- Coupled pairs mapped:
  - storage slot ↔ effective sender
  - stored parts ↔ ENS text record for computed node
  - deployment forwarder input ↔ runtime `_msgSender()` semantics
- No mutation gaps found.
- No parallel-path mismatch found between direct calls and ERC2771-forwarded calls.
- No masking code found.
- Delta from Pass 2: none beyond confirming Pass 1’s raw suspect is not a state-desync issue.

## Convergence
- Full Pass 1 (Feynman): 1 raw suspect
- Full Pass 2 (State): 0 new findings, 0 new coupled gaps
- Converged after Pass 2. No targeted Pass 3/4 delta required.

## Raw Finding Set
| ID | Source | Title | Severity | Status |
|----|--------|-------|----------|--------|
| NM-RAW-001 | Feynman-only | Non-normalized ENS labels can be stored but later fail verification | LOW | verified true positive |
