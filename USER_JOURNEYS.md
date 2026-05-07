# User Journeys

## Repo Purpose

This repo stores ENS name parts for a project and verifies them against the ENS `juicebox` text record at read time. It is a verification helper, not a naming authority. Clients still decide which `setter` address they trust.

## Primary Actors

- project owners who want a verifiable ENS handle
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

1. Set the `juicebox` text record on the ENS name to `chainId:projectId`.
2. Call `setEnsNamePartsFor(...)` with the target chain, project, and name parts.
3. The contract validates the parts and stores them under `(chainId, projectId, msg.sender)`.

**Failure Modes**

- a name part is empty or contains a dot
- labels were not normalized offchain and later never verify cleanly
- the ENS text record is missing or points at the wrong project
- clients later query the wrong `setter`

**Postconditions**

- the reverse record is stored
- verification still happens only when `handleOf(...)` is called

## Journey 2: Resolve A Verified Handle

**Actor:** frontend, indexer, or bot.

**Intent:** display a handle only if ENS points back at the same project.

**Preconditions**

- the client knows which `setter` it considers authoritative
- the ENS registry and resolver are reachable on Ethereum mainnet

**Main Flow**

1. Call `handleOf(chainId, projectId, setter)`.
2. The contract loads stored name parts for that key.
3. It computes the EIP-137 namehash and queries the ENS resolver.
4. It reads the resolver's `juicebox` text record.
5. If the record matches `chainId:projectId`, it returns the formatted handle. Otherwise it returns `""`.

**Failure Modes**

- the stored parts exist but the ENS text record does not match
- the client passes an old owner as `setter`
- the resolver reverts, causing `handleOf` to return `""`
- ENS dependencies fail and resolution becomes unavailable

**Postconditions**

- clients get either a verified handle or an empty string
- the contract never returns an unverified handle as if it were canonical

## Journey 3: Handle Ownership Transfer

**Actor:** new owner and clients that want the current canonical handle.

**Intent:** move handle resolution cleanly after project ownership changes.

**Preconditions**

- project ownership has changed
- clients now pass the new owner as the trusted `setter`

**Main Flow**

1. Project ownership changes.
2. The old owner's handle record stays onchain, but frontends now pass the new owner's address as `setter`.
3. `handleOf` returns `""` until the new owner stores name parts.
4. The new owner calls `setEnsNamePartsFor(...)` and updates the ENS text record if needed.

**Failure Modes**

- clients keep using the old owner's address and show stale branding
- the new owner stores name parts but forgets to update the ENS text record
- clients assume historical records are deleted instead of just becoming non-canonical

**Postconditions**

- handle resolution can move to the new owner without deleting historical storage

## Trust Boundaries

- this repo trusts ENS registry and resolver state at read time
- clients still choose which `setter` they treat as canonical
- project ownership still comes from core, not from this repo

## Hand-Offs

- Use ENS and the relevant resolver to set the `juicebox` text record.
- Use [nana-core-v6](../nana-core-v6/USER_JOURNEYS.md) to determine the current project owner that clients should usually pass as `setter`.
