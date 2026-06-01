# Invariants of `nana-project-handles-v6`

Scope: the `JBProjectHandles` contract — a permissionless ENS handle registry for Juicebox projects. It stores ENS name parts keyed by `(chainId, projectId, setter)` and only returns a "verified" handle when the ENS name's `juicebox` text record points back to that same project.

| Item | Detail |
|---|---|
| Contract | `JBProjectHandles` (single contract, ~317 lines) |
| Storage shape | `mapping(chainId => mapping(projectId => mapping(setter => string[] ensParts)))` |
| Trust model | permissionless writes; verification is read-time and bidirectional (this contract ↔ ENS text record) |
| Admin surface | **none** — no owner, no pause, no upgrade, no delete |
| Funds held | **none** |
| Dependencies | ENS registry at `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`, `ITextResolver`, ERC-2771 trusted forwarder |

`JBProjectHandles` is a verifiable-claims registry, not a canonical ownership registry. The contract knows nothing about Juicebox project ownership — selecting which `setter` to trust is a client-side policy decision.

---

# Section A — Guarantees to Reading Clients (Frontends, Indexers, Bots)

## A.1 Read-path semantics

- `handleOf(chainId, projectId, setter)` returns either:
  - the formatted ENS handle string (e.g. `"foo.dao.jbx"`) **iff** the stored name parts resolve to an ENS namehash whose resolver's `juicebox` text record equals `"{chainId}:{projectId}"`, OR
  - the empty string `""` in every other case.
- The function is `view` and never mutates state, never reverts on missing/malformed ENS data, and never charges fees.
- A returned non-empty string means: a setter publicly committed to those name parts onchain AND the ENS name owner committed (at read time) to pointing the `juicebox` text record back at the same `(chainId, projectId)`.
- A returned empty string means **one** of: no stored parts under that `setter`; the ENS registry has no code on the current chain; the namehash has no resolver; the resolver call reverted or exceeded its `_RESOLVER_GAS_LIMIT` (100,000) gas stipend; the resolver returned malformed ABI data; the resolver claimed a text record longer than `_MAX_TEXT_RECORD_LENGTH` (256) bytes; or the resolver's text record does not equal the expected `chainId:projectId` string.
- `ensNamePartsOf(chainId, projectId, setter)` returns the raw stored parts without verification. Clients should treat this as **unverified** — it shows what a setter claimed, not what ENS confirms.

## A.2 Protections against forged or hijacked handles

- A read for `(chainId, projectId, setter=X)` can only return name parts that address `X` itself wrote. No other address can poison `X`'s slot. Setter slots are isolated by the `_msgSender()` storage key (`src/JBProjectHandles.sol:136`).
- A malicious or broken ENS resolver can only **hide** an otherwise-resolvable handle (forcing `handleOf` to return `""`) — it cannot make `handleOf` return a resolver-chosen string or another setter's stored parts. The low-level staticcall to the resolver (`src/JBProjectHandles.sol:290-352`) soft-fails on failure, malformed ABI, or oversized response.
- A name-owner-controlled resolver cannot grief readers with unbounded gas costs. The resolver call forwards only `_RESOLVER_GAS_LIMIT = 100_000` (`src/JBProjectHandles.sol:68, 315`) and copies at most `64 + _MAX_TEXT_RECORD_LENGTH` bytes of the response (`src/JBProjectHandles.sol:62, 299, 326`) — so neither the resolver's own execution nor its response size can drive the read's gas. `chainId:projectId` is always well under the byte cap.
- Reads against chains without ENS deployed (`address(ENS_REGISTRY).code.length == 0`) return `""` instead of reverting (`src/JBProjectHandles.sol:191`). Multi-chain frontends will not break on non-mainnet calls.

## A.3 What clients must do themselves (and why this contract cannot do it for them)

- **Choose the trusted setter.** This contract has no notion of "the project owner". Frontends will usually pass the current project NFT owner from `nana-core-v6`'s `JBProjects`, but that policy lives offchain.
- **Apply ENSIP-15 normalization before storing AND before trusting.** This contract rejects only ASCII control characters (`< 0x20`), DEL (`0x7F`), dots (`.`), the empty string, and the exact label `"eth"`. It does not normalize case or Unicode. Non-normalized labels can store successfully and never verify — by design.
- **Treat a stored record as soft metadata.** A handle returned today can return `""` tomorrow if the ENS name's owner changes or the text record drifts. Cache accordingly.

