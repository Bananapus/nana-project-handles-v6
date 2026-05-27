// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBProjectHandles} from "../../src/JBProjectHandles.sol";

contract JBProjectHandlesUnicodeSpoofTest is Test {
    JBProjectHandles internal handles;

    address internal constant SETTER = address(0xBEEF);

    function setUp() public {
        handles = new JBProjectHandles(address(0));
    }

    /// @notice Unicode formatting characters (bidi overrides, zero-width joiners, BOM, etc.) are intentionally
    /// NOT rejected on-chain. The previous denylist was incomplete (missed non-bidi invisibles like U+2060, the
    /// Tags block, etc.) and lent a false sense of safety. Clients must apply ENSIP-15 normalization off-chain
    /// before trusting `handleOf`'s output. This regression test pins that "no filter" behavior so a future
    /// re-introduction of a partial filter is caught.
    function test_setEnsNamePartsFor_acceptsUnicodeFormattingCharacters() public {
        string[17] memory previouslyBlocked = [
            unicode"safe\u061Cevil",
            unicode"safe\u200Bevil",
            unicode"safe\u200Cevil",
            unicode"safe\u200Devil",
            unicode"safe\u200Eevil",
            unicode"safe\u200Fevil",
            unicode"safe\u202Aevil",
            unicode"safe\u202Bevil",
            unicode"safe\u202Cevil",
            unicode"safe\u202Devil",
            unicode"safe\u202Eevil",
            unicode"safe\u2066evil",
            unicode"safe\u2067evil",
            unicode"safe\u2068evil",
            unicode"safe\u2069evil",
            unicode"safe\uFEFFevil",
            unicode"safe\u2060evil" // U+2060 was missed by the old denylist \u2014 same equivalence class.
        ];

        for (uint256 i; i < previouslyBlocked.length;) {
            string[] memory parts = new string[](1);
            parts[0] = previouslyBlocked[i];

            vm.prank(SETTER);
            handles.setEnsNamePartsFor({chainId: 1, projectId: 100 + i, parts: parts});

            assertEq(handles.ensNamePartsOf({chainId: 1, projectId: 100 + i, setter: SETTER}), parts);

            unchecked {
                ++i;
            }
        }
    }

    function test_setEnsNamePartsFor_acceptsAdjacentUnicodeBoundaryCodepoints() public {
        string[6] memory previouslyAllowed = [
            unicode"safe\u200Aokay",
            unicode"safe\u2010okay",
            unicode"safe\u2029okay",
            unicode"safe\u202Fokay",
            unicode"safe\u2065okay",
            unicode"safe\u206Aokay"
        ];

        for (uint256 i; i < previouslyAllowed.length;) {
            string[] memory parts = new string[](1);
            parts[0] = previouslyAllowed[i];

            vm.prank(SETTER);
            handles.setEnsNamePartsFor({chainId: 1, projectId: 10 + i, parts: parts});

            assertEq(handles.ensNamePartsOf({chainId: 1, projectId: 10 + i, setter: SETTER}), parts);

            unchecked {
                ++i;
            }
        }
    }
}
