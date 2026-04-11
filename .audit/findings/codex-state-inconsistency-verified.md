# State Inconsistency Audit — Verified Findings

## Coupled State Dependency Map
| Pair | Coupled State | Invariant | Mutation points |
|------|---------------|-----------|-----------------|
| SI-P1 | `_ensNamePartsOf[chainId][projectId][setter]` ↔ `_msgSender()`-selected setter key | A caller may only mutate the record stored under its own effective sender identity | `setEnsNamePartsFor` |
| SI-P2 | Stored ENS parts ↔ ENS text record `juicebox` for the computed node | `handleOf` may return a non-empty handle only when the text record equals `chainId:projectId` for the same node | `setEnsNamePartsFor`, `handleOf`, `_namehash` |
| SI-P3 | Deployment input `core.trustedForwarder` ↔ runtime `_msgSender()` behavior | The deployed forwarder address must match the core deployment’s forwarder to preserve consistent meta-tx semantics | `Deploy.run`, `Deploy.deploy` |

## Mutation Matrix
| State Variable | Mutating Function | Type of Mutation | Updates Coupled State? |
|----------------|-------------------|------------------|------------------------|
| `_ensNamePartsOf[chainId][projectId][_msgSender()]` | `setEnsNamePartsFor` | overwrite | Yes, the key is derived from `_msgSender()` in the same operation |
| Stored ENS parts | no other path | n/a | n/a |
| Deployment record `core` | `Deploy.run` | assignment | Yes, used immediately by `deploy()` |

## Parallel Path Comparison
| Coupled State | Path A | Path B | Result |
|---------------|--------|--------|--------|
| Setter-scoped storage writes | direct call to `setEnsNamePartsFor` | trusted-forwarded call to `setEnsNamePartsFor` | Both remain isolated by effective `_msgSender()` |
| Stored handle verification | no parts set | parts set + ENS lookup | Empty path and verified path are consistent; no stale cached state exists |
| Deployment wiring | first deployment | re-run after deployment | `_isDeployed` prevents duplicate deployment at same deterministic address |

## Verification Summary
| ID | Coupled Pair | Breaking Op | Original Severity | Verdict | Final Severity |
|----|-------------|-------------|-------------------|---------|----------------|
| - | - | - | - | No verified state inconsistency findings | - |

## Verified Findings
- None.

## False Positives Eliminated
- No missing coupled update exists for setter isolation. The only mutable storage is keyed directly by `_msgSender()`, so there is no parallel path where caller A can write caller B’s slot.
- No hidden stale-state bug exists between stored ENS parts and verification output. `handleOf` performs fresh ENS registry and resolver reads every time and does not cache derived verification state on-chain.
- No deployment-state mismatch was found. `Deploy` sources the trusted forwarder from `@bananapus/core-v6` deployment JSON for the current chain and passes it directly into the constructor.

## Summary
- Coupled state pairs mapped: 3
- Mutation paths analyzed: 3
- Raw findings (pre-verification): 0
- After verification: 0 TRUE POSITIVE | 0 FALSE POSITIVE
- Final: 0 CRITICAL | 0 HIGH | 0 MEDIUM | 0 LOW
