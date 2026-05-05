# Project Handles Risk Register

This file focuses on the ENS-dependency, setter-selection, and verification-model risks in `JBProjectHandles`. The contract does not hold funds, but bad assumptions here can still mislead frontends, crawlers, and operators.

## How to use this file

- Read `Priority risks` first.
- Use the detailed sections to separate storage behavior from verification behavior.
- Treat `Invariants to Verify` as the minimum proof that a returned handle is either verified or empty.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P1 | ENS dependency and resolver liveness | `handleOf` depends on ENS registry and resolver availability. | Treat handle lookup as soft metadata, not an availability guarantee. |
| P1 | Setter-selection mistakes | Different setters can publish different candidate handles for the same project. | Frontends must choose an explicit trust policy. |
| P2 | Non-normalized labels and stale ENS ownership | The contract stores raw labels and verifies only through the text-record round trip. | ENSIP-15 normalization offchain and periodic resolver rechecks. |

## 1. Trust Assumptions

- **ENS registry.** `handleOf` trusts the canonical ENS registry to return the correct resolver.
- **Resolver behavior.** `handleOf` trusts the resolver's `text(namehash, "juicebox")` response.
- **Trusted forwarder.** Writes are keyed by `_msgSender()` through `ERC2771Context`. A compromised forwarder can write into another account's setter slot.

## 2. Known Risks

- **Permissionless writes.** Anyone can call `setEnsNamePartsFor` for any `(chainId, projectId)`. This is intentional. Verification happens later in `handleOf`.
- **Setter trust is external.** The contract does not know which setter is official.
- **No delete path.** A setter cannot clear its record back to true onchain null state. It can only overwrite with different non-empty labels.
- **ENS label normalization is offchain.** The contract rejects dots and empty labels, but it does not normalize case or Unicode.
- **Resolver reverts resolve to empty.** `handleOf` returns `""` when no resolver exists or when the resolver's `text()` call reverts. A malicious or broken ENS resolver can therefore hide an otherwise stored handle, but it cannot forge verification or corrupt another setter's record.
- **Cross-chain semantics are social, not enforced.** `chainId` is only part of the lookup key and expected text-record value.

## 3. Integration Risks

- **Ownership changes do not migrate setter slots.** If a project changes owners, the old owner's entry remains stored.
- **Bots must not treat stored parts as verified output.** `ensNamePartsOf(...)` returns what a setter stored. `handleOf(...)` is the verification surface.
- **Read-only metadata can still be availability-sensitive.** A UI that blocks on `handleOf` can degrade when ENS or the resolver is unavailable.

## 4. Invariants to Verify

- `setEnsNamePartsFor` only writes to `_ensNamePartsOf[chainId][projectId][_msgSender()]`.
- Empty arrays, empty labels, and labels containing `.` always revert.
- `handleOf` returns `""` when no stored parts exist, no resolver exists, the resolver text call reverts, or the `juicebox` text record does not equal `"{chainId}:{projectId}"`.
- `_formatHandle` and `_namehash` preserve the intended label ordering.

## 5. Accepted Behaviors

### 5.1 Multiple competing setters are allowed

The contract intentionally allows many setters to publish candidate ENS handles for the same `(chainId, projectId)`. The consuming client must decide whose setter slot to trust.

### 5.2 Unverified records stay stored but resolve to empty

If a setter stores labels that never get the correct ENS text record, or if the ENS name later expires or changes hands, the labels remain onchain but `handleOf` returns `""`. This separation between storage and verification is intentional.
