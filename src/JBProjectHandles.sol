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
/// validated against control characters, bidi overrides, and other Unicode formatting exploits.
contract JBProjectHandles is IJBProjectHandles, ERC2771Context {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBProjectHandles_EmptyNamePart(string[] parts);
    error JBProjectHandles_InvalidNamePart(string part);
    error JBProjectHandles_NoParts();

    //*********************************************************************//
    // ---------------- public constant stored properties ---------------- //
    //*********************************************************************//

    /// @notice The key of the ENS text record which points back to a project.
    string public constant override TEXT_KEY = "juicebox";

    /// @notice The ENS registry contract address.
    /// @dev Same on Ethereum mainnet and most of its testnets.
    ENS public constant override ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

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
    /// @dev Callers must provide ENS-normalized names (lowercase, ENSIP-15). ASCII control characters, DEL, and
    /// dangerous Unicode formatting controls are rejected.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to set an ENS handle for.
    /// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
    function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external override {
        // Get a reference to the number of parts are in the ENS name.
        uint256 partsLength = parts.length;

        // Make sure there are ENS name parts.
        if (partsLength == 0) revert JBProjectHandles_NoParts();

        // Make sure no provided parts are empty or contain unsafe formatting bytes.
        for (uint256 i; i < partsLength; i++) {
            string memory part = parts[i];
            if (bytes(part).length == 0) {
                revert JBProjectHandles_EmptyNamePart(parts);
            }

            bytes memory partBytes = bytes(part);

            // Make sure no provided parts contain control characters (< 0x20), DEL (0x7F), or Unicode
            // formatting controls that can make verified handles render misleadingly.
            for (uint256 j; j < partBytes.length; j++) {
                bytes1 b = partBytes[j];
                if (
                    b < 0x20 || b == 0x7f || _isDisallowedUnicodeFormat({input: partBytes, index: j})
                        || (b == "." && (j == 0 || j == partBytes.length - 1 || partBytes[j - 1] == "."))
                ) {
                    revert JBProjectHandles_InvalidNamePart(part);
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

        // Get the resolver for this handle, returns address(0) if non-existing.
        address textResolver = ENS_REGISTRY.resolver(hashedName);

        // If the handle is not a registered ENS, return empty string.
        if (textResolver == address(0)) return "";

        // Find the text record that the ENS name is mapped to.
        // Wrap in try-catch so that a misconfigured resolver doesn't revert the entire call.
        string memory textRecord;
        try ITextResolver(textResolver).text(hashedName, TEXT_KEY) returns (string memory result) {
            textRecord = result;
        } catch {
            return "";
        }

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
        // Get a reference to the number of parts are in the ENS name.
        uint256 partsLength = ensNameParts.length;

        // Concatenate each name part.
        for (uint256 i = 1; i <= partsLength; i++) {
            // Compute the handle.
            // slither-disable-next-line encode-packed-collision
            handle = string(abi.encodePacked(handle, ensNameParts[partsLength - i]));

            // Add a dot if this part isn't the last.
            if (i < partsLength) handle = string(abi.encodePacked(handle, "."));
        }
    }

    /// @notice Returns a namehash for an ENS name.
    /// @dev See https://eips.ethereum.org/EIPS/eip-137.
    /// @param ensNameParts The parts of an ENS name to hash.
    /// @return namehash The namehash for the ENS name parts.
    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        // Hash the trailing "eth" suffix.
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        // Build the visible handle first so dots inside a stored part resolve as ENS label separators too.
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

    /// @notice Checks whether a byte in a handle part begins a blocked Unicode format control sequence.
    /// @dev Blocks common bidi controls and invisible format characters:
    ///      U+061C, U+200B-U+200F, U+202A-U+202E, U+2066-U+2069, and U+FEFF.
    /// @param input The UTF-8 encoded handle part being validated.
    /// @param index The byte offset to check as the start of a blocked UTF-8 sequence.
    /// @return True if `input[index]` starts a blocked Unicode format control sequence.
    function _isDisallowedUnicodeFormat(bytes memory input, uint256 index) internal pure returns (bool) {
        uint256 length = input.length;

        // U+061C ARABIC LETTER MARK: D8 9C.
        if (input[index] == 0xd8) return index + 1 < length && input[index + 1] == 0x9c;

        if (input[index] == 0xe2) {
            if (index + 2 >= length) return false;

            bytes1 second = input[index + 1];
            bytes1 third = input[index + 2];

            // U+200B-U+200F zero-width / direction marks: E2 80 8B-8F.
            // U+202A-U+202E bidi embeddings / overrides: E2 80 AA-AE.
            if (second == 0x80) return (third >= 0x8b && third <= 0x8f) || (third >= 0xaa && third <= 0xae);

            // U+2066-U+2069 isolate controls: E2 81 A6-A9.
            if (second == 0x81) return third >= 0xa6 && third <= 0xa9;

            return false;
        }

        // U+FEFF zero-width no-break space / byte order mark: EF BB BF.
        if (input[index] == 0xef) {
            return index + 2 < length && input[index + 1] == 0xbb && input[index + 2] == 0xbf;
        }

        return false;
    }

    /// @notice Returns `input[start:end]`.
    function _slice(bytes memory input, uint256 start, uint256 end) internal pure returns (bytes memory output) {
        output = new bytes(end - start);

        for (uint256 i; i < output.length; i++) {
            output[i] = input[start + i];
        }
    }

    /// @notice Returns the sender, preferred to use over `msg.sender`.
    /// @return sender The sender address of this call.
    function _msgSender() internal view override returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns the calldata, preferred to use over `msg.data`.
    /// @return The `msg.data` of this call.
    function _msgData() internal view override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
