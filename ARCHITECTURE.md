# Architecture

## Purpose

`JBProjectHandles` is a permissionless two-way ENS handle registry for Juicebox projects. It stores the "reverse record" side of the association: which ENS name a given setter address has linked to a given project on a given chain.

## What it does

- Stores ENS name parts keyed by `(chainId, projectId, setter)`.
- Validates name parts (no empty parts, no dots within parts).
- Verifies handles by checking that the ENS text record `juicebox` contains the matching `chainId:projectId` string.
- Computes EIP-137 namehashes for ENS lookups.

## What it does NOT do

- Does not enforce that the setter is the project owner — that's a client-side concern.
- Does not deploy or manage ENS names.
- Does not store any project metadata beyond the ENS name association.
- Does not have any admin, pause, or upgrade capability.

## Components

| Component | Role |
|-----------|------|
| `JBProjectHandles` | Main contract: stores name parts, validates, verifies against ENS |
| `IJBProjectHandles` | Interface: events, views, transactions |

## Runtime model

1. **Set:** Caller provides `(chainId, projectId, parts)` → contract validates parts → stores under `_msgSender()`.
2. **Verify:** Client calls `handleOf(chainId, projectId, setter)` → contract retrieves stored parts → computes namehash → queries ENS resolver → compares text record → returns formatted handle or empty string.

## Critical invariants

1. **Name parts are validated:** No empty parts, no parts containing dots.
2. **Handle verification is read-only:** `handleOf` never modifies state — it's a pure verification function against ENS.
3. **Setter isolation:** Each setter's records are independent. Setting name parts for one setter cannot affect another setter's records.
4. **ENS namehash correctness:** The `_namehash` function must produce EIP-137 compliant hashes for ENS resolution to work.

## Boundaries

- **Upstream:** ENS registry and text resolver (read-only dependency).
- **Downstream:** Frontend clients that call `handleOf` to display project handles.
- **Lateral:** JBProjects (project ownership) — the contract itself doesn't check ownership, but frontends pass the owner address as `setter`.

## Safe change guide

- The ENS namehash and format logic is cryptographic plumbing — prefer no change over clever change.
- Dot validation in `setEnsNamePartsFor` prevents ENS injection — do not weaken.
- The `_msgSender()` key ensures permissionless safety — do not change the storage key structure.
