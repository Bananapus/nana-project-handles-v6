// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

contract MalformedResolverHarness is JBProjectHandles {
    constructor() JBProjectHandles(address(0)) {}

    function textRecordOf(address textResolver, bytes32 hashedName) external view returns (string memory) {
        return _textRecordOf({textResolver: textResolver, hashedName: hashedName});
    }
}

contract MalformedResolverTest is Test {
    JBProjectHandles internal handles;
    MalformedResolverHarness internal harness;

    address internal setter = address(0xBEEF);
    address internal resolver = address(0xCAFE);

    function setUp() public {
        vm.etch(address(ENS_REGISTRY), "0x69");
        vm.etch(resolver, "0x69");
        handles = new JBProjectHandles(address(0));
        harness = new MalformedResolverHarness();
    }

    function test_malformedResolverReturnDataReturnsEmptyHandle() public {
        uint256 chainId = 1;
        uint256 projectId = 123;
        string[] memory parts = new string[](1);
        parts[0] = "malformed";

        vm.prank(setter);
        handles.setEnsNamePartsFor({chainId: chainId, projectId: projectId, parts: parts});

        bytes32 node = _namehash(parts);
        vm.mockCall({
            callee: address(ENS_REGISTRY),
            data: abi.encodeWithSelector(ENS.resolver.selector, node),
            returnData: abi.encode(resolver)
        });
        vm.mockCall({
            callee: resolver,
            data: abi.encodeWithSelector(ITextResolver.text.selector, node, handles.TEXT_KEY()),
            returnData: hex""
        });

        assertEq(handles.handleOf({chainId: chainId, projectId: projectId, setter: setter}), "");
    }

    function test_oversizedResolverTextRecordReturnsEmptyHandle() public {
        bytes32 maxLengthNode = bytes32(uint256(1));
        bytes32 oversizedNode = bytes32(uint256(2));

        // The cap is inclusive at 256 bytes, which is far above an expected `chainId:projectId` record.
        string memory maxLengthRecord = new string(256);
        _mockTextRecord({hashedName: maxLengthNode, returnData: abi.encode(maxLengthRecord)});
        assertEq(bytes(harness.textRecordOf({textResolver: resolver, hashedName: maxLengthNode})).length, 256);

        // A longer resolver-controlled string would make every on-chain reader pay to copy irrelevant data before
        // rejecting the record. Soft-fail it as an unverified handle instead.
        string memory oversizedRecord = new string(257);
        _mockTextRecord({hashedName: oversizedNode, returnData: abi.encode(oversizedRecord)});
        assertEq(harness.textRecordOf({textResolver: resolver, hashedName: oversizedNode}), "");
    }

    function test_textRecordOfReturnsEmptyIfResolverReverts() public {
        bytes32 node = bytes32(uint256(3));

        vm.mockCallRevert({
            callee: resolver,
            data: abi.encodeWithSelector(ITextResolver.text.selector, node, harness.TEXT_KEY()),
            revertData: abi.encodeWithSignature("Error(string)", "resolver failed")
        });

        assertEq(harness.textRecordOf({textResolver: resolver, hashedName: node}), "");
    }

    function test_textRecordOfReturnsEmptyForMalformedAbiShapes() public {
        // A successful call that returns only the dynamic offset word is not enough to read the string length.
        _assertTextRecordSoftFails({hashedName: bytes32(uint256(4)), returnData: abi.encode(uint256(32))});

        // A 63-byte response is one byte short of the minimum ABI shape: offset word + length word.
        _assertTextRecordSoftFails({hashedName: bytes32(uint256(5)), returnData: new bytes(63)});

        // A single returned `string` must point to its data at offset 32. Any other offset is noncanonical for this
        // function's return shape, so treat it like an unverified handle instead of trying to chase arbitrary offsets.
        _assertTextRecordSoftFails({hashedName: bytes32(uint256(6)), returnData: abi.encode(uint256(64), uint256(0))});

        // The resolver can claim a longer string than it actually returned. Bound the claimed length before the copy
        // loop so malformed resolver data soft-fails instead of reverting on an out-of-bounds read.
        _assertTextRecordSoftFails({hashedName: bytes32(uint256(7)), returnData: abi.encode(uint256(32), uint256(1))});
    }

    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));
        bytes memory handle = bytes(ensNameParts[0]);
        namehash = keccak256(abi.encodePacked(namehash, keccak256(handle)));
    }

    function _assertTextRecordSoftFails(bytes32 hashedName, bytes memory returnData) internal {
        _mockTextRecord({hashedName: hashedName, returnData: returnData});
        assertEq(harness.textRecordOf({textResolver: resolver, hashedName: hashedName}), "");
    }

    function _mockTextRecord(bytes32 hashedName, bytes memory returnData) internal {
        vm.mockCall({
            callee: resolver,
            data: abi.encodeWithSelector(ITextResolver.text.selector, hashedName, harness.TEXT_KEY()),
            returnData: returnData
        });
    }
}
