# Project Handles V6

`@bananapus/project-handles-v6` is a permissionless ENS handle registry for Juicebox projects. It maps `(chainId, projectId, setter)` to ENS name parts and only returns a handle when the ENS text record points back to that same project.

Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)  
User journeys: [USER_JOURNEYS.md](./USER_JOURNEYS.md)  
Skills: [SKILLS.md](./SKILLS.md)  
Risks: [RISKS.md](./RISKS.md)  
Administration: [ADMINISTRATION.md](./ADMINISTRATION.md)  
Audit instructions: [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md)

## Overview

This package solves a narrow naming problem: letting wallets, frontends, and crawlers discover a project's claimed ENS handle without trusting a centralized registry.

The trust model is intentionally lightweight:

- anyone can store ENS name parts for any project
- the storage slot is scoped by the caller, so one setter cannot overwrite another setter's record
- `handleOf` only treats a handle as valid when the ENS `juicebox` text record resolves back to `chainId:projectId`

Use this repo when the question is "what ENS handle does this project claim?" Do not use it when the question is project ownership, permissions, or protocol accounting.

If the issue is "who controls the project?" start in `nana-core-v6` and `JBProjects` first. This repo only describes a verifiable naming layer on top.

## Key Contract

| Contract | Role |
| --- | --- |
| `JBProjectHandles` | Stores ENS name parts per `(chainId, projectId, setter)` and verifies them against ENS text records before returning a handle. |

## Mental Model

The contract does two things:

1. record which ENS name parts a given setter associates with a project
2. verify at read time that the ENS name's `juicebox` text record points back to the same project

That means this repo is not a source of subjective truth. It is a source of verifiable claims.

## Read These Files First

1. `src/JBProjectHandles.sol`
2. `src/interfaces/IJBProjectHandles.sol`

## Integration Traps

- callers must supply the `setter` they want to trust; there is no single built-in canonical setter
- a stored handle can exist on-chain and still fail verification if the ENS text record drifts
- callers should store ENS-normalized labels; non-canonical labels can be stored but fail verification because `_namehash` hashes raw bytes
- mainnet deployment does not mean mainnet-only data; the `chainId` parameter intentionally points at projects on many EVM chains
- ENS liveness and resolver behavior remain external dependencies

## Where State Lives

- stored ENS name parts live in `JBProjectHandles`
- authoritative project ownership still lives in `nana-core-v6`
- final verification depends on live ENS text records outside this repo

## High-Signal Tests

1. `test/JBProjectHandles.t.sol`

## Install

```bash
npm install @bananapus/project-handles-v6
```

## Development

```bash
npm install
forge build
forge test
```

Useful scripts:

- `npm run test:fork`
- `npm run deploy:mainnets`
- `npm run deploy:testnets`

## Deployment Notes

The production deployment target is Ethereum mainnet through `script/Deploy.s.sol`. The contract manages handles for many chains by carrying the target `chainId` in storage and verification calls.

## Repository Layout

```text
src/
  JBProjectHandles.sol
  interfaces/
test/
  handle verification and edge-case coverage
script/
  Deploy.s.sol
  helpers/
```

## Risks And Notes

- frontends that want an owner-endorsed handle may choose the current project owner as the trusted setter, but that trust policy is application-specific
- if a project changes owners, older setter records remain stored but should no longer be treated as canonical automatically
- there is no delete path; changing a handle means overwriting the stored name parts for that setter
- malformed or non-normalized ENS labels can be stored successfully and still never verify at read time
- ENS outages or resolver misconfiguration can make a stored handle unreadable or unverifiable
- a handle can be stored on-chain and still fail verification at read time if the ENS text record no longer points back to the same `chainId:projectId`

## For AI Agents

- Describe this repo as a verifiable naming layer, not as a canonical ownership registry.
- Be explicit that the caller chooses which setter they trust.
