# Project Handles Risk Register

This file focuses on the ENS-dependency, setter-selection, and verification-model risks in `JBProjectHandles`. The contract does not custody funds, but stale assumptions here can still mislead crawlers, frontends, and operators about a project's canonical handle.

## How to use this file

- Read `Priority risks` first; those are the highest-signal failure modes for integrators and indexers.
- Use the detailed sections to separate storage behavior from verification behavior.
- Treat `Invariants to Verify` as the minimum proof that a returned handle is either verified or empty.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P1 | ENS dependency and resolver liveness | `handleOf` depends on the canonical ENS registry and the node's resolver being available and well-behaved. | Treat handle lookup as soft metadata, not an authoritative availability guarantee. |
| P1 | Setter-selection mistakes | Multiple setters can store different candidate handles for the same project. Querying the wrong setter can show the wrong name or no name. | Frontends must choose an explicit trust policy for which setter to query. |
| P2 | Non-normalized labels and stale ENS ownership | The contract stores raw labels and only verifies via text-record round-trip. Bad normalization or expired ENS ownership makes stored data resolve to empty. | ENSIP-15 normalization off-chain and periodic resolver rechecks. |

## 1. Trust Assumptions

- **ENS registry.** `handleOf` trusts the canonical ENS registry at `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` to return the correct resolver for a node.
- **Resolver behavior.** `handleOf` trusts the resolver's `text(namehash, "juicebox")` response. A broken or malicious resolver can make lookup revert or return misleading data.
- **Trusted forwarder.** Writes are keyed by `_msgSender()` through `ERC2771Context`. A compromised forwarder can write records under another account's setter slot.

## 2. Known Risks

- **Permissionless writes.** Anyone can call `setEnsNamePartsFor` for any `(chainId, projectId)`. This is intentional. Verification happens later in `handleOf`, but storage can still accumulate arbitrary candidate records.
- **Setter trust is external.** The contract does not know which setter is "official". Frontends usually want the current project owner, but that policy lives off-chain.
- **No delete path.** `setEnsNamePartsFor` rejects empty arrays and empty labels, so a setter cannot clear its record to a true on-chain null state. It can only overwrite with different non-empty labels.
- **ENS label normalization is off-chain.** `setEnsNamePartsFor` rejects dots and empty labels, but it does not normalize case or Unicode. Callers must supply ENSIP-15-normalized labels or `handleOf` may never verify.
- **Resolver reverts are not caught.** `handleOf` returns `""` when no resolver exists, but if the resolver contract itself reverts on `text(...)`, the entire call reverts.
- **Cross-chain semantics are social, not enforced.** The `chainId` is just part of the lookup key and the expected `juicebox` text-record value. The contract does not verify that the referenced project exists on that chain.

## 3. Integration Risks

- **Ownership changes do not migrate setter slots.** If a project changes owners, the old owner's stored entry remains. Consumers that continue querying the old setter may keep showing a stale or unofficial handle.
- **Bots must not treat stored parts as verified output.** `ensNamePartsOf(...)` only returns what a setter stored. `handleOf(...)` is the verification surface.
- **Read-only metadata can still be availability-sensitive.** A UI that blocks on `handleOf` can degrade when ENS or the resolver is unavailable, even though no protocol funds are involved.

## 4. Invariants to Verify

- `setEnsNamePartsFor` only writes to `_ensNamePartsOf[chainId][projectId][_msgSender()]`.
- Empty arrays, empty labels, and labels containing `.` always revert.
- `handleOf` returns `""` when no stored parts exist, no resolver exists, or the `juicebox` text record does not equal `"{chainId}:{projectId}"`.
- `_formatHandle` and `_namehash` preserve the intended label ordering, where `["jbx","dao","foo"]` corresponds to `foo.dao.jbx.eth`.

## 5. Accepted Behaviors

### 5.1 Multiple competing setters are allowed

The contract intentionally allows many setters to publish candidate ENS handles for the same `(chainId, projectId)`. This is not a collision bug. The consuming client must decide whose setter slot to trust.

### 5.2 Unverified records stay stored but resolve to empty

If a setter stores labels that never receive the correct ENS text record, or if the ENS name later expires or changes hands, the stored labels remain on-chain but `handleOf` returns `""`. This is an accepted separation between storage and verification.
