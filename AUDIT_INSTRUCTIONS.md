# Audit Instructions

This repo stores and verifies ENS-based project handles. Audit it as a small identity registry whose main risks are verification mistakes and cross-setter corruption.

## Audit Objective

Find issues that:

- let a setter corrupt another setter's records
- break the two-way ENS verification model
- enable ENS injection through malformed name parts
- cause `_namehash` to produce incorrect EIP-137 hashes
- let the trusted forwarder bypass intended access control in unexpected ways

## Scope

| File | Purpose |
|------|---------|
| `src/JBProjectHandles.sol` | Main contract: storage, validation, ENS verification |
| `src/interfaces/IJBProjectHandles.sol` | Interface: events, views, transactions |
| `script/Deploy.s.sol` | Deployment |

## Start Here

1. `src/JBProjectHandles.sol`
2. `_namehash` and handle verification logic
3. `script/Deploy.s.sol`

## Security Model

`JBProjectHandles` stores ENS name parts per `(chainId, projectId, setter)` and verifies handles by querying ENS text records. It is permissionless. Anyone can store records, and verification happens only at read time.

## Roles And Privileges

| Role | Powers | How constrained |
|------|--------|-----------------|
| Setter | Store ENS name parts for its own namespace | Must not modify another setter's records |
| Trusted forwarder | Define `_msgSender()` in meta-tx flows | Must not let callers spoof another setter |

## Integration Assumptions

| Dependency | Assumption | What breaks if wrong |
|------------|------------|----------------------|
| ENS resolver and text records | Return the intended `chainId:projectId` binding | Handle verification becomes false-positive or false-negative |

## Critical Invariants

1. Setter isolation
   `_ensNamePartsOf[chainId][projectId][setter]` can only be written when `_msgSender() == setter`.

2. Verification correctness
   `handleOf` returns a non-empty string only when the ENS text record matches `chainId:projectId`.

3. Name part validation
   Empty parts and parts containing dots are always rejected.

4. Namehash correctness
   `_namehash` must produce EIP-137 compliant hashes.

## Attack Surfaces

- cross-setter writes to the `(chainId, projectId, setter)` namespace
- ERC-2771 sender handling
- malformed or ambiguous ENS name parts
- text-record verification and namehash calculation

## Verification

```bash
npm install
forge build --deny notes --skip "*/test/**" --skip "*/script/**"
forge test --deny notes
```