---

# Section B — Guarantees to Setters (Anyone Publishing a Candidate Handle)

## B.1 Powers any setter retains

- **Write to your own slot.** Any address can call `setEnsNamePartsFor(chainId, projectId, parts)` for **any** `(chainId, projectId)`. The write lands in `_ensNamePartsOf[chainId][projectId][_msgSender()]` — your own slot, not someone else's. There is no project-ownership check (`src/JBProjectHandles.sol:96-135`).
- **Overwrite your own slot.** Calling `setEnsNamePartsFor` again with new parts replaces the prior array. No history is preserved onchain.
- **Cross-chain claims.** The `chainId` parameter is data, not contract state — a single mainnet deployment can carry candidate handles for projects on any EVM chain.
- **Meta-transactions.** Via ERC-2771, a trusted forwarder can submit a `setEnsNamePartsFor` call on behalf of the original sender; the storage slot is `_msgSender()` (i.e. the original sender, not the forwarder) (`src/JBProjectHandles.sol:18, 81, 236-238`).

## B.2 Powers no setter has

- **Cannot overwrite another setter's record.** Storage is keyed by `_msgSender()`. Address A's parts never land in address B's slot.
- **Cannot delete a slot back to onchain null.** There is no clear/zeroize entrypoint. The minimum write is one non-empty, non-`"eth"`, non-control-character label. "Clearing" effectively means overwriting with placeholder data that will never verify against ENS.
- **Cannot force `handleOf` to return your stored parts.** Verification still requires the ENS name's `juicebox` text record to match `chainId:projectId` at read time. A setter without control of the corresponding ENS name's resolver can store parts but never produce a non-empty `handleOf`.
- **Cannot bypass label validation.** The contract reverts on: empty `parts[]`, any empty part, any part equal to `"eth"`, any part containing a byte `< 0x20`, `0x7F`, or `.` (`src/JBProjectHandles.sol:101-127`).
- **Cannot reserve a label.** Two different addresses can store identical name parts for identical `(chainId, projectId)` — they each occupy their own setter slot. There is no global name-collision rule.

## B.3 Guarantees about the write itself

- A successful `setEnsNamePartsFor` emits exactly one `SetEnsNameParts(chainId, projectId, handle, parts, caller)` event (`src/JBProjectHandles.sol:132-134`) where `caller == _msgSender()`. Indexers can rebuild the entire setter-slot state from this one event.
- The write is unconditional on ENS state. There is no ENS lookup during write. Storage and verification are decoupled — by design (see RISKS.md §2 and §5.2).
- Validation failures revert the entire transaction; no partial state is written.

---

# Section C — Per-Function Operation Inventory

`JBProjectHandles` has one mutating external function, two view external functions, and a constructor. Everything else is internal.

## C.1 `constructor(address trustedForwarder)` — `src/JBProjectHandles.sol:87`

- Stores `trustedForwarder` into immutable ERC-2771 context. Cannot be changed after deploy.
- **Invariant:** the trusted forwarder is set once at deploy. A compromised forwarder can write into any setter slot it impersonates (documented in RISKS.md §1) — operator-side hazard for whoever deploys, not a contract-side flaw.

## C.2 `setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts)` — `src/JBProjectHandles.sol:102-141`

- **Caller:** anyone (or any sender routed via the trusted ERC-2771 forwarder).
- **Effect:** writes `parts` into `_ensNamePartsOf[chainId][projectId][_msgSender()]` after validation; emits `SetEnsNameParts`.
- **Reverts on:**
  - `parts.length == 0` → `JBProjectHandles_NoParts`
  - any `parts[i]` is the empty string → `JBProjectHandles_EmptyNamePart`
  - any `parts[i]` equals `"eth"` (compared by `keccak256`) → `JBProjectHandles_EthPartNotAllowed`
  - any byte in any `parts[i]` is `< 0x20`, `== 0x7F`, or `== '.'` → `JBProjectHandles_InvalidNamePart`
- **Invariants preserved:**
  - storage write is scoped to `(chainId, projectId, _msgSender())` only — never another setter's slot
  - the stored array length is always `≥ 1` and every element is `≥ 1` byte, contains no dots/controls/DEL, and is not `"eth"`
  - the emitted event's `caller` field equals the slot key
- **Cannot:** verify or interact with ENS; check project ownership; touch funds; affect any other setter's record; lock or reserve a name.

