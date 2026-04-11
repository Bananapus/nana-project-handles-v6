# Audit Instructions

## Objective

Find issues that:
- Allow a setter to corrupt another setter's records.
- Break the two-way ENS verification (handle resolves without matching text record, or fails to resolve with matching text record).
- Enable ENS injection via malformed name parts.
- Cause `_namehash` to produce incorrect EIP-137 hashes.
- Allow the trusted forwarder to bypass intended access controls in unexpected ways.

## Scope

| File | Purpose |
|------|---------|
| `src/JBProjectHandles.sol` | Main contract: storage, validation, ENS verification |
| `src/interfaces/IJBProjectHandles.sol` | Interface: events, views, transactions |
| `script/Deploy.s.sol` | Sphinx-based deployment |

## System model

`JBProjectHandles` stores ENS name parts per `(chainId, projectId, setter)` and verifies handles by querying ENS text records. It is permissionless — anyone can set records, and verification happens at read time.

## Critical invariants

1. **Setter isolation:** `_ensNamePartsOf[chainId][projectId][setter]` can only be written when `_msgSender() == setter`.
2. **Verification correctness:** `handleOf` returns a non-empty string only when the ENS text record matches `chainId:projectId`.
3. **Name part validation:** Empty parts and parts containing dots are always rejected.
4. **Namehash correctness:** `_namehash` produces EIP-137 compliant hashes.

## Threat model

- **Cross-setter pollution:** Can setter A's transaction modify setter B's records?
- **ERC2771 spoofing:** Can a non-forwarder caller manipulate `_msgSender()`?
- **ENS injection:** Can malformed name parts cause `_namehash` to produce a hash that resolves to an unintended ENS name?
- **Text record bypass:** Can `handleOf` return a verified handle when the ENS text record doesn't match?
- **Dot bypass:** Can name parts with encoded dots (e.g., URL-encoded, Unicode) bypass the dot validation?

## Build and verification

```bash
npm install
forge build
forge test
```

## Test notes

Tests cover:
- Single and multi-level subdomain name parts (fuzz)
- Empty parts and empty array rejection
- Dot validation in name parts (fuzz)
- Handle resolution with matching text records
- Handle resolution with mismatched text records
- Handle resolution with unregistered ENS names
- Handle resolution with no parts set
