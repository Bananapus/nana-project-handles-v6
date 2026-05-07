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
        handles.setEnsNamePartsFor(1, 1, parts);
    }

    function test_handleOf_cannotReturnVerifiedBidiSpoofedHandle() public {
        string[] memory parts = new string[](2);
        parts[0] = unicode"safe\u202Eevil";
        parts[1] = "dao";

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, parts[0]));
        handles.setEnsNamePartsFor(1, 1, parts);
    }
}
