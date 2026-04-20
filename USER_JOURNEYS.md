# User Journeys

## Repo Purpose

This repo stores ENS name parts for a project and verifies them against the ENS `juicebox` text record at read time.
It is a verification helper, not a naming authority. It does not decide which handle is canonical; clients still choose
which `setter` address they trust.

## Primary Actors

- project owners who want a verifiable ENS handle for branding
- frontend and indexer clients resolving a project's handle for display
- auditors reviewing the two-way verification model

## Key Surfaces

- `JBProjectHandles.setEnsNamePartsFor(...)`: stores the caller's chosen ENS name parts for a project
- `JBProjectHandles.handleOf(...)`: resolves the stored name and verifies it against ENS text records
- `ensNamePartsOf(...)`: raw stored parts, useful for debugging but not itself a verification surface

## Journey 1: Set An ENS Handle

**Actor:** project owner or another address that wants to publish a handle candidate.

**Intent:** associate an ENS name with a project in a way clients can verify later.

**Preconditions**
- the caller controls or coordinates with the ENS name they want to use
- the ENS resolver can serve a `juicebox` text record for that name
- the caller understands that storage is keyed by `msg.sender`

**Main Flow**
1. Owner sets the `juicebox` text record on their ENS name (e.g., `project.jeff.eth`) to `chainId:projectId` (e.g., `10:5`) via the ENS app.
2. Owner calls `setEnsNamePartsFor(chainId: 10, projectId: 5, parts: ["project", "jeff"])` on `JBProjectHandles` on Ethereum mainnet.
3. The contract validates that no parts are empty or contain dots, then stores the parts keyed by `(chainId, projectId, msg.sender)`.

**Failure Modes**
- any name part is empty or contains a dot
- labels are not normalized correctly offchain and never verify cleanly later
- the ENS text record is never set or points at the wrong `chainId:projectId`
- clients later query the wrong `setter` address

**Postconditions**
- the reverse record is stored
- verification still happens only when `handleOf(...)` is called

## Journey 2: Resolve A Verified Handle

**Actor:** frontend, indexer, or bot.

**Intent:** display a handle only if ENS points back at the same project.

**Preconditions**
- the client knows which `setter` address it considers authoritative
- the ENS registry and resolver are reachable on Ethereum mainnet

**Main Flow**
1. Client calls `handleOf(chainId: 10, projectId: 5, setter: ownerAddress)`.
2. Contract retrieves stored name parts for that key.
3. Contract computes the EIP-137 namehash and queries the ENS registry for a resolver.
4. Contract queries the resolver's `text(namehash, "juicebox")` record.
5. Contract compares the text record against `"10:5"`.
6. If matched, returns the formatted handle (e.g., `"project.jeff.eth"`). Otherwise returns `""`.

**Failure Modes**
- the name parts exist but the ENS text record does not match
- the client passes an old owner as `setter`
- the resolver itself reverts, making handle resolution unavailable
- ENS dependencies fail and resolution reverts or returns empty

**Postconditions**
- clients get either a verified handle or an empty string
- the contract never returns an unverified handle as if it were canonical

## Journey 3: Handle Ownership Transfer

**Actor:** new owner and any client that wants the current canonical handle.

**Intent:** re-associate the project after ownership changes.

**Preconditions**
- project ownership has changed
- clients now pass the new owner as the trusted `setter`

**Main Flow**
1. Project ownership changes (the NFT transfers to a new address).
2. The old owner's handle record still exists but frontends pass the new owner's address as `setter`.
3. `handleOf` returns `""` because the new owner hasn't set name parts yet.
4. New owner calls `setEnsNamePartsFor` to associate the same or different ENS name.
5. New owner also updates the ENS text record if needed.

**Failure Modes**
- clients keep using the old owner's address and show stale branding
- the new owner sets name parts but forgets to update the ENS text record
- clients assume historical records are deleted rather than simply becoming non-canonical for the new `setter`

**Postconditions**
- handle resolution can move cleanly to the new owner without deleting historical storage

## Trust Boundaries

- this repo trusts ENS registry and resolver state at read time
- clients still choose which `setter` address they treat as canonical
- project ownership still comes from core, not from this repo

## Hand-Offs

- Use ENS and the relevant resolver to set the `juicebox` text record.
- Use [nana-core-v6](../nana-core-v6/USER_JOURNEYS.md) to determine the current project owner that clients should usually pass as `setter`.
