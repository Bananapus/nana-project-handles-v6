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

    function test_setEnsNamePartsFor_acceptsBidiOverrideCharacter() public {
        string[] memory parts = new string[](1);
        parts[0] = unicode"safe\u202Eevil";

        vm.prank(SETTER);
        handles.setEnsNamePartsFor(1, 1, parts);

        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
        assertEq(keccak256(bytes(stored[0])), keccak256(bytes(parts[0])));
    }
}
