# Feynman Audit — Verified Findings

## Scope
- Language: Solidity 0.8.28
- Modules analyzed: `src/JBProjectHandles.sol`, `src/interfaces/IJBProjectHandles.sol`, `script/Deploy.s.sol`, `script/helpers/ProjectHandlesDeploymentLib.sol`
- Functions analyzed: 10 implementation functions in scope, plus 5 interface entrypoints
- Lines interrogated: full runtime and deployment surface

## Verification Summary
| ID | Original Severity | Verdict | Final Severity |
|----|-------------------|---------|----------------|
| FF-001 | LOW | TRUE POSITIVE | LOW |

## Function-State Matrix
| Function | Reads | Writes | Guards | Calls |
|----------|-------|--------|--------|-------|
| `JBProjectHandles.setEnsNamePartsFor` | `parts`, `_msgSender()` | `_ensNamePartsOf[chainId][projectId][_msgSender()]` | ERC2771 trusted forwarder context only | `_msgSender()`, `_formatHandle()` |
| `JBProjectHandles.ensNamePartsOf` | `_ensNamePartsOf[chainId][projectId][setter]` | none | none | none |
| `JBProjectHandles.handleOf` | `_ensNamePartsOf[...]`, `TEXT_KEY`, `ENS_REGISTRY` | none | none | `_namehash()`, `ENS_REGISTRY.resolver()`, `ITextResolver.text()`, `_formatHandle()` |
| `JBProjectHandles._formatHandle` | `ensNameParts` | none | none | none |
| `JBProjectHandles._namehash` | `ensNameParts` | none | none | none |
| `JBProjectHandles._msgSender` | forwarded calldata / `msg.sender` | none | trusted forwarder check in OZ | `ERC2771Context._msgSender()` |
| `JBProjectHandles._msgData` | forwarded calldata / `msg.data` | none | trusted forwarder check in OZ | `ERC2771Context._msgData()` |
| `Deploy.configureSphinx` | none | `sphinxConfig` | none | none |
| `Deploy.run` | env var, deployment files, `block.chainid` | `core` | none | `CoreDeploymentLib.getDeployment()`, `deploy()` |
| `Deploy.deploy` | `core.trustedForwarder` | deploys `JBProjectHandles` | `sphinx` modifier | `_isDeployed()`, `new JBProjectHandles(...)` |
| `Deploy._isDeployed` | salt, creation code, args | none | none | `vm.computeCreate2Address()` |
| `ProjectHandlesDeploymentLib.getDeployment(path)` | `block.chainid`, Sphinx network table | none | none | `new SphinxConstants()`, overloaded `getDeployment(...)` |
| `ProjectHandlesDeploymentLib.getDeployment(path,networkName)` | deployment JSON | `deployment.projectHandles` | none | `_getDeploymentAddress()` |
| `ProjectHandlesDeploymentLib._getDeploymentAddress` | deployment JSON file | none | none | `vm.readFile()`, `stdJson.readAddress()` |

## Guard Consistency Analysis
- `JBProjectHandles` has a single mutating entrypoint, so there is no sibling write path with inconsistent access control.
- Setter isolation is enforced structurally by keying storage with `_msgSender()`; no function accepts a caller-supplied `setter` for mutation.
- Deployment functions have no runtime privilege transfer or post-deploy mutation path beyond deterministic deployment.

## Inverse Operation Parity
- No inverse runtime operation exists. The only mutation path is overwrite-in-place via `setEnsNamePartsFor`.
- No deletion or admin override path exists, so no asymmetry was found between normal and emergency/admin flows.

## Verified Findings (TRUE POSITIVES only)

### Finding FF-001: Non-normalized ENS labels can be stored but never verify
**Severity:** LOW
**Module:** `JBProjectHandles`
**Function:** `setEnsNamePartsFor`, `handleOf`, `_namehash`
**Lines:** `src/JBProjectHandles.sol:68`, `src/JBProjectHandles.sol:134`, `src/JBProjectHandles.sol:181`
**Verification:** Code trace