## C.3 `ensNamePartsOf(uint256 chainId, uint256 projectId, address setter) view → string[]` — `src/JBProjectHandles.sol:152-163`

- **Caller:** anyone.
- **Effect:** returns the raw stored array for `(chainId, projectId, setter)`, or an empty array if none.
- **Invariant:** the return value is **unverified**. Consumers must use `handleOf` for verification, not this view (documented in RISKS.md §3).

## C.4 `handleOf(uint256 chainId, uint256 projectId, address setter) view → string` — `src/JBProjectHandles.sol:171-211`

- **Caller:** anyone.
- **Effect:** loads stored parts; if empty, returns `""`. Else computes EIP-137 namehash via `_namehash`; resolves resolver via `ENS_REGISTRY.resolver`; pulls text record via `_textRecordOf`; if the record equals `"{chainId}:{projectId}"`, returns the formatted handle; otherwise returns `""`.
- **Invariants:**
  - `view` — no state mutation, no events
  - never reverts on a missing/malformed ENS state path; soft-fails to `""`
  - the returned handle, when non-empty, has been validated against the live ENS text record at the block of the call
  - returns `""` for chains without ENS deployed (`code.length == 0` check at `:191`)
- **Cannot:** mutate state; emit; verify project ownership; verify Unicode normalization of the stored labels (clients must do this).

## C.5 Internal helpers (no external surface)

- **`_formatHandle(parts) pure → string`** — reverses parts and joins with `"."` (e.g. `["jbx","dao","foo"] → "foo.dao.jbx"`). Used by both write-emit and read-verify, so the visible handle string is deterministic from storage (`src/JBProjectHandles.sol:220-232`).
- **`_namehash(parts) pure → bytes32`** — EIP-137 namehash with an implicit trailing `"eth"` suffix label (`src/JBProjectHandles.sol:250-271`). Iterates the formatted handle right-to-left at dot boundaries.
- **`_slice(input, start, end) pure → bytes`** — pure substring (`src/JBProjectHandles.sol:278-284`).
- **`_textRecordOf(textResolver, hashedName) view → string`** — bounded low-level staticcall to `ITextResolver.text`: forwards only `_RESOLVER_GAS_LIMIT` gas, copies at most `64 + _MAX_TEXT_RECORD_LENGTH` bytes of the response, and rejects failed calls, non-standard ABI offset (`!= 32`), a claimed length over `_MAX_TEXT_RECORD_LENGTH`, or a response shorter than the claimed length; soft-fails to `""` in all failure paths (`src/JBProjectHandles.sol:290-352`).
- **`_msgSender() / _msgData()`** — ERC-2771 forwarder-aware overrides (`src/JBProjectHandles.sol:236-244`). Determines the storage-key identity for writes.

---

# Section D — Cross-Cutting Invariants

1. **Permissionless writes, verified reads.** Anyone can write into their own setter slot at any time, for any `(chainId, projectId)`. Reads only return non-empty when ENS independently confirms the back-pointer. The two-way handshake is the only assurance offered; the contract does not pretend to vouch for stored data.

2. **Setter isolation is absolute.** `_msgSender()` is the only key under which a write lands. There is no global registry, no project-owner override, no admin path that can write into someone else's slot. A compromised ERC-2771 forwarder can spoof one specific sender's slot, but cannot scribble across slots.

3. **Storage and verification are decoupled.** A successful `setEnsNamePartsFor` never consults ENS. A `handleOf` never mutates storage. ENS outages, resolver bugs, or reverse-record drift never corrupt stored state; they only make `handleOf` return `""` until the situation resolves.

4. **Soft-fail everywhere on the read path.** Every ENS-side failure mode (no registry on this chain, no resolver, resolver reverts, resolver exceeds its gas stipend, ABI-malformed return, oversized return, wrong text record) collapses to `handleOf == ""`. Reads cannot revert under hostile resolver behavior.

5. **Resolver gas-griefing is bounded.** A name-owner-controlled resolver controls both how much gas it burns and how much data it returns. The read forwards only `_RESOLVER_GAS_LIMIT = 100_000` gas to the resolver (`src/JBProjectHandles.sol:68, 315`) and copies at most `64 + _MAX_TEXT_RECORD_LENGTH` bytes of the response before the equality check (`src/JBProjectHandles.sol:62, 299, 326`). Neither the resolver's execution nor its return-data size can drive `handleOf` gas, so an oversized or expensive response soft-fails to `""` instead of running the read out of gas.

