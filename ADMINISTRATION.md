# Administration

## At A Glance

| Item | Details |
| --- | --- |
| Scope | Permissionless project-handle publication keyed by caller identity |
| Control posture | Fully permissionless and adminless |
| Highest-risk actions | Offchain clients trusting the wrong setter or stale handle resolution policy |
| Recovery posture | Fix the client trust model or deploy replacement code; there is no owner recovery path |

## Purpose

`project-handles-v6` has no privileged admin surface. It is intentionally permissionless. The only real control consideration is how clients choose which `setter` address they trust when resolving a handle.

## Control Model

- No owner
- No governance
- No pause
- No upgrade
- Immutable ERC-2771 forwarder configuration

## Roles

| Role | How Assigned | Scope | Notes |
| --- | --- | --- | --- |
| Anyone | No assignment | Global | Can set ENS name parts for themselves as setter |
| Client integrator | Offchain choice | Per UI or indexer | Decides which setter to treat as authoritative |

## Privileged Surfaces

There are no privileged functions.

Relevant permissionless functions are:

- `setEnsNamePartsFor(...)`
- `handleOf(...)`

## Immutable And One-Way

- There is no admin delete path.
- The trusted forwarder is constructor-immutable.
- Records are keyed by `_msgSender()`, so changing the trust model would require new code, not an admin action.

## Operational Notes

- Frontends should choose the trusted setter explicitly, usually the current project owner.
- Treat stale records as a client-resolution problem, not an onchain admin problem.

## Machine Notes

- Do not confuse stored handle data with canonical project ownership; the contract does not verify that relationship.
- Treat client-side setter selection as the real trust decision.
- If an indexer resolves handles from the wrong setter, fix the indexer rather than searching for onchain admin recovery.

## Recovery

- There is no owner recovery surface.
- If a client trusted the wrong setter, fix the client or indexer logic.

## Admin Boundaries

- Nobody can curate, delete, or seize records.
- Nobody can verify project ownership onchain through this repo; clients decide which setter matters.

## Source Map

- `src/JBProjectHandles.sol`
- `src/interfaces/IJBProjectHandles.sol`
- `script/Deploy.s.sol`
- `script/helpers/ProjectHandlesDeploymentLib.sol`
- `test/JBProjectHandles.t.sol`
