// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IJBProjectHandles} from "./interfaces/IJBProjectHandles.sol";

/// @notice Allows anyone to associate a Juicebox project with an ENS name, creating a human-readable handle.
/// Verification is bidirectional: the caller sets ENS name parts here, and the ENS name must have a text record
/// (key: "juicebox") containing "chainId:projectId" pointing back. If both directions match, clients treat the ENS
/// name as the project's verified handle.
/// @dev Name parts are stored in reverse order — ["jbx", "dao", "foo"] represents foo.dao.jbx.eth. Input is
/// validated against ASCII control characters, DEL, and dots. Unicode normalization (ENSIP-15) and any Unicode
/// formatting-character filtering are the caller's and client's responsibility, not this contract's.
contract JBProjectHandles is IJBProjectHandles, ERC2771Context {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    /// @notice Thrown when one of the ENS name parts is empty.
    /// @param parts The full set of name parts that was provided.
    error JBProjectHandles_EmptyNamePart(string[] parts);

    /// @notice Thrown when "eth" is used as a name part, which would create an ambiguous handle.
    /// @param parts The full set of name parts that was provided.
    error JBProjectHandles_EthPartNotAllowed(string[] parts);

    /// @notice Thrown when an ENS name part contains unsupported characters.
    /// @param part The invalid name part.
    error JBProjectHandles_InvalidNamePart(string part);

    /// @notice Thrown when no ENS name parts are provided for a project handle.
    /// @param chainId The chain ID the handle was being set for.
    /// @param projectId The project ID the handle was being set for.
    /// @param caller The account that attempted to set the handle.
    error JBProjectHandles_NoParts(uint256 chainId, uint256 projectId, address caller);

    //*********************************************************************//
    // ---------------- public constant stored properties ---------------- //
    //*********************************************************************//

    /// @notice The key of the ENS text record which points back to a project.
    string public constant override TEXT_KEY = "juicebox";

    /// @notice The ENS registry contract address.
    /// @dev Same on Ethereum mainnet and most of its testnets.
    ENS public constant override ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    //*********************************************************************//
    // ----------------------- internal constants ------------------------ //
    //*********************************************************************//

    /// @notice Maximum ENS text-record bytes copied from a resolver response.
    /// @dev Verified records are `chainId:projectId`, so this leaves room for very large decimal IDs while bounding
    /// name-owner-controlled resolver gas griefing.
    uint256 internal constant _MAX_TEXT_RECORD_LENGTH = 256;

    /// @notice The hash of the reserved "eth" ENS name part.
    bytes32 internal constant _ETH_NAME_PART_HASH = keccak256("eth");

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice ENS name parts set by different addresses for different projects.
    /// @dev The `ensParts` ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @custom:param chainId The chain ID of the network the project is on.
    /// @custom:param projectId The ID of the project to get the ENS parts of.
    /// @custom:param setter The address that set the requested `ensParts`.
    mapping(uint256 chainId => mapping(uint256 projectId => mapping(address setter => string[] ensParts))) private
        _ensNamePartsOf;

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    //*********************************************************************//
    // ----------------------- external transactions --------------------- //
    //*********************************************************************//

    /// @notice Point from a Juicebox project to an ENS node.
    /// @dev The `parts` ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @dev Callers must provide ENS-normalized names (lowercase, ENSIP-15). ASCII control characters, DEL, and dots
    /// are rejected. The Unicode formatting denylist this contract used to enforce was incomplete (it missed
    /// non-bidi invisible codepoints like U+2060, the Tags block, etc.) and lent a false sense of safety. Clients
    /// must apply ENSIP-15 normalization off-chain before trusting a returned handle.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to set an ENS handle for.
    /// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
    function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external override {
        // Cache the number of ENS name parts.
        uint256 partsLength = parts.length;

        // Make sure there are ENS name parts.
        if (partsLength == 0) {
            revert JBProjectHandles_NoParts({chainId: chainId, projectId: projectId, caller: _msgSender()});
        }

        // Make sure no provided parts are empty or contain unsafe ASCII bytes.
        for (uint256 i; i < partsLength; i++) {
            string memory part = parts[i];
            bytes memory partBytes = bytes(part);

            if (partBytes.length == 0) {
                revert JBProjectHandles_EmptyNamePart({parts: parts});
            }

            // Reject "eth" as a name part to prevent ambiguous handles (e.g. "foo.eth.eth").
            if (keccak256(partBytes) == _ETH_NAME_PART_HASH) {
                revert JBProjectHandles_EthPartNotAllowed({parts: parts});
            }

            // Reject ASCII control characters (< 0x20), DEL (0x7F), and dots. Higher-byte Unicode handling is
            // delegated to off-chain ENSIP-15 normalization — see contract NatSpec.
            for (uint256 j; j < partBytes.length; j++) {
                bytes1 b = partBytes[j];
                if (b < 0x20 || b == 0x7f || b == ".") {
                    revert JBProjectHandles_InvalidNamePart({part: part});
                }
            }
        }

        // Store the parts.
        _ensNamePartsOf[chainId][projectId][_msgSender()] = parts;

        emit SetEnsNameParts({
            chainId: chainId, projectId: projectId, handle: _formatHandle(parts), parts: parts, caller: _msgSender()
        });
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The parts of the stored ENS name of a project.
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to get the ENS name of.
    /// @param setter The address that set the requested record in this contract.
    /// @return The parts of the ENS name of a project.
    function ensNamePartsOf(
        uint256 chainId,
        uint256 projectId,
        address setter
    )
        external
        view
        override
        returns (string[] memory)
    {
        return _ensNamePartsOf[chainId][projectId][setter];
    }

    /// @notice Returns a project's verified handle, or the empty string if unverified.
    /// @dev Verified means the ENS text record with `TEXT_KEY` contains `chainId:projectId`.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to get the handle of.
    /// @param setter The address which set the requested handle.
    /// @return handle The project's verified handle.
    function handleOf(
        uint256 chainId,
        uint256 projectId,
        address setter
    )
        external
        view
        override
        returns (string memory)
    {
        // Get a reference to the project's ENS name parts.
        string[] memory ensNameParts = _ensNamePartsOf[chainId][projectId][setter];

        // Return an empty string if not found.
        if (ensNameParts.length == 0) return "";

        // Compute the hash of the handle.
        bytes32 hashedName = _namehash(ensNameParts);

        // If the ENS registry has no code (chain without ENS), return empty string instead of reverting.
        if (address(ENS_REGISTRY).code.length == 0) return "";

        // Get the resolver for this handle from the trusted ENS registry.
        address textResolver = ENS_REGISTRY.resolver(hashedName);

        // If the handle is not a registered ENS, return empty string.
        if (textResolver == address(0)) return "";

        // Find the text record that the ENS name is mapped to. Resolvers are name-owner controlled, so use a low-level
        // call to soft-fail malformed return data the same way as a reverting resolver.
        string memory textRecord = _textRecordOf({textResolver: textResolver, hashedName: hashedName});

        // Return empty string if text record from ENS name doesn't match `projectId` and `chainId`.
        if (
            keccak256(bytes(textRecord))
                != keccak256(bytes(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId))))
        ) return "";

        // Format the handle from the name parts.
        return _formatHandle(ensNameParts);
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Formats ENS name parts into a handle.
    /// @param ensNameParts The ENS name parts to format into a handle.
    /// @return handle The formatted ENS handle.
    function _formatHandle(string[] memory ensNameParts) internal pure returns (string memory handle) {
        // Cache the number of ENS name parts.
        uint256 partsLength = ensNameParts.length;

        // Concatenate each name part.
        for (uint256 i = 1; i <= partsLength; i++) {
            // Compute the handle.
            handle = string(abi.encodePacked(handle, ensNameParts[partsLength - i]));

            // Add a dot if this part isn't the last.
            if (i < partsLength) handle = string(abi.encodePacked(handle, "."));
        }
    }

    /// @notice Returns the calldata, preferred to use over `msg.data`.
    /// @return The `msg.data` of this call.
    function _msgData() internal view override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @notice Returns the sender, preferred to use over `msg.sender`.
    /// @return sender The sender address of this call.
    function _msgSender() internal view override returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns a namehash for an ENS name.
    /// @dev See https://eips.ethereum.org/EIPS/eip-137.
    /// @param ensNameParts The parts of an ENS name to hash.
    /// @return namehash The namehash for the ENS name parts.
    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        // Hash the trailing "eth" suffix.
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        // Build the visible handle for hashing.
        bytes memory handle = bytes(_formatHandle(ensNameParts));

        // Get a reference to the current label's end. Labels are hashed from right to left.
        uint256 labelEnd = handle.length;

        // Hash each dot-separated label.
        for (uint256 i = handle.length; i > 0; i--) {
            if (handle[i - 1] != ".") continue;

            namehash =
                keccak256(abi.encodePacked(namehash, keccak256(_slice({input: handle, start: i, end: labelEnd}))));
            labelEnd = i - 1;
        }

        // Hash the leftmost label.
        namehash = keccak256(abi.encodePacked(namehash, keccak256(_slice({input: handle, start: 0, end: labelEnd}))));
    }

    /// @notice Returns the sub-slice `input[start:end]`.
    /// @param input The byte string to slice.
    /// @param start The inclusive start index of the slice.
    /// @param end The exclusive end index of the slice.
    /// @return output The bytes from `start` (inclusive) to `end` (exclusive).
    function _slice(bytes memory input, uint256 start, uint256 end) internal pure returns (bytes memory output) {
        output = new bytes(end - start);

        for (uint256 i; i < output.length; i++) {
            output[i] = input[start + i];
        }
    }

    /// @notice Reads the handle text record from an ENS resolver, returning an empty string on resolver failure.
    /// @param textResolver The ENS resolver to query.
    /// @param hashedName The ENS namehash to query.
    /// @return textRecord The resolver's text record, or empty if the call or ABI return data is invalid.
    function _textRecordOf(address textResolver, bytes32 hashedName) internal view returns (string memory textRecord) {
        // Resolver contracts are controlled by the ENS name owner, so use a low-level call instead of a typed
        // `try/catch`. A typed return would still ABI-decode a successful-but-malformed response in this frame.
        (bool success, bytes memory result) =
            textResolver.staticcall(abi.encodeWithSelector(ITextResolver.text.selector, hashedName, TEXT_KEY));

        // The ABI encoding for one dynamic `string` return needs at least an offset word and a length word.
        if (!success || result.length < 64) return "";

        uint256 offset;
        uint256 length;

        assembly {
            // First return word: offset to the string data, measured from the start of the return payload.
            offset := mload(add(result, 32))
            // Second return word: byte length of the returned string.
            length := mload(add(result, 64))
        }

        // A standard single-string return has offset 32. The result-length check keeps the manual copy in bounds.
        // The explicit cap prevents a name-owner-controlled resolver from returning a huge, valid ABI string that
        // readers must copy before the later `chainId:projectId` equality check rejects it.
        if (offset != 32 || length > result.length - 64 || length > _MAX_TEXT_RECORD_LENGTH) return "";

        bytes memory textBytes = bytes(textRecord = new string(length));
        for (uint256 i; i < length;) {
            // Copy the string bytes by hand so malformed resolver data soft-fails above instead of reverting.
            textBytes[i] = result[64 + i];
            unchecked {
                ++i;
            }
        }
    }
}
