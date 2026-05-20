// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

import {JBProjectHandles} from "../../src/JBProjectHandles.sol";

/// @notice Exposes ProjectHandles' internal ENS text-record decoder without touching production code.
contract JBProjectHandlesHarness is JBProjectHandles {
    constructor() JBProjectHandles(address(0)) {}

    /// @notice Reads a resolver text record through the same low-level parser used by `handleOf`.
    function textRecordOf(address textResolver, bytes32 hashedName) external view returns (string memory) {
        return _textRecordOf({textResolver: textResolver, hashedName: hashedName});
    }
}

/// @notice Resolver double that can return arbitrary bytes for the `text(bytes32,string)` selector.
contract RawTextResolver {
    bytes internal _returnData;
    bool internal _shouldRevert;

    function setReturnData(bytes memory returnData) external {
        _returnData = returnData;
        _shouldRevert = false;
    }

    function setShouldRevert(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
    }

    fallback() external {
        if (_shouldRevert) revert();

        bytes memory returnData = _returnData;

        // Return exactly the resolver-controlled bytes so the harness exercises ProjectHandles' manual ABI checks.
        assembly {
            return(add(returnData, 32), mload(returnData))
        }
    }
}

/// @notice Halmos entrypoints for ProjectHandles' ENS resolver soft-fail parser.
/// @dev ENS resolvers are name-owner controlled. These proofs pin the branch table that turns malformed or oversized
/// resolver data into `""` instead of reverting or copying unbounded bytes in onchain readers.
contract JBProjectHandlesHalmos {
    /// @notice Proves a well-formed resolver string at the expected ABI shape is copied through exactly.
    function check_textRecordOfReturnsValidRecord() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        resolver.setReturnData(abi.encode("1:123"));

        assert(
            keccak256(bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(1))})))
                == keccak256(bytes("1:123"))
        );
    }

    /// @notice Proves the inclusive 256-byte cap still accepts the largest intended resolver copy.
    function check_textRecordOfAcceptsMaxLengthRecord() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        string memory maxLengthRecord = new string(256);
        resolver.setReturnData(abi.encode(maxLengthRecord));

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(2))})).length
                == 256
        );
    }

    /// @notice Proves resolver-controlled strings above the cap soft-fail before the manual copy loop.
    function check_textRecordOfRejectsOversizedRecord() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        string memory oversizedRecord = new string(257);
        resolver.setReturnData(abi.encode(oversizedRecord));

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(3))})).length == 0
        );
    }

    /// @notice Proves a reverting resolver is treated as an unverified handle.
    function check_textRecordOfReturnsEmptyIfResolverReverts() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        resolver.setShouldRevert(true);

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(4))})).length == 0
        );
    }

    /// @notice Proves the minimum ABI shape check rejects an offset-only response.
    function check_textRecordOfRejectsOffsetOnlyReturn() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        resolver.setReturnData(abi.encode(uint256(32)));

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(5))})).length == 0
        );
    }

    /// @notice Proves the decoder rejects noncanonical string offsets.
    function check_textRecordOfRejectsNonCanonicalOffset() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        resolver.setReturnData(abi.encode(uint256(64), uint256(0)));

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(6))})).length == 0
        );
    }

    /// @notice Proves the claimed length must fit inside returned bytes before any copy occurs.
    function check_textRecordOfRejectsOverstatedLength() public {
        JBProjectHandlesHarness harness = new JBProjectHandlesHarness();
        RawTextResolver resolver = new RawTextResolver();

        resolver.setReturnData(abi.encode(uint256(32), uint256(1)));

        assert(
            bytes(harness.textRecordOf({textResolver: address(resolver), hashedName: bytes32(uint256(7))})).length == 0
        );
    }

    /// @notice Proves the raw resolver call uses the standard ENS text selector.
    function check_textResolverSelectorPinned() public pure {
        assert(ITextResolver.text.selector == bytes4(keccak256("text(bytes32,string)")));
    }
}
