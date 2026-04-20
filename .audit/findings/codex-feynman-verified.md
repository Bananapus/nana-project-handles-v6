# Feynman Audit — Verified Findings

## Scope
- Language: Solidity 0.8.28
- Modules analyzed: `src/JBProjectHandles.sol`, `src/interfaces/IJBProjectHandles.sol`, `script/Deploy.s.sol`, `script/helpers/ProjectHandlesDeploymentLib.sol`
- Functions analyzed: 14 executable functions across repo code, plus the interface surface
- Verification run: `forge test`

## Verification Summary
| ID | Original Severity | Verdict | Final Severity |
|---|---|---|---|
| FF-001 | LOW | TRUE POSITIVE | LOW |
| FF-R2 | LOW | FALSE POSITIVE | — |
| FF-R3 | LOW | FALSE POSITIVE / accepted behavior | — |

## Verified Findings

### Finding FF-001: Resolver Reverts Bubble Through `handleOf`
**Severity:** LOW  
**Module:** `JBProjectHandles`  
**Function:** `handleOf`  
**Lines:** `src/JBProjectHandles.sol:139-145`  
**Verification:** Hybrid — code trace plus `test_handleOf_revertsWhenResolverReverts()`

**Feynman Question that exposed this:**
> What happens on the error path of the external ENS resolver call?

**The code:**
```solidity
address textResolver = ENS_REGISTRY.resolver(hashedName);
if (textResolver == address(0)) return "";
string memory textRecord = ITextResolver(textResolver).text(hashedName, TEXT_KEY);
```

**Why this is wrong:**
The function degrades gracefully when no resolver exists, but it does not degrade gracefully when a resolver exists and reverts. That means the public verification surface has two different failure modes for equivalent "cannot verify" outcomes: empty string for benign failure, revert for hostile or broken resolver behavior.

**Verification evidence:**
- Code trace: no `try/catch` surrounds `ITextResolver(textResolver).text(...)`, so any revert propagates to the caller.
- PoC: `test_handleOf_revertsWhenResolverReverts()` passes and proves the revert bubbles to the external caller.

**Attack scenario:**
1. A setter stores ENS parts for a project.
2. The referenced ENS node resolves to a contract that reverts on `text(...)`.
3. Any UI, indexer, or helper contract calling `handleOf` for that setter receives a revert instead of `""`.

**Impact:**
This is an availability issue on the metadata verification path. It does not let an attacker forge a verified handle or write into another setter's slot, but it can break integrations that assume the documented outcome is "verified handle or empty string."

**Suggested fix:**
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

## False Positives Eliminated
- `Deploy.deploy()` zero-forwarder concern: unverified as a protocol bug because the issue depends on invoking the script outside its intended Sphinx flow; no evidence in-repo shows that the production path calls `deploy()` without `run()`.
- Non-normalized labels: accepted behavior. The contract documents raw-label storage and still fails closed at verification time by returning `""` unless the exact ENS bytes round-trip matches.

## Summary
- Total functions analyzed: 14 executable functions across repo code
- Raw findings: 3 LOW
- After verification: 1 TRUE POSITIVE, 2 eliminated
- Final: 1 LOW
