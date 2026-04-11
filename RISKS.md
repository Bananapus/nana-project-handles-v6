# Risks

## Priority P1 — highest impact

### ENS dependency

`handleOf` makes external calls to the ENS registry and text resolver. If either is unreachable or reverts, handle resolution fails. This is a read-only dependency — no funds at risk, but frontend display degrades.

### Stale text records

A project owner may set name parts but then lose control of the ENS name (expiry, transfer). The stored record remains, but `handleOf` will return `""` because the text record no longer matches. No on-chain harm, but clients may show a "loading" state.

### Setter trust model

The contract stores records keyed by `_msgSender()`. Frontends must decide which `setter` address to query — typically the current project owner. If a frontend uses the wrong `setter`, it may display an incorrect or missing handle.

## Priority P2

### Anyone can set records

The contract is fully permissionless. Anyone can call `setEnsNamePartsFor` for any `(chainId, projectId)`. This is by design — the verification happens in `handleOf` via ENS text record matching. But it means storage can accumulate records from arbitrary setters.

### No deletion

There is no function to remove a handle record. Setting new parts overwrites old ones, but there's no way to clear a record to "no handle." A setter can overwrite with different parts but cannot delete their entry entirely.

## Known risks

| Risk | Mitigation |
|------|------------|
| ENS registry returns wrong resolver | ENS registry is immutable and battle-tested; contract trusts it |
| Text record spoofing | Only the ENS name owner can set text records; two-way verification prevents spoofing |
| EIP-137 namehash mismatch | `_namehash` implementation matches the standard; tested against known hashes |
| Non-canonical ENS labels | The contract does not normalize labels (e.g. lowercase). Callers must provide ENSIP-15-normalized labels or `handleOf` will fail to resolve. This is by design — on-chain normalization is prohibitively expensive. |
| Dot injection in name parts | `setEnsNamePartsFor` validates that no parts contain dots |

## Invariants to verify

1. `_ensNamePartsOf[chainId][projectId][setter]` is only modified by transactions where `_msgSender() == setter`.
2. `handleOf` never modifies state — it is a pure verification function.
3. Name parts with empty strings or dots are always rejected.
4. The namehash computation matches EIP-137 for all valid ENS names.

## Accepted behavior

- Multiple setters can store different ENS names for the same `(chainId, projectId)`. This is intentional — the frontend chooses which setter to trust.
- `handleOf` returns `""` for any unverified handle, including handles where the ENS text record is missing or mismatched.
