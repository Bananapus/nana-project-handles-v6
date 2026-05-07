// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {JBProjectHandles} from "../../src/JBProjectHandles.sol";

contract JBProjectHandlesControlCharTest is Test {
    ENS internal constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    address internal constant SETTER = address(0xBEEF);
    ITextResolver internal constant RESOLVER = ITextResolver(address(0xCAFE));

    JBProjectHandles internal handles;

    function setUp() public {
        vm.etch(address(ENS_REGISTRY), "0x69");
        vm.etch(address(RESOLVER), "0x69");
        handles = new JBProjectHandles(address(0));
    }

    /// @notice Control characters are now rejected by setEnsNamePartsFor.
    function test_handleOf_revertsOnControlCharacterHandle() public {
        uint256 chainId = 1;
        uint256 projectId = 123;

        string[] memory parts = new string[](1);
        parts[0] = string.concat("team", "\n", "ops");

        vm.prank(SETTER);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, parts[0]));
        handles.setEnsNamePartsFor(chainId, projectId, parts);
    }

    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        for (uint256 i; i < ensNameParts.length; i++) {
            namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked(ensNameParts[i]))));
        }
    }
}
