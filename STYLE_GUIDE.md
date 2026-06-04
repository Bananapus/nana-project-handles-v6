# Style Guide

How we write Solidity and organize repos across the Juicebox V6 ecosystem. `nana-core-v6` is the gold standard — when in doubt, match what it does.

## File organization

```
src/
├── Contract.sol              # Main contracts in root
├── abstract/                 # Base contracts (JBPermissioned, JBControlled)
├── enums/                    # One enum per file
├── interfaces/               # One interface per file, prefixed with I
├── libraries/                # Pure/view logic, prefixed with JB
├── periphery/                # Utility contracts (deadlines, price feeds)
└── structs/                  # One struct per file, prefixed with JB
```

One contract/interface/struct/enum per file. Name the file after the type it contains.

## Pragma versions

```solidity
// Contracts — pin to exact version
pragma solidity 0.8.28;

// Interfaces, structs, enums — caret for forward compatibility
pragma solidity ^0.8.0;

// Libraries — pin to exact version like contracts
pragma solidity 0.8.28;
```

## Imports

Named imports only. Grouped by source, alphabetized within each group:

```solidity
// External packages (alphabetized)
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {mulDiv} from "@prb/math/src/Common.sol";

// Local: abstract contracts
import {JBPermissioned} from "./abstract/JBPermissioned.sol";

// Local: interfaces (alphabetized)
import {IJBController} from "./interfaces/IJBController.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBMultiTerminal} from "./interfaces/IJBMultiTerminal.sol";

// Local: libraries (alphabetized)
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBFees} from "./libraries/JBFees.sol";

// Local: structs (alphabetized)
import {JBAccountingContext} from "./structs/JBAccountingContext.sol";
import {JBSplit} from "./structs/JBSplit.sol";
```

## Contract structure

Section banners divide the contract into a fixed ordering. Every contract with 50+ lines uses these banners:

```solidity
/// @notice One-line description.
contract JBExample is JBPermissioned, IJBExample {
    // A library that does X.
    using SomeLib for SomeType;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBExample_SomethingFailed(uint256 amount);

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
    //*********************************************************************//

    uint256 public constant override FEE = 25;

    //*********************************************************************//
    // ----------------------- internal constants ------------------------ //
    //*********************************************************************//

    uint256 internal constant _FEE_BENEFICIARY_PROJECT_ID = 1;

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    IJBDirectory public immutable override DIRECTORY;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // -------------------- private stored properties -------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // ----------------------- external views ---------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // ----------------------- internal views ---------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // ----------------------- private helpers --------------------------- //
    //*********************************************************************//
}
```

Functions are alphabetized within each section.

## Interface structure

```solidity
/// @notice One-line description.
interface IJBExample is IJBBase {
    // Events (with full NatSpec)

    /// @notice Emitted when X happens.
    /// @param projectId The ID of the project.
    /// @param amount The amount transferred.
    event SomethingHappened(uint256 indexed projectId, uint256 amount);

    // Views (alphabetized)

    /// @notice The directory of terminals and controllers.
    function DIRECTORY() external view returns (IJBDirectory);

    // State-changing functions (alphabetized)

    /// @notice Does the thing.
    /// @param projectId The ID of the project.
    /// @return result The result.
    function doThing(uint256 projectId) external returns (uint256 result);
}
```

**Rules:**
- Events first, then views, then state-changing functions
- No custom errors in interfaces — errors belong in the implementing contract
- Full NatSpec on every event, function, and parameter
- Alphabetized within each group

## Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| Contract | PascalCase | `JBMultiTerminal` |
| Interface | `I` + PascalCase | `IJBMultiTerminal` |
| Library | PascalCase | `JBCashOuts` |
| Error | `ContractName_ErrorName` | `JBMultiTerminal_FeeTerminalNotFound` |
| Public constant | `ALL_CAPS` | `FEE`, `MAX_FEE` |
| Internal constant | `_ALL_CAPS` | `_FEE_HOLDING_SECONDS` |
| Public immutable | `ALL_CAPS` | `DIRECTORY`, `PERMISSIONS` |
| Public/external function | `camelCase` | `cashOutTokensOf` |
| Internal/private function | `_camelCase` | `_processFee` |
| Function parameter | `camelCase` (no underscores) | `projectId`, `cashOutCount` |

## NatSpec

Every contract, interface, library, error, event, function, return value, state variable, mapping, and struct
member carries complete NatSpec. NatSpec describes the current behavior as the only behavior (see Comments).

