# Project Handles

## Use This File For

- Use this file when you need to understand ENS handle resolution for Juicebox projects.
- Use this file when modifying handle verification, name-part storage, or deployment assumptions around the registry.
- Start here when debugging why a handle is missing, empty, or resolving differently than expected. Most failures are either setter mismatch, ENS resolver behavior, or non-canonical labels.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and architecture | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| ENS verification flow | [`src/JBProjectHandles.sol`](./src/JBProjectHandles.sol) and `handleOf` |
| Name-part storage and validation | [`src/JBProjectHandles.sol`](./src/JBProjectHandles.sol) and `setEnsNamePartsFor` |
| Runtime and operational assumptions | [`references/runtime.md`](./references/runtime.md), [`references/operations.md`](./references/operations.md) |
| Deployment flow | [`script/Deploy.s.sol`](./script/Deploy.s.sol) |
| Runtime validation | [`test/JBProjectHandles.t.sol`](./test/JBProjectHandles.t.sol) |

## Repo Map

| Area | Where to look |
|---|---|
| Main contract | [`src/JBProjectHandles.sol`](./src/JBProjectHandles.sol) |
| Interface | [`src/interfaces/IJBProjectHandles.sol`](./src/interfaces/IJBProjectHandles.sol) |
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

Permissionless ENS handle registry. Stores ENS name parts per `(chainId, projectId, setter)` and verifies handles by checking ENS text records.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) when you need handle verification semantics, ENS dependency notes, or the main invariants around storage and namehashing.
- Open [`references/operations.md`](./references/operations.md) when you need change-specific validation guidance, common failure modes, or deployment-time sender assumptions.

## Working Rules

- Start in [`src/JBProjectHandles.sol`](./src/JBProjectHandles.sol). The repo is intentionally small, so most behavior lives in one contract.
- `handleOf` is read-only verification. It queries ENS registry and resolver contracts; failures here are integration failures, not state transitions.
- Setter isolation is the core storage invariant. Storage is keyed by `_msgSender()`, so frontends and scripts must use the intended setter address.
- Callers are expected to provide ENS-normalized labels. Raw mixed-case or otherwise non-canonical labels can store successfully but fail to resolve as intended.
- Dot validation in `setEnsNamePartsFor` is a security boundary. Do not weaken it without re-deriving the namehash safety properties.
