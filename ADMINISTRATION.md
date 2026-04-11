# Administration

## At a glance

| Aspect | Detail |
|--------|--------|
| Owner | None |
| Admin functions | None |
| Pause capability | None |
| Upgrade path | None — deploy new contract and migrate clients |

## Permissionless design

`JBProjectHandles` has no privileged roles. All functions are callable by any address:

| Function | Access | Effect |
|----------|--------|--------|
| `setEnsNamePartsFor` | Anyone | Stores ENS name parts under `_msgSender()` |
| `ensNamePartsOf` | Anyone (view) | Reads stored name parts |
| `handleOf` | Anyone (view) | Verifies handle against ENS text record |

## ERC2771 trusted forwarder

The contract inherits `ERC2771Context` and accepts a `trustedForwarder` address at construction. This enables meta-transactions where a relayer submits transactions on behalf of users. The forwarder address is immutable — it cannot be changed after deployment.

**Trust implication:** The trusted forwarder can set `_msgSender()` to any address. Only deploy with a forwarder you trust, or use `address(0)` to disable meta-transactions.

## Routine operations

- **No maintenance required.** The contract has no state that needs periodic attention.
- **Client-side:** Frontends should query `handleOf` with the current project owner as `setter`. If ownership changes, the frontend automatically sees the new owner has no handle set.

## One-way / high-risk actions

- **No recovery:** If a setter loses access to their address, their stored records remain but cannot be updated or deleted.
- **Forwarder lock-in:** The trusted forwarder is set at construction and cannot be changed. If the forwarder is compromised, deploy a new contract.

## Migration

To migrate to a new version, deploy a new `JBProjectHandles` contract and point frontends to it. The old contract's storage remains on-chain but becomes unused.
