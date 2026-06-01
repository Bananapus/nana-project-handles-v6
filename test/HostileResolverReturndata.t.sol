// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

/// @notice A resolver controlled by a hostile name owner. Its `text` returns a huge blob of return data — far larger
/// than any real `chainId:projectId` record — to try to make on-chain readers copy unbounded bytes.
contract HugeReturndataResolver {
    /// @dev Number of 32-byte words of garbage return data to emit (~3.2 MB).
    uint256 internal constant _GARBAGE_WORDS = 100_000;

    fallback() external {
        assembly {
            let size := mul(_GARBAGE_WORDS, 32)
            // Grow memory to `size` so the return covers a large region. The data content is irrelevant.
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
            return(ptr, size)
        }
    }
}

/// @notice A well-behaved resolver returning a valid, correctly-sized `chainId:projectId` text record.
contract HonestResolver is ITextResolver {
    string internal _record;

    constructor(string memory record) {
        _record = record;
    }

    function text(bytes32, string calldata) external view override returns (string memory) {
        return _record;
    }
}

contract HostileResolverReturndataTest is Test {
    /// @notice A hostile resolver's return-data size must never drive `handleOf` gas. This ceiling is far below the
    /// cost of copying the multi-megabyte blob `HugeReturndataResolver` returns, but well above a normal lookup.
    uint256 internal constant _GAS_CEILING = 1_000_000;

    JBProjectHandles internal handles;

    address internal setter = address(0xBEEF);

    function setUp() public {
        vm.etch(address(ENS_REGISTRY), "0x69");
        handles = new JBProjectHandles(address(0));
    }

    /// @notice A hostile resolver returning megabytes of return data must not be able to drive `handleOf` gas. The
    /// lookup soft-fails to an empty handle while consuming bounded gas, rather than copying the whole blob.
    function test_handleOf_softFailsOnOversizedResolverReturndata() public {
        uint256 chainId = 1;
        uint256 projectId = 123;

        string[] memory parts = new string[](1);
        parts[0] = "hostile";

        vm.prank(setter);
        handles.setEnsNamePartsFor({chainId: chainId, projectId: projectId, parts: parts});

        bytes32 node = _namehash(parts);

        // Point the namehash at a real hostile resolver contract (not a cheatcode mock) so the EVM models the actual
        // return-data copy cost a reader would pay on-chain.
        HugeReturndataResolver hostile = new HugeReturndataResolver();
        vm.mockCall({
            callee: address(ENS_REGISTRY),
            data: abi.encodeWithSelector(ENS.resolver.selector, node),
            returnData: abi.encode(address(hostile))
        });

        uint256 gasBefore = gasleft();
        string memory handle = handles.handleOf({chainId: chainId, projectId: projectId, setter: setter});
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(handle, "", "hostile resolver must not produce a verified handle");
        assertLt(gasUsed, _GAS_CEILING, "handleOf gas scaled with hostile resolver return-data size");
    }

    /// @notice A well-behaved resolver still resolves to the correct handle after the bound is applied.
    function test_handleOf_resolvesHonestResolverUnchanged() public {
        uint256 chainId = 1;
        uint256 projectId = 123;

        string[] memory parts = new string[](1);
        parts[0] = "honest";

        vm.prank(setter);
        handles.setEnsNamePartsFor({chainId: chainId, projectId: projectId, parts: parts});

        bytes32 node = _namehash(parts);

        HonestResolver honest =
            new HonestResolver(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId)));
        vm.mockCall({
            callee: address(ENS_REGISTRY),
            data: abi.encodeWithSelector(ENS.resolver.selector, node),
            returnData: abi.encode(address(honest))
        });

        assertEq(handles.handleOf({chainId: chainId, projectId: projectId, setter: setter}), "honest");
    }

    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));
        bytes memory handle = bytes(ensNameParts[0]);
        namehash = keccak256(abi.encodePacked(namehash, keccak256(handle)));
    }
}