6. **Label validation is a real safety boundary, not cosmetic.** Dot rejection is what makes the namehash labeling unambiguous. Control-character / DEL rejection forecloses some non-printing-character spoofing. `"eth"` rejection forecloses the `foo.eth.eth` ambiguity. Weakening any of these without re-deriving the namehash assumptions is a breaking change (per ARCHITECTURE.md §"Safe Change Guide").

7. **Unicode normalization is the caller's job, by contract.** The contract intentionally does not enforce ENSIP-15. A previous denylist of bidi/format codepoints was incomplete and gave a false sense of safety, so it was removed (`src/JBProjectHandles.sol:89-93` NatSpec). Clients must normalize before storing AND before trusting.

8. **No name reservation, no collision rules.** Two different addresses may store identical name parts for the same `(chainId, projectId)`. Whichever setter the client chooses to trust wins for that client. There is no "first one wins" or "project owner wins" semantic onchain.

9. **No delete path; overwrite-only.** Once a setter writes, the slot can be replaced with new non-empty parts but cannot be zeroed. The minimum "cleared" state is non-empty parts that will never verify (e.g. a label pointing at an ENS name whose `juicebox` text record is wrong). Indexers can treat lingering parts as historical but not necessarily canonical.

10. **`chainId` is data, not destiny.** A mainnet-deployed `JBProjectHandles` can hold candidate handles for projects on any chain. Cross-chain semantics are entirely social: the ENS lookup happens on the chain where the contract runs (typically mainnet), while the encoded `chainId:projectId` text record can name a project anywhere.

---

# Section E — Out-of-Scope Centralization Caveats

These are **not** third-party attack vectors but are powers held outside the contract's protocol surface:

- **No contract-level admin exists.** There is no owner, no pause, no upgrade, no curation surface. `ADMINISTRATION.md` documents the deliberately-flat control model.
- **ERC-2771 trusted forwarder.** Constructor-immutable. A compromised forwarder can spoof one sender per submitted meta-tx and write into that sender's setter slot. It cannot read or write across other setters' slots. Mitigation lives at the forwarder layer, outside this repo.
- **ENS registry contract** at `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` is trusted to return the correct resolver for a given namehash. ENS DAO-level governance changes to that registry are upstream concerns.
- **ENS resolver per name.** The owner of each ENS name controls its resolver. They can break their own `handleOf` reads at any time by changing or revoking the `juicebox` text record. They cannot break someone else's handle or another setter's slot.
- **Client-side setter-selection policy.** Whichever address a frontend or indexer chooses as the "authoritative" setter is offchain policy. The contract enforces nothing about this choice. A UI that picks the wrong setter shows a wrong (or empty) handle but cannot corrupt onchain state.
- **No funds held.** A compromise of any party listed above cannot extract value from this contract because there is none here. The blast radius is at most "wrong displayed handle".

---

# Section F — Key Code References

- Storage key (setter isolation): `src/JBProjectHandles.sol:79, 136, 162, 182`
- Label validation (empty, `"eth"`, control bytes, DEL, dots): `src/JBProjectHandles.sol:107-133`
- ENS registry constant: `src/JBProjectHandles.sol:47`
- Text-key constant (`"juicebox"`): `src/JBProjectHandles.sol:50`
- ERC-2771 forwarder wiring: `src/JBProjectHandles.sol:18, 87, 236-244`
- `handleOf` read flow + soft-fail branches: `src/JBProjectHandles.sol:171-211`
- ENS-not-deployed soft-fail: `src/JBProjectHandles.sol:191`
- Text-record byte cap (`_MAX_TEXT_RECORD_LENGTH = 256`): `src/JBProjectHandles.sol:62, 299, 326`
- Resolver gas stipend (`_RESOLVER_GAS_LIMIT = 100_000`): `src/JBProjectHandles.sol:68, 315`
- Bounded low-level resolver staticcall with ABI hardening: `src/JBProjectHandles.sol:290-352`
- EIP-137 namehash with implicit `"eth"` suffix: `src/JBProjectHandles.sol:250-271`
- Event for indexer reconstruction: `src/JBProjectHandles.sol:138-140` and `src/interfaces/IJBProjectHandles.sol:19-21`

For the broader threat model around this contract — ENS dependency, setter-selection failure modes, accepted multi-setter behavior — see `RISKS.md`. For the deliberately-empty admin surface, see `ADMINISTRATION.md`.
