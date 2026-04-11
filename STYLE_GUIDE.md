# Style Guide

How we write Solidity and organize repos across the Juicebox V6 ecosystem. `nana-core-v6` is the gold standard — when in doubt, match what it does.

## File Organization

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

## Pragma Versions

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

## Contract Structure

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

## Interface Structure

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

Full NatSpec on all contracts, functions, parameters, structs, enums, and mappings.

## Numbers

Use underscores for thousands separators:

```solidity
uint256 internal constant _FEE_HOLDING_SECONDS = 2_419_200; // 28 days
```

## Function Calls

Use named arguments for all function calls with 2 or more arguments — in both `src/` and `script/`:

```solidity
// Good
token.mint({account: beneficiary, amount: count});

// Bad
token.mint(beneficiary, count);
```

## Error Handling

- Validate inputs with explicit `revert` + custom error
- Use `try-catch` only for external calls to untrusted contracts

## DevOps

See `foundry.toml`, `.github/workflows/`, `package.json`, and `remappings.txt` in this repo for the standard configuration. All match the patterns described in the `nana-address-registry-v6` STYLE_GUIDE.md.
