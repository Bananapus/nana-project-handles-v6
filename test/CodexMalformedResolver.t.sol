// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

ENS constant CODEX_ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

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

    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));
        bytes memory handle = bytes(ensNameParts[0]);
        namehash = keccak256(abi.encodePacked(namehash, keccak256(handle)));
    }
}
