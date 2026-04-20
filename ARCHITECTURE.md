# Architecture

## Purpose

`project-handles-v6` is a permissionless ENS handle registry for Juicebox projects. It stores the reverse side of the association: which ENS name a given setter address has linked to a project on a given chain.

## System Overview

`JBProjectHandles` stores ENS name parts keyed by `(chainId, projectId, setter)`, validates that those parts are well formed, computes EIP-137 namehashes, and verifies handles by checking that the ENS text record `juicebox` points back to the expected `chainId:projectId`. The contract is deliberately permissionless and has no admin, pause, or upgrade layer.

## Core Invariants

- ENS name parts cannot be empty and cannot contain dots.
- `handleOf(...)` is read-only verification against ENS and must not mutate state.
- Setter records are isolated from one another.
- Stored labels are hashed as provided. Caller-supplied ENS normalization is therefore part of correctness.
- Namehash calculation must remain EIP-137 compliant.

## Modules

| Module | Responsibility | Notes |
| --- | --- | --- |
| `JBProjectHandles` | Storage, validation, ENS lookup, and verification | Main contract |
| `IJBProjectHandles` | Interface, views, and events | External surface |

## Trust Boundaries

- The repo trusts ENS registry and resolver reads.
- It does not verify project ownership itself; clients decide which `setter` is authoritative.
- It does not manage ENS names or other project metadata.

## Critical Flows

### Set Handle

```text
caller
  -> calls setEnsNamePartsFor(chainId, projectId, parts)
  -> contract validates parts
  -> stores the parts under `_msgSender()`
```

### Verify Handle

```text
client
  -> calls handleOf(chainId, projectId, setter)
  -> contract loads stored name parts
  -> computes the ENS namehash
  -> queries ENS text record `juicebox`
  -> returns the formatted handle if the record matches `chainId:projectId`
```

## Accounting Model

No economic accounting lives here. The critical state is the `(chainId, projectId, setter) -> ENS parts` mapping.

## Security Model

- Namehash and formatting logic are effectively protocol plumbing and should stay simple.
- The permissionless model relies on `_msgSender()` scoping; changing the storage key would change the trust model.
- ENS availability and resolver correctness are upstream dependencies.
- This repo does not canonicalize labels. Non-normalized input can be stored but later fail verification because ENS namehashing operates on the raw bytes provided.

## Safe Change Guide

- Do not weaken part validation or dot checks.
- Keep `_msgSender()` in the storage key unless you intend to redesign the trust model.
- If label handling changes, re-check ENS normalization assumptions and namehash compatibility together.
- Prefer no change over clever change in namehash logic.

## Canonical Checks

- part validation, overwrite behavior, and ENS record verification:
  `test/JBProjectHandles.t.sol`

## Source Map

- `src/JBProjectHandles.sol`
- `src/interfaces/IJBProjectHandles.sol`
- `test/JBProjectHandles.t.sol`
- `script/Deploy.s.sol`
- `script/helpers/ProjectHandlesDeploymentLib.sol`
- `references/runtime.md`
- `references/operations.md`
