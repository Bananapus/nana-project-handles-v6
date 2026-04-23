// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

/// @notice Tests for control character validation in setEnsNamePartsFor.
contract TestControlCharValidation is Test {
    JBProjectHandles internal handles;

    address internal constant SETTER = address(0xBEEF);

    function setUp() public {
        handles = new JBProjectHandles(address(0));
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _singlePart(string memory label) internal pure returns (string[] memory parts) {
        parts = new string[](1);
        parts[0] = label;
    }

    function _setParts(string memory label) internal {
        vm.prank(SETTER);
        handles.setEnsNamePartsFor(1, 1, _singlePart(label));
    }

    function _expectInvalidNamePart(string memory label) internal {
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, label));
    }

    // ---------------------------------------------------------------
    // Control characters are rejected
    // ---------------------------------------------------------------

    function test_rejects_newline() public {
        string memory label = string(abi.encodePacked("hello", bytes1(0x0a), "world"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_carriage_return() public {
        string memory label = string(abi.encodePacked("hello", bytes1(0x0d), "world"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_null_byte() public {
        string memory label = string(abi.encodePacked("hello", bytes1(0x00), "world"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_tab() public {
        string memory label = string(abi.encodePacked("hello", bytes1(0x09), "world"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_bell() public {
        string memory label = string(abi.encodePacked("hello", bytes1(0x07)));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_escape() public {
        string memory label = string(abi.encodePacked(bytes1(0x1b), "hello"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_byte_0x01() public {
        string memory label = string(abi.encodePacked(bytes1(0x01)));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_byte_0x1f() public {
        string memory label = string(abi.encodePacked("a", bytes1(0x1f)));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    // ---------------------------------------------------------------
    // DEL (0x7F) is rejected
    // ---------------------------------------------------------------

    function test_rejects_del() public {
        string memory label = string(abi.encodePacked("abc", bytes1(0x7f)));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_rejects_del_only() public {
        string memory label = string(abi.encodePacked(bytes1(0x7f)));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    // ---------------------------------------------------------------
    // Fuzz: every byte < 0x20 and 0x7F is rejected
    // ---------------------------------------------------------------

    function test_fuzz_rejects_all_control_chars(uint8 raw) public {
        vm.assume(raw < 0x20 || raw == 0x7f);

        string memory label = string(abi.encodePacked("ok", bytes1(raw), "ok"));
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    // ---------------------------------------------------------------
    // Valid ASCII passes
    // ---------------------------------------------------------------

    function test_accepts_simple_ascii() public {
        _setParts("hello");
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
        assertEq(keccak256(bytes(stored[0])), keccak256(bytes("hello")));
    }

    function test_accepts_printable_ascii_boundary_space() public {
        // 0x20 (space) is the first allowed byte
        _setParts(" ");
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    function test_accepts_printable_ascii_boundary_tilde() public {
        // 0x7E (~) is the last printable ASCII before DEL
        _setParts("~");
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    function test_accepts_alphanumeric_and_hyphens() public {
        _setParts("my-project-123");
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
        assertEq(keccak256(bytes(stored[0])), keccak256(bytes("my-project-123")));
    }

    // ---------------------------------------------------------------
    // Valid UTF-8 multibyte (bytes >= 0x80) passes
    // ---------------------------------------------------------------

    function test_accepts_utf8_multibyte() public {
        // Unicode snowman: U+2603 = 0xE2 0x98 0x83 (all bytes >= 0x80 except lead byte 0xE2 which is also >= 0x80)
        _setParts(unicode"\u2603");
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    function test_accepts_emoji() public {
        // Rocket emoji U+1F680 = 0xF0 0x9F 0x9A 0x80 (4-byte UTF-8, all bytes >= 0x80)
        string memory label = string(abi.encodePacked(bytes1(0xf0), bytes1(0x9f), bytes1(0x9a), bytes1(0x80)));
        _setParts(label);
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    function test_accepts_high_byte_0x80() public {
        // A single 0x80 continuation byte (not valid UTF-8 on its own, but the filter only checks < 0x20 and 0x7F)
        string memory label = string(abi.encodePacked(bytes1(0x80)));
        _setParts(label);
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    function test_accepts_byte_0xff() public {
        // 0xFF is well above the control range
        string memory label = string(abi.encodePacked(bytes1(0xff)));
        _setParts(label);
        string[] memory stored = handles.ensNamePartsOf(1, 1, SETTER);
        assertEq(stored.length, 1);
    }

    // ---------------------------------------------------------------
    // Dot rejection still works
    // ---------------------------------------------------------------

    function test_dot_rejection_still_works() public {
        string memory label = "hello.world";
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    function test_dot_only_still_rejected() public {
        string memory label = ".";
        _expectInvalidNamePart(label);
        _setParts(label);
    }

    // ---------------------------------------------------------------
    // Empty label rejection still works
    // ---------------------------------------------------------------

    function test_empty_label_still_rejected() public {
        string[] memory parts = new string[](1);
        parts[0] = "";

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_EmptyNamePart.selector, parts));
        handles.setEnsNamePartsFor(1, 1, parts);
    }

    function test_no_parts_still_rejected() public {
        string[] memory parts = new string[](0);

        vm.prank(SETTER);
        vm.expectRevert(JBProjectHandles.JBProjectHandles_NoParts.selector);
        handles.setEnsNamePartsFor(1, 1, parts);
    }

    // ---------------------------------------------------------------
    // Multi-part: control char in second label is caught
    // ---------------------------------------------------------------

    function test_control_char_in_second_part_rejected() public {
        string[] memory parts = new string[](2);
        parts[0] = "good";
        parts[1] = string(abi.encodePacked("bad", bytes1(0x00)));

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, parts[1]));
        handles.setEnsNamePartsFor(1, 1, parts);
    }
}
