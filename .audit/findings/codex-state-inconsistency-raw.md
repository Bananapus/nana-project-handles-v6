# State Inconsistency Audit — Raw Analysis

## Coupled State Dependency Map

| Pair | Invariant | Mutation points |
|---|---|---|
| `_ensNamePartsOf[chainId][projectId][setter]` ↔ `_msgSender()` namespace | A caller may only mutate the slot keyed by its effective sender | `setEnsNamePartsFor` |
| Stored `ensNameParts` ↔ derived `handle` / `namehash` | Formatting and hashing must reflect the exact stored label ordering | `setEnsNamePartsFor`, `handleOf`, `_formatHandle`, `_namehash` |
| Derived ENS node ↔ ENS text record `"{chainId}:{projectId}"` | `handleOf` may return non-empty only if the resolver text record matches the project binding | `handleOf` |
| Deployment `core.trustedForwarder` ↔ runtime `_msgSender()` trust boundary | Constructor wiring must match the intended forwarder singleton | `run`, `deploy` |

## Mutation Matrix

| State Variable / Trust Root | Mutating Function | Updates Coupled State? |
|---|---|---|
| `_ensNamePartsOf[...]` | `setEnsNamePartsFor` | Yes — key is scoped by `_msgSender()` |
| derived `handle` | none stored | N/A — recomputed on read |
| derived `namehash` | none stored | N/A — recomputed on read |
| `core` deployment cache | `run` | Yes — then consumed by `deploy` |

## Parallel Path Comparison

| Outcome | Path A | Path B | Result |
|---|---|---|---|
| Setter-scoped write | direct call | ERC-2771 forwarded call | both resolve to the correct setter namespace under current OZ logic |
| Verification miss | no stored parts | zero resolver | both return `""` |
| Verification miss | text mismatch | wrong chain id | both return `""` |
| Verification miss | resolver revert | N/A | this diverges by reverting instead of returning `""` |

## Raw State Findings

No confirmed state desynchronization bugs were found in storage mutation paths. The only structural divergence was the resolver-revert behavior in `handleOf`, which is better classified as an availability issue than a coupled-state corruption issue.
