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

    function test_setEnsNamePartsFor_rejectsBidiOverrideCharacter() public {
        string[] memory parts = new string[](1);
        parts[0] = unicode"safe\u202Eevil";

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, parts[0]));
        handles.setEnsNamePartsFor({chainId: 1, projectId: 1, parts: parts});
    }

    function test_handleOf_cannotReturnVerifiedBidiSpoofedHandle() public {
        string[] memory parts = new string[](2);
        parts[0] = unicode"safe\u202Eevil";
        parts[1] = "dao";

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, parts[0]));
        handles.setEnsNamePartsFor({chainId: 1, projectId: 1, parts: parts});
    }

    function test_setEnsNamePartsFor_rejectsEveryBlockedUnicodeFormatCodepoint() public {
        string[16] memory blocked = [
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
            unicode"safe\uFEFFevil"
        ];

        for (uint256 i; i < blocked.length;) {
            // Each label contains one blocked Unicode formatting control. These characters can alter display order
            // or render invisibly, so even one occurrence must make the handle un-settable.
            _expectInvalidNamePart({part: blocked[i]});

            unchecked {
                ++i;
            }
        }
    }

    function test_setEnsNamePartsFor_allowsAdjacentUnicodeBoundaryCodepoints() public {
        string[6] memory allowed = [
            unicode"safe\u200Aokay",
            unicode"safe\u2010okay",
            unicode"safe\u2029okay",
            unicode"safe\u202Fokay",
            unicode"safe\u2065okay",
            unicode"safe\u206Aokay"
        ];

        for (uint256 i; i < allowed.length;) {
            string[] memory parts = new string[](1);
            parts[0] = allowed[i];

            // These are the nearest codepoints outside the blocked ranges. Keeping them accepted proves the filter is
            // not rejecting entire UTF-8 byte prefixes around legitimate ENS-normalized labels.
            vm.prank(SETTER);
            handles.setEnsNamePartsFor({chainId: 1, projectId: 10 + i, parts: parts});

            assertEq(handles.ensNamePartsOf({chainId: 1, projectId: 10 + i, setter: SETTER}), parts);

            unchecked {
                ++i;
            }
        }
    }

    function _expectInvalidNamePart(string memory part) internal {
        string[] memory parts = new string[](1);
        parts[0] = part;

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, part));
        handles.setEnsNamePartsFor({chainId: 1, projectId: 1, parts: parts});
    }
}
