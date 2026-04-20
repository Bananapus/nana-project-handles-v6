# Feynman Audit — Raw Analysis

## Scope
- Language: Solidity 0.8.28
- Modules analyzed: `src/JBProjectHandles.sol`, `src/interfaces/IJBProjectHandles.sol`, `script/Deploy.s.sol`, `script/helpers/ProjectHandlesDeploymentLib.sol`
- Functions analyzed: 14 executable functions across repo code, plus the interface surface

## Phase 0 — Attacker's Hit List

### Attack goals
1. Corrupt another setter's namespace through ERC-2771 sender confusion.
2. Return a false-positive verified handle by breaking the ENS round-trip check.
3. Make `handleOf` unusable for an otherwise stored record.

### Novel code
- `src/JBProjectHandles.sol` — custom ENS formatting and EIP-137 namehash construction.
- `script/Deploy.s.sol` — custom deployment wiring from `core-v6` into the trusted forwarder trust root.

### Value stores / trust stores
- `_ensNamePartsOf[chainId][projectId][setter]` — authoritative onchain storage of candidate ENS labels.
- `core.trustedForwarder` in deployment flow — runtime authority for `_msgSender()` under ERC-2771.
- ENS registry + resolver text record — offchain-controlled verification oracle used by `handleOf`.

### Complex paths
- `setEnsNamePartsFor` -> `_msgSender()` -> `_ensNamePartsOf` write -> later `handleOf` -> `_namehash` -> ENS registry -> ENS resolver text read.
- `run` -> `CoreDeploymentLib.getDeployment` -> `deploy` -> constructor injection of trusted forwarder.

### Priority order
1. `JBProjectHandles.handleOf` — external trust boundary, custom namehash, external calls.
2. `JBProjectHandles.setEnsNamePartsFor` — only mutation path for setter isolation.
3. `Deploy.run/deploy` — wires the trusted forwarder authority.

## Function-State Matrix

| Function | Reads | Writes | Guards | Internal Calls | External Calls |
|---|---|---|---|---|---|
| `JBProjectHandles.setEnsNamePartsFor` | `parts`, `_msgSender()` | `_ensNamePartsOf[...]` | part count / empty-part / dot rejection | `_formatHandle`, `_msgSender` | none |
| `JBProjectHandles.ensNamePartsOf` | `_ensNamePartsOf[...]` | none | none | none | none |
| `JBProjectHandles.handleOf` | `_ensNamePartsOf[...]`, `TEXT_KEY` | none | none | `_namehash`, `_formatHandle` | `ENS_REGISTRY.resolver`, `ITextResolver.text` |
| `JBProjectHandles._formatHandle` | `ensNameParts` | none | none | none | none |
| `JBProjectHandles._namehash` | `ensNameParts` | none | none | none | none |
| `JBProjectHandles._msgSender` | ERC2771 context | none | trusted-forwarder check in OZ | none | none |
| `JBProjectHandles._msgData` | ERC2771 context | none | trusted-forwarder check in OZ | none | none |
| `Deploy.configureSphinx` | none | `sphinxConfig` | none | none | none |
| `Deploy.run` | env var, deployment files | `core` | none | `deploy` | `CoreDeploymentLib.getDeployment` |
| `Deploy.deploy` | `core.trustedForwarder` | deployment side effect | `sphinx` | `_isDeployed` | `new JBProjectHandles(...)` |
| `Deploy._isDeployed` | creation code, args | none | none | none | `vm.computeCreate2Address` |
| `ProjectHandlesDeploymentLib.getDeployment(path)` | `block.chainid`, Sphinx network table | none | supported-chain check | overloaded `getDeployment` | file/network metadata lookup |
| `ProjectHandlesDeploymentLib.getDeployment(path,networkName)` | deployment JSON | none | none | `_getDeploymentAddress` | `vm.readFile` |
| `ProjectHandlesDeploymentLib._getDeploymentAddress` | deployment JSON | none | none | none | `vm.readFile`, `stdJson.readAddress` |

## Raw Feynman Findings

### FF-R1: `handleOf` bubbles a resolver revert
- Module: `src/JBProjectHandles.sol`
- Lines: 139-145
- Question: `Q6.3: What if an external call in this function fails silently or reverts?`
- Scenario:
  1. A setter stores a valid-looking ENS record.
  2. ENS registry returns a resolver contract.
  3. `resolver.text(namehash, "juicebox")` reverts.
  4. `handleOf` reverts instead of degrading to `""`.
- Initial severity: LOW
- Notes: likely metadata availability only, but the verification API contract becomes harsher than its "verified or empty" semantics.

### FF-R2: direct `deploy()` invocation may bypass `run()` initialization
- Module: `script/Deploy.s.sol`
- Lines: 32-38
- Question: `Q4.3: What does this function assume about current state?`
- Scenario:
  1. `deploy()` is entered without `run()` having populated `core`.
  2. `core.trustedForwarder` remains its zero-initialized value.
  3. `JBProjectHandles` is deployed with an unintended forwarder.
- Initial severity: LOW
- Status: suspect pending verification against Sphinx execution model.

### FF-R3: non-normalized labels can still be stored
- Module: `src/JBProjectHandles.sol`
- Lines: 56-86, 183-193
- Question: `Q4.2: What does this function assume about external data it receives?`
- Scenario:
  1. Caller provides raw labels that are not ENSIP-15 normalized.
  2. Labels are stored and emitted unchanged.
  3. `handleOf` later hashes raw bytes and may never verify.
- Initial severity: LOW
- Status: likely accepted-by-design because verification still fails closed.
