# N E M E S I S — Raw Repo-Level Audit

## Scope
- Repo: `project-handles-v6`
- Solidity files analyzed: `src/JBProjectHandles.sol`, `src/interfaces/IJBProjectHandles.sol`, `script/Deploy.s.sol`, `script/helpers/ProjectHandlesDeploymentLib.sol`
- Audit mode: one integrated repo audit, not per-file loops

## Phase 0 — Nemesis Recon

**Language:** Solidity 0.8.28

**Attack Goals**
1. Corrupt another setter's record by confusing `_msgSender()` under ERC-2771.
2. Return a non-empty handle without the correct ENS `juicebox` round-trip.
3. Break the verification surface so clients cannot safely read handles.

**Novel Code**
- `JBProjectHandles._namehash` / `_formatHandle` — custom label-ordering logic.
- `JBProjectHandles.handleOf` — external ENS dependency boundary.
- `Deploy.run/deploy` — runtime trusted-forwarder wiring from another repo's deployment artifacts.

**Value / Trust Stores + Initial Coupling Hypothesis**
- `_ensNamePartsOf` holds candidate handle state.
  - Outflows: read by `ensNamePartsOf`, `handleOf`.
  - Suspected coupled state: effective sender namespace, derived handle string, derived ENS node, ENS text record binding.
- `core.trustedForwarder` holds deployment-time trust for meta-tx sender derivation.
  - Outflows: constructor arg into `JBProjectHandles`.
  - Suspected coupled state: `_msgSender()` semantics at runtime.

**Complex Paths**
- Setter write -> later verification through ENS registry and resolver.
- Deployment artifact read -> trusted forwarder injection -> all future setter isolation.

**Priority Order**
1. `handleOf`
2. `setEnsNamePartsFor`
3. `run` / `deploy`

## Phase 1 — Unified Nemesis Map

| Function | Writes A | Writes B | A↔B Pair | Sync Status |
|---|---|---|---|---|
| `setEnsNamePartsFor` | `_ensNamePartsOf` | `_msgSender()`-scoped namespace | storage↔setter | synced |
| `handleOf` | none | none | stored parts↔ENS text record | read-only verification |
| `run` | `core` | deployment inputs | deploy cache↔constructor args | synced |
| `deploy` | deployment side effect | constructor arg | trusted forwarder↔runtime sender model | suspect until verified |

## Pass 1 — Feynman (full)

### New findings / suspects
- `FF-R1` low: resolver revert propagates through `handleOf`.
- `FF-R2` low suspect: `deploy()` assumes `run()` already initialized `core`.
- `FF-R3` low suspect: raw-label storage without normalization.

## Pass 2 — State Inconsistency (full, enriched)

### New coupled pairs
- No additional writable storage pairs beyond setter namespace, derived handle/namehash, ENS text-record binding, and deployment forwarder trust.

### Gaps
- No storage mutation gaps found in `_ensNamePartsOf`.
- Divergence noted in verification miss handling: missing/mismatched data returns `""`, but resolver revert bubbles.

## Pass 3 — Feynman Re-Interrogation (targeted)

### Delta on Pass 2 items
- Resolver-revert path is real and reachable. Root cause: `ITextResolver.text(...)` is not wrapped in `try/catch`.
- No downstream forged verification discovered; impact remains availability-only.
- No root-cause evidence that `deploy()` is unsafe in the intended Sphinx workflow.

## Pass 4 — State Re-Analysis (targeted)

### Delta on Pass 3 items
- No new state couplings or mutation paths discovered.
- No hidden reconciliation or lazy-sync patterns exist; the contract is effectively stateless apart from `_ensNamePartsOf`.

## Convergence
- Converged after 4 passes.
- Last pass produced no new findings, coupled pairs, or mutation paths.

## Raw Finding Set

### NM-R1: Resolver Revert Bubbles Through Verification
- Severity: LOW
- Discovery path: Feynman-only, confirmed in targeted re-pass
- Affected path: `handleOf` -> `ENS_REGISTRY.resolver` -> `ITextResolver.text`

### NM-R2: Direct `deploy()` invocation without `run()`
- Severity: LOW
- Discovery path: Feynman-only
- Status: likely false positive / operational-only pending verification

### NM-R3: Non-normalized labels stored unchanged
- Severity: LOW
- Discovery path: Feynman-only
- Status: likely accepted-by-design pending verification
