# State Inconsistency Audit — Verified Findings

## Coupled State Dependency Map

| Pair | Invariant |
|---|---|
| `_ensNamePartsOf[chainId][projectId][setter]` ↔ `_msgSender()` namespace | effective sender can only write its own setter slot |
| Stored `ensNameParts` ↔ derived `handle` / `namehash` | formatting and hashing must preserve stored label order |
| Derived ENS node ↔ ENS text record `"{chainId}:{projectId}"` | verified output is non-empty only on an exact round-trip match |
| Deployment `core.trustedForwarder` ↔ runtime `_msgSender()` trust boundary | deployment wiring must preserve the intended forwarder singleton |

## Mutation Matrix

| State Variable | Mutating Function | Updates Coupled State? |
|---|---|---|
| `_ensNamePartsOf[...]` | `setEnsNamePartsFor` | Yes |
| `core` | `run` | Yes |

## Parallel Path Comparison

| Coupled State | Path A | Path B | Result |
|---|---|---|---|
| setter isolation | direct sender | forwarded sender | consistent |
| verified-handle miss | missing record | zero resolver / text mismatch | consistent empty-string behavior except resolver revert |

## Verification Summary
| ID | Coupled Pair | Breaking Op | Original Severity | Verdict | Final Severity |
|---|---|---|---|---|---|

No verified state inconsistency findings.

## False Positives Eliminated
- Cross-setter corruption via normal calls: eliminated. The only storage write is `_ensNamePartsOf[chainId][projectId][_msgSender()]`, and the ERC-2771 tests confirm correct namespacing for trusted-forwarder and non-forwarder paths.
- Namehash / format drift: eliminated. `_formatHandle` and `_namehash` use the same label ordering, and `test_namehash_matchesKnownValues()` confirms the EIP-137 computation used by the contract.
- Deployment-time state gap: eliminated as a runtime state inconsistency issue; the script concern is operational, not a persistent storage desync in the deployed contract.

## Summary
- Coupled state pairs mapped: 4
- Mutation paths analyzed: 4
- Raw findings: 0 state-desync bugs
- After verification: 0 TRUE POSITIVE, 0 FALSE POSITIVE state findings
- Final: 0 CRITICAL, 0 HIGH, 0 MEDIUM, 0 LOW
