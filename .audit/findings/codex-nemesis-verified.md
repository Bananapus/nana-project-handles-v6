# N E M E S I S — Verified Findings

## Scope
- Language: Solidity 0.8.28
- Modules analyzed:
  - `src/JBProjectHandles.sol`
  - `src/interfaces/IJBProjectHandles.sol`
  - `script/Deploy.s.sol`
  - `script/helpers/ProjectHandlesDeploymentLib.sol`
- Functions analyzed: 15
- Coupled state pairs mapped: 3
- Mutation paths traced: 3
- Nemesis loop iterations: 2 passes total (`Feynman -> State`)

## Nemesis Map (Phase 1 Cross-Reference)
| Function | Writes A | Writes B | A↔B Pair | Sync Status |
|----------|----------|----------|----------|-------------|
| `setEnsNamePartsFor` | `_ensNamePartsOf[chainId][projectId][_msgSender()]` | sender-scoped slot selection | storage ↔ effective sender identity | `SYNCED` |
| `handleOf` | none | none | stored parts ↔ ENS text record | `READ-TIME CHECK` |
| `Deploy.deploy` | constructor side effect | runtime forwarder binding | deployment forwarder ↔ `_msgSender()` semantics | `SYNCED` |

## Verification Summary
| ID | Source | Coupled Pair | Breaking Op | Severity | Verdict |
|----|--------|-------------|-------------|----------|---------|
| NM-001 | Feynman-only | stored ENS parts ↔ canonical ENS node | `setEnsNamePartsFor()` / `_namehash()` | LOW | TRUE POS |

## Verified Findings (TRUE POSITIVES only)

### Finding NM-001: Non-canonical ENS labels break verification correctness
**Severity:** LOW
**Source:** Feynman-only
**Verification:** Code trace

**Coupled Pair:** Stored ENS parts ↔ canonical ENS node used by the ENS registry
**Invariant:** The bytes accepted for storage must correspond to the same canonical ENS node that the resolver and text record were registered under.

**Feynman Question that exposed it:**
> What does this function assume about external data it receives, and is that assumption enforced before the data becomes part of the verification path?

**State Mapper gap that confirmed it:**
> The state pass confirmed there is no secondary normalization or reconciliation path between stored parts and the node later queried in `handleOf`.

**Breaking Operation:** `setEnsNamePartsFor()` at [src/JBProjectHandles.sol:61](/Users/jango/Documents/jb/v6/evm/project-handles-v6/src/JBProjectHandles.sol#L61)
- Modifies State A: stores arbitrary non-empty, no-ASCII-dot labels under `_ensNamePartsOf`.
- Does NOT update State B: there is no canonicalization step to align stored bytes with ENS-normalized label bytes before `_namehash()` later queries the registry.

**Trigger Sequence:**
1. A setter owns `alice.eth` and sets its ENS `juicebox` text record to `1:5`.
2. The setter calls `setEnsNamePartsFor(1, 5, ["ALICE"])`.
3. The contract stores `["ALICE"]` because uppercase is not rejected.
4. A client calls `handleOf(1, 5, setter)`.
5. `_namehash()` hashes `ALICE` verbatim, so `ENS_REGISTRY.resolver()` is queried for a different node than canonical `alice.eth`.
6. `handleOf` returns `""` even though the intended ENS text record matches.

**Consequence:**
- Breaks the repo’s stated verification-correctness goal for non-canonical label input.
- Causes self-inflicted handle resolution failure until the setter overwrites the record with canonical labels.

**Verification Evidence:**
- Validation only rejects empties and ASCII dots at [src/JBProjectHandles.sol:68](/Users/jango/Documents/jb/v6/evm/project-handles-v6/src/JBProjectHandles.sol#L68).
- `_namehash()` hashes raw bytes at [src/JBProjectHandles.sol:181](/Users/jango/Documents/jb/v6/evm/project-handles-v6/src/JBProjectHandles.sol#L181).
- No repo function lowercases or normalizes stored labels before lookup.
- Existing tests cover empty labels, ASCII dots, matching text records, mismatches, and ERC2771 behavior, but not uppercase or other non-canonical labels.

**Fix:**
```solidity
// Enforce canonical ENS input before storage, for example by:
// - restricting labels to a canonical lowercase subset, or
// - normalizing labels with ENS-compatible normalization before hashing/storage.
```

## Feedback Loop Discoveries
- None. The state pass found no additional coupled-state gaps or parallel-path mismatches beyond the Feynman canonicalization issue.

## False Positives Eliminated
- **ERC2771 spoofing by non-forwarders:** eliminated by the `isTrustedForwarder(msg.sender)` gate in OpenZeppelin’s `ERC2771Context`.
- **Cross-setter record corruption:** eliminated because the only write path stores under `_msgSender()`, never a caller-supplied setter.
- **Deployment wiring bug:** eliminated by tracing `Deploy.run()` into `CoreDeploymentLib.getDeployment()` and confirming the trusted forwarder comes directly from the current-chain `core-v6` deployment artifact.
- **Resolver revert handling:** reviewed but not reported because the repo docs already model ENS availability/revert behavior as an accepted external dependency risk, not a broken internal invariant.

## Downgraded Findings
- None.

## Summary
- Total functions analyzed: 15
- Coupled state pairs mapped: 3
- Nemesis loop iterations: 2
- Raw findings (pre-verification): 0 C | 0 H | 0 M | 1 L
- Feedback loop discoveries: 0
- After verification: 1 TRUE POSITIVE | 0 FALSE POSITIVE | 0 DOWNGRADED
- Final: 0 CRITICAL | 0 HIGH | 0 MEDIUM | 1 LOW
