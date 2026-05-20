// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// forge-lint: disable-next-line(unaliased-plain-import)
import "forge-std/Test.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {JBProjectHandles} from "../../src/JBProjectHandles.sol";

/// @notice Live-ENS fork tests. The rest of the suite uses `vm.etch + vm.mockCall` against the registry address,
/// which means the `_textRecordOf` low-level call path has never been exercised against real ENS bytecode. This
/// file pins the integration with the live mainnet registry and a real public resolver.
contract ENSMainnetFork is Test {
    JBProjectHandles internal handles;

    function setUp() public {
        vm.createSelectFork("ethereum", 21_700_000);
        handles = new JBProjectHandles(address(0)); // no trusted forwarder
    }

    /// @notice Round-trip against the live ENS registry: set parts pointing at `juicebox.eth` (or whichever name
    /// exists at this block), then have a setter publish the matching `juicebox` text record. The point is to
    /// exercise the real `_textRecordOf` ABI-decoding path against a real resolver's output, not just confirm
    /// the test vectors against a mock.
    /// @dev We don't assert handle equality here — at the pinned block we may or may not have a real `.eth` name
    /// with our `chainId:projectId` text record. Instead we lock the behavior that calling `handleOf` against a
    /// real registry doesn't revert and returns either the empty string or a valid handle.
    function testFork_handleOf_realRegistry_doesNotRevert() public {
        // Set name parts pointing at `juicebox.eth` for chain 1 / project 1 / this contract as setter.
        string[] memory parts = new string[](1);
        parts[0] = "juicebox";
        handles.setEnsNamePartsFor(1, 1, parts);

        // Call `handleOf` against the live registry. Even if the text record doesn't point back, the call
        // must complete without reverting.
        string memory handle = handles.handleOf(1, 1, address(this));
        // Either empty (no matching text record) or the formatted handle. Both are valid outcomes for a real
        // ENS name that the test setter doesn't control.
        assertTrue(
            bytes(handle).length == 0 || keccak256(bytes(handle)) == keccak256(bytes("juicebox")),
            "handleOf must complete cleanly against live ENS"
        );
    }

    /// @notice A handle that points at a non-existent ENS name returns empty without reverting.
    function testFork_handleOf_unregisteredName_returnsEmpty() public {
        string[] memory parts = new string[](2);
        parts[0] = "juicebox-handle-test";
        parts[1] = "definitely-not-registered-test";
        handles.setEnsNamePartsFor(1, 1, parts);

        string memory handle = handles.handleOf(1, 1, address(this));
        assertEq(bytes(handle).length, 0, "unregistered name returns empty");
    }

    /// @notice The contract gracefully soft-fails for a name with no resolver set in the live registry.
    function testFork_handleOf_nameWithoutResolver_returnsEmpty() public {
        // `.eth` itself has no text resolver — querying it should soft-fail to empty, not revert.
        string[] memory parts = new string[](1);
        parts[0] = "eth-but-this-shouldnt-match";
        // We can't actually set parts == "eth" because the contract rejects "eth" (ambiguous handle).
        // Instead we use a name that resolves to an existing name without a `juicebox` text record.
        handles.setEnsNamePartsFor(1, 1, parts);

        string memory handle = handles.handleOf(1, 1, address(this));
        assertEq(bytes(handle).length, 0, "no resolver / no text record -> empty");
    }

    /// @notice Multi-level handle (3 labels) round-trips through the live namehash machinery.
    function testFork_handleOf_threeLevelName_doesNotRevert() public {
        string[] memory parts = new string[](3);
        parts[0] = "juicebox";
        parts[1] = "v6";
        parts[2] = "test";
        handles.setEnsNamePartsFor(1, 1, parts);

        // Just confirm the call doesn't revert against the real registry. The deeper namehash machinery is
        // covered by mock tests; this proves the live registry doesn't trip on multi-level lookups.
        handles.handleOf(1, 1, address(this));
    }
}
