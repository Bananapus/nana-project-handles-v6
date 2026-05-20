// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

ENS constant CODEX_ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

contract CodexProjectHandlesHarness is JBProjectHandles {
    constructor() JBProjectHandles(address(0)) {}

    function textRecordOf(address textResolver, bytes32 hashedName) external view returns (string memory) {
        return _textRecordOf({textResolver: textResolver, hashedName: hashedName});
    }
}

contract CodexMalformedResolverTest is Test {
    JBProjectHandles internal handles;
    address internal setter = address(0xBEEF);
    address internal resolver = address(0xCAFE);

    function setUp() public {
        vm.etch(address(CODEX_ENS_REGISTRY), "0x69");
        vm.etch(resolver, "0x69");
        handles = new JBProjectHandles(address(0));
    }

    function test_malformedResolverReturnDataReturnsEmptyHandle() public {
        uint256 chainId = 1;
        uint256 projectId = 123;
        string[] memory parts = new string[](1);
        parts[0] = "malformed";

        vm.prank(setter);
        handles.setEnsNamePartsFor(chainId, projectId, parts);

        bytes32 node = _namehash(parts);
        vm.mockCall(
            address(CODEX_ENS_REGISTRY), abi.encodeWithSelector(ENS.resolver.selector, node), abi.encode(resolver)
        );
        vm.mockCall(resolver, abi.encodeWithSelector(ITextResolver.text.selector, node, handles.TEXT_KEY()), hex"");

        assertEq(handles.handleOf(chainId, projectId, setter), "");
    }

    function test_oversizedResolverTextRecordReturnsEmptyHandle() public {
        CodexProjectHandlesHarness harness = new CodexProjectHandlesHarness();
        bytes32 maxLengthNode = bytes32(uint256(1));
        bytes32 oversizedNode = bytes32(uint256(2));

        // The cap is inclusive at 256 bytes, which is far above an expected `chainId:projectId` record.
        string memory maxLengthRecord = new string(256);
        vm.mockCall(
            resolver,
            abi.encodeWithSelector(ITextResolver.text.selector, maxLengthNode, harness.TEXT_KEY()),
            abi.encode(maxLengthRecord)
        );
        assertEq(bytes(harness.textRecordOf({textResolver: resolver, hashedName: maxLengthNode})).length, 256);

        // A longer resolver-controlled string would make every on-chain reader pay to copy irrelevant data before
        // rejecting the record. Soft-fail it as an unverified handle instead.
        string memory oversizedRecord = new string(257);
        vm.mockCall(
            resolver,
            abi.encodeWithSelector(ITextResolver.text.selector, oversizedNode, harness.TEXT_KEY()),
            abi.encode(oversizedRecord)
        );
        assertEq(harness.textRecordOf({textResolver: resolver, hashedName: oversizedNode}), "");
    }

    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));
        bytes memory handle = bytes(ensNameParts[0]);
        namehash = keccak256(abi.encodePacked(namehash, keccak256(handle)));
    }
}
