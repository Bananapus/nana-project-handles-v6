# Project Handles V6

`@bananapus/project-handles-v6` is a permissionless ENS handle registry for Juicebox projects. It stores ENS name parts by `(chainId, projectId, setter)` and only returns a handle when the ENS text record points back to that same project.

Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)  
User journeys: [USER_JOURNEYS.md](./USER_JOURNEYS.md)  
Skills: [SKILLS.md](./SKILLS.md)  
Risks: [RISKS.md](./RISKS.md)  
Administration: [ADMINISTRATION.md](./ADMINISTRATION.md)  
Audit instructions: [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md)

## Overview

This package solves one narrow problem: letting wallets, frontends, and crawlers discover a project's claimed ENS handle without trusting a central registry.

Its trust model is simple:

- anyone can store ENS name parts for any project
- each record is scoped by the caller, so one setter cannot overwrite another setter's record
- `handleOf` only returns a handle when the ENS `juicebox` text record resolves back to `chainId:projectId`

Use this repo when the question is "what ENS handle does this project claim?" Do not use it for project ownership, permissions, or protocol accounting.

## Key Contract

| Contract | Role |
| --- | --- |
| `JBProjectHandles` | Stores ENS name parts per `(chainId, projectId, setter)` and verifies them against ENS text records before returning a handle. |

## Mental Model

The contract does two jobs:

1. store which ENS name parts a setter claims for a project
2. verify at read time that the ENS name's `juicebox` text record points back to that same project

So this repo is not a source of canonical truth. It is a source of verifiable claims.

## Read These Files First

1. `src/JBProjectHandles.sol`
2. `src/interfaces/IJBProjectHandles.sol`

## Integration Traps

- callers must supply the `setter` they want to trust; there is no built-in canonical setter
- a stored handle can exist onchain and still fail verification if the ENS text record drifts
- callers should store ENS-normalized labels; non-canonical labels can store successfully but fail verification later
- mainnet deployment does not mean mainnet-only data; the `chainId` parameter can point at projects on other EVM chains
- ENS liveness and resolver behavior stay outside this repo

## Where State Lives

- stored ENS name parts live in `JBProjectHandles`
- project ownership still lives in `nana-core-v6`
- final verification depends on live ENS text records

## High-Signal Tests

1. `test/JBProjectHandles.t.sol`

## Install

```bash
npm install @bananapus/project-handles-v6
```

## Development

```bash
npm install
forge build --deny notes --skip "*/test/**" --skip "*/script/**"
forge test --deny notes
```

Useful scripts:

- `npm run test:fork`
- `npm run deploy:mainnets`
- `npm run deploy:testnets`

## Deployment Notes

The production deployment target is Ethereum mainnet through `script/Deploy.s.sol`. The contract can still manage handles for many chains because `chainId` is part of the stored and verified data.

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

- frontends that want an owner-endorsed handle will usually choose the current project owner as the trusted setter, but that policy is offchain
- if a project changes owners, older setter records remain stored and should not automatically be treated as canonical
- there is no delete path; changing a handle means overwriting the stored name parts for that setter
- malformed or non-normalized ENS labels can be stored and still never verify
- ENS outages or resolver bugs can make a stored handle unreadable or unverifiable

## For AI Agents

- Describe this repo as a verifiable naming layer, not as a canonical ownership registry.
- Be explicit that the caller chooses which setter to trust.
