# Changelog

## 0.0.25 — Raise dependency floors; document conventions

- Raise dependency floors to the latest published versions (`@bananapus/core-v6`: `^0.0.72 → ^0.0.78`).
- Document NatSpec, comment, and lint conventions in `STYLE_GUIDE.md`.

## 0.0.24 — Bound the resolver read in `handleOf`

- `_textRecordOf` now reads the ENS resolver through a low-level call that (1) forwards only a bounded gas stipend (`_RESOLVER_GAS_LIMIT = 100_000`) and (2) copies at most `64 + _MAX_TEXT_RECORD_LENGTH` bytes of the response. Previously the resolver response was copied in full before the length cap was applied, so a name-owner-controlled resolver could return a huge response and force `handleOf` to run out of gas (or revert) instead of soft-failing to an empty handle. Well-behaved resolvers resolve exactly as before.

## 0.0.12 — Bump nana-core-v6 to ^0.0.53

- `@bananapus/core-v6`: `0.0.39 → ^0.0.53` ([PR #145](https://github.com/Bananapus/nana-core-v6/pull/145)). The pin was previously exact (`0.0.39`); switching to caret to track minor releases.
- All `JBRulesetMetadata` test literals patched to include `pauseCrossProjectFeeFreeInflows: false`.

## v5 to v6

### Solidity version

- **v5:** `pragma solidity 0.8.23`
- **v6:** `pragma solidity 0.8.28`

### EVM target

- **v5:** `evm_version = 'paris'`
- **v6:** `evm_version = 'cancun'`

### Removed `_contextSuffixLength` override

The v5 contract had an explicit `_contextSuffixLength()` override that just called `super._contextSuffixLength()`. This is unnecessary in OpenZeppelin v5+ and has been removed.

### Package name

- **v5:** `@bananapus/project-handles`
- **v6:** `@bananapus/project-handles-v6`

### Dependencies

- **v5:** `@bananapus/core` (runtime dependency) + `@openzeppelin/contracts` 5.2.x
- **v6:** `@bananapus/core-v6` 0.0.39 (devDependency only, for tests) + `@openzeppelin/contracts` 5.6.1

The core dependency moved to devDependencies because the contract itself doesn't import from core — only the test file uses `JBProjects` for mocking.

### Deployment

- **v5:** Deployed with `CoreDeploymentLib` integration for trusted forwarder lookup.
- **v6:** Standalone `Deploy.s.sol` with `CoreDeploymentLib` from `@bananapus/core-v6` for trusted forwarder.

### Style changes

- Named imports throughout (v6 convention)
- V6 section banner ordering (external transactions before external views)
- Named arguments for multi-arg function calls
- V6 NatSpec style (single `/// @notice` lines)
- V6 test naming (`test_functionName_description`)
- Removed `oldHandle` references from tests (no legacy fallback in v6)

### Functional changes

- `setEnsNamePartsFor` now rejects `"eth"` as a name part (`JBProjectHandles_EthPartNotAllowed` error) and rejects control characters in name parts.
- `handleOf` now wraps ENS registry calls in try/catch and performs a code-length check, so it returns `""` on chains without ENS instead of reverting.

### Breaking ABI changes

New error: `JBProjectHandles_EthPartNotAllowed`. ABIs generated from v5 will not include this error.

### Indexer impact

Event shape is identical. The new error only affects write-side callers.
