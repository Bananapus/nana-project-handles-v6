# N E M E S I S — Verified Findings

## Scope
- Language: Solidity 0.8.28
- Modules analyzed: `src/JBProjectHandles.sol`, `src/interfaces/IJBProjectHandles.sol`, `script/Deploy.s.sol`, `script/helpers/ProjectHandlesDeploymentLib.sol`
- Functions analyzed: 14 executable functions across repo code, plus the interface surface
- Coupled state pairs mapped: 4
- Mutation paths traced: 4
- Nemesis loop iterations: 4 passes total (`Feynman -> State -> Feynman -> State`)

## Nemesis Map (Phase 1 Cross-Reference)

| Function | Writes A | Writes B | A↔B Pair | Sync Status |
|---|---|---|---|---|
| `setEnsNamePartsFor` | `_ensNamePartsOf` | setter namespace via `_msgSender()` | storage↔setter | synced |
| `handleOf` | none | none | stored parts↔ENS text record | read-only verification |
| `run` | `core` | constructor input cache | deployment cache↔forwarder wiring | synced |
| `deploy` | deployment side effect | runtime trust root | trusted forwarder↔ERC-2771 sender model | verified operationally safe in intended flow |

## Verification Summary
| ID | Source | Coupled Pair | Breaking Op | Severity | Verdict |
|---|---|---|---|---|---|
| NM-001 | Feynman-only | derived ENS node ↔ resolver text read | `handleOf()` | LOW | TRUE POSITIVE |

## Verified Findings

### Finding NM-001: Resolver Reverts Break the "Verified Or Empty" Read Path
**Severity:** LOW  
**Source:** Feynman-only  
**Verification:** Hybrid

**Coupled Pair:** derived ENS node ↔ resolver text read result  
**Invariant:** verification failures should degrade to an empty string rather than throwing, otherwise the read surface is not consistently fail-closed.

**Feynman Question that exposed it:**
> What happens on the error path of the external resolver call inside `handleOf`?

**State Mapper gap that confirmed it:**
> Parallel-path comparison showed that "no resolver" and "text mismatch" both return `""`, while "resolver revert" diverges and aborts the call.

**Breaking Operation:** `handleOf()` at `src/JBProjectHandles.sol:139`
- Reads the resolver from ENS.
- Calls `ITextResolver(textResolver).text(hashedName, TEXT_KEY)` at `src/JBProjectHandles.sol:145`.
- Does not catch resolver failure.

**Trigger Sequence:**
1. A setter stores ENS parts with `setEnsNamePartsFor`.
2. The ENS registry resolves the derived node to a resolver contract.
3. That resolver reverts on `text(namehash, "juicebox")`.
4. `handleOf` reverts instead of returning `""`.

**Consequence:**
- Integrations that treat `handleOf` as a safe verification oracle can be DoSed for that record.
- The bug does not forge verification or cross setter boundaries, so impact is availability-only.

**Verification Evidence:**
- Code trace: no `try/catch` or alternate error handling exists around the external resolver call.
- PoC: `test_handleOf_revertsWhenResolverReverts()` passes under Foundry and demonstrates the revert propagation.

**Fix:**
```solidity
try ITextResolver(textResolver).text(hashedName, TEXT_KEY) returns (string memory textRecord) {
    if (
        keccak256(bytes(textRecord))
            != keccak256(bytes(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId))))
    ) return "";
    return _formatHandle(ensNameParts);
} catch {
    return "";
}
```

## Feedback Loop Discoveries
- None. The State pass narrowed the impact of the resolver-revert issue, but it did not reveal an additional cross-contract or state-desync bug.

## False Positives Eliminated
- Cross-setter corruption through normal calls or non-forwarder calldata padding: eliminated by direct code trace and existing ERC-2771 tests.
- `_namehash` label-order bug: eliminated by code trace and `test_namehash_matchesKnownValues()`.
- Deployment-ordering bug in `Deploy.deploy()`: not reported because the repo does not provide evidence that the intended Sphinx production path bypasses `run()`.

## Downgraded Findings
- None.

## Summary
- Total functions analyzed: 14 executable functions across repo code
- Coupled state pairs mapped: 4
- Nemesis loop iterations: 4 passes total
- Raw findings: 0 CRITICAL | 0 HIGH | 0 MEDIUM | 3 LOW
- Feedback loop discoveries: 0
- After verification: 1 TRUE POSITIVE | 2 FALSE POSITIVE / accepted
- Final: 0 CRITICAL | 0 HIGH | 0 MEDIUM | 1 LOW