**Feynman Question that exposed this:**
> What does this function assume about external data it receives, and is that assumption enforced before the data becomes part of the verification path?

**The code:**
```solidity
for (uint256 i; i < partsLength; i++) {
    string memory part = parts[i];
    if (bytes(part).length == 0) revert JBProjectHandles_EmptyNamePart(parts);
    for (uint256 j; j < bytes(part).length; j++) {
        if (bytes(part)[j] == ".") revert JBProjectHandles_InvalidNamePart(part);
    }
}

bytes32 hashedName = _namehash(ensNameParts);
address textResolver = ENS_REGISTRY.resolver(hashedName);
```

**Why this is wrong:**
`setEnsNamePartsFor` only rejects empty strings and ASCII `.`. It does not normalize ENS labels or reject non-canonical inputs such as uppercase labels. `handleOf` later hashes the stored bytes exactly as provided. ENS names are canonicalized off-chain before registration and lookup, so a user can store a label like `ALICE`, pass validation, and still never resolve the matching `alice.eth` text record because `_namehash` hashes `ALICE` rather than the canonical lowercase label.

**Verification evidence:**
- `setEnsNamePartsFor` accepts any non-empty label without dots at [src/JBProjectHandles.sol:68](/Users/jango/Documents/jb/v6/evm/project-handles-v6/src/JBProjectHandles.sol#L68).
- `_namehash` hashes raw `ensNameParts[i]` bytes with no normalization at [src/JBProjectHandles.sol:181](/Users/jango/Documents/jb/v6/evm/project-handles-v6/src/JBProjectHandles.sol#L181).
- No other repo function lowercases, normalizes, or validates labels against ENS canonical form.
- Existing tests cover dots and empties but do not cover uppercase or other non-canonical labels.
- Independent normalization check during verification showed `ALICE -> alice`, confirming a canonical ENS record can exist while this contract hashes different bytes.

**Attack scenario:**
1. A setter owns `alice.eth` and sets the ENS `juicebox` text record to `1:5`.
2. The setter calls `setEnsNamePartsFor(1, 5, ["ALICE"])`.
3. The contract stores `["ALICE"]`.
4. `handleOf(1, 5, setter)` hashes `ALICE.eth`, queries the registry for that raw node, and returns `""`.

**Impact:**
- Breaks the repo’s verification-correctness invariant for non-canonical but otherwise human-plausible input.
- Causes self-inflicted handle resolution failure until the setter overwrites the stored parts with canonical labels.

**Suggested fix:**
```solidity
// Either reject non-canonical labels or normalize them before storage.
// Example direction:
// 1. require labels are already lowercase ASCII if that is the intended subset
// 2. or integrate ENS-compatible normalization before hashing/storage
```

## False Positives Eliminated
- Resolver reverts bubbling out of `handleOf` were reviewed and not reported. The repo docs and risks already model ENS availability/revert behavior as an accepted external dependency boundary, and no runtime value or privilege invariant depends on graceful recovery.
- ERC2771 spoofing by non-forwarders was eliminated by trace to OpenZeppelin’s `isTrustedForwarder` gate at `ERC2771Context._msgSender()`.
- Cross-setter pollution was eliminated by tracing the sole write path to `_ensNamePartsOf[chainId][projectId][_msgSender()]`.

## Downgraded Findings
- None.

## LOW Findings (verified by inspection)
| ID | Summary | Lines |
|----|---------|-------|
| FF-001 | Non-normalized labels can be stored but never verify | `src/JBProjectHandles.sol:68`, `src/JBProjectHandles.sol:134`, `src/JBProjectHandles.sol:181` |

## Summary
- Total functions analyzed: 15
- Raw findings (pre-verification): 1 LOW
- After verification: 1 TRUE POSITIVE | 0 FALSE POSITIVE | 0 DOWNGRADED
- Final: 0 HIGH | 0 MEDIUM | 1 LOW
