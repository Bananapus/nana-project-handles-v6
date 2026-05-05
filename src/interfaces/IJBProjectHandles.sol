// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";

/// @notice Manages ENS handles for Juicebox projects — allows setting ENS name parts for any project and verifying
/// them against the ENS text record. A verified handle means the ENS name's "juicebox" text record matches
/// "chainId:projectId".
interface IJBProjectHandles {
    //*********************************************************************//
    // ------------------------------ events ----------------------------- //
    //*********************************************************************//

    /// @notice Emitted when ENS name parts are set for a project.
    /// @param projectId The ID of the project whose ENS name parts were set.
    /// @param handle The formatted ENS handle string.
    /// @param parts The parts of the ENS name that were set.
    /// @param caller The address that set the ENS name parts.
    event SetEnsNameParts(
        uint256 indexed chainId, uint256 indexed projectId, string handle, string[] parts, address caller
    );

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The ENS registry contract address.
    /// @return The ENS registry.
    function ENS_REGISTRY() external view returns (ENS);

    /// @notice The parts of the stored ENS name of a project.
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to get the ENS name of.
    /// @param setter The address that set the requested record in this contract.
    /// @return The parts of the ENS name of a project.
    function ensNamePartsOf(uint256 chainId, uint256 projectId, address setter) external view returns (string[] memory);

    /// @notice Returns a project's verified handle, or the empty string if unverified.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to get the handle of.
    /// @param setter The address which set the requested handle.
    /// @return handle The project's verified handle.
    function handleOf(uint256 chainId, uint256 projectId, address setter) external view returns (string memory handle);

    /// @notice The key of the ENS text record which points back to a project.
    /// @return The text key string.
    function TEXT_KEY() external view returns (string memory);

    //*********************************************************************//
    // ----------------------- external transactions --------------------- //
    //*********************************************************************//

    /// @notice Point from a Juicebox project to an ENS node.
    /// @dev Callers must provide ENS-normalized names (lowercase, ENSIP-15). ASCII control characters, DEL, and
    /// dangerous Unicode formatting controls are rejected.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to set an ENS handle for.
    /// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
    function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external;
}