Required tags by member:
- **Contract / interface / library** — `@notice` (what it is and does). Add `@dev` for cross-cutting notes such as storage-layout choices, invariants it upholds, or integration assumptions.
- **Error** — `@notice` stating exactly when it reverts and the reason the guard exists.
- **Event** — `@notice` (when it's emitted) and a `@param` for every field.
- **Function** — `@notice` (what it does, user-facing), a `@param` for every parameter, and a named `@return` for every return value. Add `@dev` whenever a non-obvious mechanic, ordering requirement, edge case, rounding choice, permission rule, or invariant explains the WHY behind the behavior.
- **State variable** — `@notice` (what it holds). Add `@dev` for how/when it is maintained or any invariant it preserves. For a mapping, also a `@custom:param` for every key, outer to inner.
- **Struct** — `@custom:member` for every field.

**Contracts:**
```solidity
/// @notice One-line description of what the contract does.
contract JBExample is IJBExample {
```

**Errors:**
```solidity
/// @notice Thrown when the caller is not the project's controller, so only the controller can record balances.
error JBExample_Unauthorized(address caller);
```

**Events:**
```solidity
/// @notice Emitted when funds are added to a project's balance.
/// @param projectId The ID of the project funds were added to.
/// @param amount The amount added.
event AddToBalance(uint256 indexed projectId, uint256 amount);
```

**Functions:**
```solidity
/// @notice Records funds being added to a project's balance.
/// @dev Reverts if the project has no accounting context for the token, so the token must be registered first.
/// @param projectId The ID of the project which funds are being added to.
/// @param token The token being added.
/// @param amount The amount added, as a fixed point number with the same decimals as the terminal.
/// @return surplus The new surplus after adding.
function recordAddedBalanceFor(
    uint256 projectId,
    address token,
    uint256 amount
) external override returns (uint256 surplus) {
```

**State variables and mappings:**
```solidity
/// @notice How many NFTs an address owns from a hook, totaled across all tiers.
/// @dev Maintained as a running aggregate in `recordTransferForTier`, so this read is O(1) instead of O(tiers).
/// @custom:param hook The 721 contract to check.
/// @custom:param owner The address to get the balance of.
mapping(address hook => mapping(address owner => uint256)) public override balanceOf;
```

**Structs:**
```solidity
/// @custom:member duration The number of seconds the ruleset lasts for. 0 means it never expires.
/// @custom:member weight How many tokens to mint per unit paid (18 decimals).
/// @custom:member weightCutPercent How much weight decays each cycle (9 decimals).
struct JBRulesetConfig {
    uint32 duration;
    uint112 weight;
    uint32 weightCutPercent;
}
```

## Comments

Every non-trivial statement or block carries an inline `//` comment that explains WHY it exists — the reason,
invariant, edge case, ordering requirement, or guarantee it provides — in plain English. Comment the intent, not
the literal syntax: `// increment i` adds nothing; `// advance the index before the external call so a re-entrant
call cannot replay this entry` does.

Write every comment and NatSpec as if the current implementation is the first and the last:
- No references to other implementations in time: no "previously", "now", "used to", "changed to", "legacy",
  "old/new approach", "v1/v2", "temporary", or "for backwards compatibility".
- No references to audits, audit tools, reviewers, or finding/issue codes. The code stands on its own reasoning;
  describe the mechanism and its rationale directly.
- Describe a behavior by what it guarantees, not by the history of how it came to be.

A `// forge-lint: disable-next-line(<rule>)` directive sits on its own line directly above the line it applies to —
never merged into a prose comment, or the formatter reflows it into the prose and it silently disables nothing.

## Numbers

Use underscores for thousands separators:

```solidity
uint256 internal constant _FEE_HOLDING_SECONDS = 2_419_200; // 28 days
```

## Function calls

Use named arguments for all function calls with 2 or more arguments — in both `src/` and `script/`:

```solidity
// Good
token.mint({account: beneficiary, amount: count});

// Bad
token.mint(beneficiary, count);
```

## Error handling

- Validate inputs with explicit `revert` + custom error
- Use `try-catch` only for external calls to untrusted contracts

## Linting

The committed source builds, lints, and tests with zero errors, warnings, and notes. CI runs
`forge build --deny notes --sizes ...` and `forge test --deny notes ...`; `--deny notes` escalates any solc warning
or solar lint note to a hard failure, so anything less than clean fails CI. Do not silence a real issue — fix it.
The only acceptable suppression is a justified, standalone `// forge-lint: disable-next-line(<rule>)` for a rule
that is genuinely inapplicable (for example a multi-day timestamp comparison flagged by `block-timestamp`).

Solar (Foundry's built-in linter) runs automatically during `forge build`. It scans all `.sol` files in `libs`
directories, including `node_modules`. All test helpers use relative imports (e.g. `../../src/structs/JBRuleset.sol`),
not bare `src/` imports, so solar can resolve paths when the helper is consumed via npm in downstream repos.

## DevOps

See `foundry.toml`, `.github/workflows/`, `package.json`, and `remappings.txt` in this repo for the standard configuration. All match the patterns described in the `nana-address-registry-v6` STYLE_GUIDE.md.
