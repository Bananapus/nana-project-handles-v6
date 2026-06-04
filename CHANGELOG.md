# V5 to V6 Changelog

## Scope

This is a V5-to-V6 migration changelog, not a package release log or commit history. `nana-project-handles-v6` has no deployed V5 package counterpart in `../../v5/evm`; it is a new V6 contract package.

## Current V6 Surface

- `JBProjectHandles`
- `IJBProjectHandles`

## Summary

- V6 introduces a project-handle registry that maps `(chainId, projectId, setter)` to ENS name parts and verifies them through an ENS text record.
- Handles are verified by checking the ENS `TEXT_KEY` value against the project identity, so a stored handle can resolve to an empty string when the ENS record is not valid.
- The package is not a replacement for a V5 deployed contract. It is a new V6 integration surface for project identity.

## ABI, Event, and Error Changes

- No V5 ABI exists to diff against. All project-handle ABI surface is new to V6.
- New functions:
  - `ENS_REGISTRY()`
  - `TEXT_KEY()`
  - `ensNamePartsOf(uint256,uint256,address)`
  - `handleOf(uint256,uint256,address)`
  - `setEnsNamePartsFor(uint256,uint256,string[])`
- New event:
  - `SetEnsNameParts`
- Migration-sensitive behavior:
  - `handleOf(...)` returns an empty string when the stored ENS name does not verify against the expected text record.
  - callers must provide ENS-normalized name parts; the contract rejects dots and ASCII control characters.

## Machine-Checked ABI Coverage

Generated from Foundry `out/**/*.json` artifacts, filtered to this repo's own runtime source roots and excluding tests, scripts, and dependencies.

- V5 comparison package: none; this is a new V6 runtime ABI surface.
- Own-source ABI artifacts compared: V6 `2`, V5 `0`.
- Contract/interface coverage: `2` added, `0` removed, `0` shared names with ABI changes, `0` shared names ABI-identical.
- Shared-name ABI item deltas: `0` added, `0` removed, `0` modified.

Added V6 ABI artifacts:
- `IJBProjectHandles` from `src/interfaces/IJBProjectHandles.sol`: `5` functions, `1` events, `0` errors.
- `JBProjectHandles` from `src/JBProjectHandles.sol`: `7` functions, `1` events, `4` errors.

Generated event/error name deltas:
- Event names added:
  - `SetEnsNameParts`.
- Error names added:
  - `JBProjectHandles_EmptyNamePart`, `JBProjectHandles_EthPartNotAllowed`, `JBProjectHandles_InvalidNamePart`, `JBProjectHandles_NoParts`.

## Migration Notes

- Treat handles as a new optional V6 identity layer.
- Index `SetEnsNameParts` and verify current ENS text records when displaying handles.
- Do not assume a V5 project has an existing handle unless this V6 registry says it does.
