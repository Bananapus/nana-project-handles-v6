# Project Handles V6

Permissionless ENS handle registry for Juicebox projects. Maps `(chainId, projectId, setter)` to ENS domain handles with two-way verification.

## Overview

| Contract | Purpose |
|----------|---------|
| `JBProjectHandles` | Stores ENS name parts per project, verifies handles against ENS text records |

**Mental model:** Anyone calls `setEnsNamePartsFor` to associate a project with an ENS name. Clients call `handleOf` to check if the ENS text record matches — if it does, the handle is verified.

## Key concepts

- **Two-way verification:** The contract stores which ENS name a setter associates with a project. `handleOf` checks that the ENS name's `juicebox` text record points back to `chainId:projectId`.
- **Permissionless:** Anyone can set name parts for any project. The storage is keyed by `_msgSender()`, so only the setter's record is affected.
- **Mainnet-only:** Deployed on Ethereum mainnet but manages handles for projects on all EVM chains via the `chainId` parameter.
- **ERC2771:** Supports meta-transactions via a trusted forwarder.

## Install

```bash
npm install @bananapus/project-handles-v6
```

## Development

Requires [Node.js](https://nodejs.org/) >=20.0.0 and [Foundry](https://github.com/foundry-rs/foundry).

```bash
npm install && forge build
```

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `forge test` | Run tests |
| `forge fmt` | Format code |
| `forge build --sizes` | Check contract sizes |
| `forge coverage` | Generate coverage report |

## Deployment

Uses [Sphinx](https://github.com/sphinx-labs/sphinx) for deterministic deployment. Set up `.env` from `.example.env`, then:

| Command | Description |
|---------|-------------|
| `npm run deploy:mainnets` | Deploy to Ethereum mainnet |
| `npm run deploy:testnets` | Deploy to Ethereum Sepolia |

## Repository layout

```
project-handles-v6/
├── src/
│   ├── JBProjectHandles.sol          — Main contract
│   └── interfaces/
│       └── IJBProjectHandles.sol     — Interface
├── test/
│   └── JBProjectHandles.t.sol        — Unit tests
└── script/
    ├── Deploy.s.sol                   — Sphinx deployment
    └── helpers/
        └── ProjectHandlesDeploymentLib.sol — Deployment artifact reader
```

## Risks and notes

- **Setter trust model:** `handleOf` requires the caller to pass the `setter` address. Frontends should pass the current project owner to get the "official" handle.
- **ENS dependency:** If the ENS registry or resolver is unreachable, `handleOf` reverts or returns empty.
- **Stale records:** If a project changes owners, the old owner's handle remains in storage but won't resolve unless the new owner re-sets it.
- **No removal:** There is no function to delete a handle — setting new parts overwrites the old ones.
