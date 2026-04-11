# Skills

Working reference guide for understanding and modifying this repository.

## When to use this file

- You need to understand ENS handle resolution for Juicebox projects.
- You're modifying the handle verification or name part storage logic.
- You're debugging why a handle isn't resolving.

## Read-next matrix

| Starting from | Read next |
|---------------|-----------|
| New to repo | README.md → ARCHITECTURE.md |
| Understanding verification | src/JBProjectHandles.sol (`handleOf`) |
| Understanding storage | src/JBProjectHandles.sol (`setEnsNamePartsFor`, `_ensNamePartsOf`) |
| Running tests | test/JBProjectHandles.t.sol |
| Deploying | script/Deploy.s.sol |

## Repo map

```
src/JBProjectHandles.sol          — Single contract: storage, validation, ENS verification
src/interfaces/IJBProjectHandles.sol — Interface with events and function signatures
test/JBProjectHandles.t.sol       — Fuzz tests for set/get/verify flows
script/Deploy.s.sol               — Sphinx-based deployment
script/helpers/                   — Deployment artifact reader
```

## Purpose

Permissionless ENS handle registry. Stores ENS name parts per `(chainId, projectId, setter)` and verifies handles by checking ENS text records.

## Working rules

1. **Start in `src/JBProjectHandles.sol`** — it's the only contract, intentionally small.
2. **`handleOf` is read-only verification** — it queries ENS and compares records. No state changes.
3. **Setter isolation** — storage is keyed by `_msgSender()`. One caller's records cannot affect another's.
4. **Dot validation matters** — prevents ENS injection attacks. Do not weaken the check in `setEnsNamePartsFor`.
5. **ENS namehash is EIP-137** — the `_namehash` function must match the standard exactly for resolution to work.
