// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {JBProjects} from "@bananapus/core-v6/src/JBProjects.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

contract JBProjectHandlesTest is Test {
    event SetEnsNameParts(
        uint256 indexed chainId, uint256 indexed projectId, string ensName, string[] parts, address caller
    );

    address projectOwner = address(6_942_069);
    address otherUser = address(0xBEEF);
    ITextResolver ensTextResolver = ITextResolver(address(69_420));

    JBProjects jbProjects;
    JBProjectHandles projectHandle;

    function setUp() public {
        vm.etch(address(ensTextResolver), "0x69");
        vm.etch(address(ENS_REGISTRY), "0x69");
        vm.label(address(ensTextResolver), "ensTextResolver");
        vm.label(address(ENS_REGISTRY), "ensRegistry");

        jbProjects = new JBProjects(address(69), address(69), address(0));
        projectHandle = new JBProjectHandles(address(0x0));
    }

    //*********************************************************************//
    // -------------------- setEnsNamePartsFor tests --------------------- //
    //*********************************************************************//

    function test_setEnsNamePartsFor_singleNamePart(string calldata name) public {
        vm.assume(bytes(name).length != 0);

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = name;

        bool hasInvalidChar = _hasRejectedByteInAny(nameParts);

        if (hasInvalidChar) {
            vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, name));
        }

        if (!hasInvalidChar) {
            vm.expectEmit(true, true, true, true);
            emit SetEnsNameParts(chainId, projectId, name, nameParts, projectOwner);
        }

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        if (hasInvalidChar) return;

        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), nameParts);
    }

    function test_setEnsNamePartsFor_multipleSubdomainLevels(
        string memory name,
        string memory subdomain,
        string memory subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length > 0 && bytes(subdomain).length > 0 && bytes(subsubdomain).length > 0);

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        string memory fullName = string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain));

        bool hasRejectedByte = _hasRejectedByteInAny(nameParts);

        if (hasRejectedByte) {
            // We can't predict which part will trigger the revert in fuzz, so just check it reverts.
            vm.prank(projectOwner);
            vm.expectRevert();
            projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);
            return;
        }

        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(chainId, projectId, fullName, nameParts, projectOwner);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), nameParts);
    }

    /// @notice Reverts when any element in the parts array is empty (first element empty).
    function test_setEnsNamePartsFor_revertsOnEmptyFirstElement() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](3);
        nameParts[0] = "";
        nameParts[1] = "subdomain";
        nameParts[2] = "name";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_EmptyNamePart.selector, nameParts));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);

        assertEq(projectHandle.ensNamePartsOf(1, projectId, projectOwner), new string[](0));
    }

    /// @notice Reverts when the middle element is empty.
    function test_setEnsNamePartsFor_revertsOnEmptyMiddleElement() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](3);
        nameParts[0] = "sub";
        nameParts[1] = "";
        nameParts[2] = "name";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_EmptyNamePart.selector, nameParts));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);
    }

    /// @notice Reverts when the last element is empty.
    function test_setEnsNamePartsFor_revertsOnEmptyLastElement() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](3);
        nameParts[0] = "sub";
        nameParts[1] = "domain";
        nameParts[2] = "";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_EmptyNamePart.selector, nameParts));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);
    }

    function test_setEnsNamePartsFor_revertsOnEmptyParts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](0);

        vm.prank(projectOwner);
        vm.expectRevert(JBProjectHandles.JBProjectHandles_NoParts.selector);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), new string[](0));
    }

    /// @notice Setting parts twice overwrites the first record.
    function test_setEnsNamePartsFor_overwritesPreviousRecord() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        // Set first handle.
        string[] memory first = new string[](1);
        first[0] = "alice";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, first);
        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), first);

        // Set second handle — should overwrite.
        string[] memory second = new string[](2);
        second[0] = "dao";
        second[1] = "bob";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, second);
        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), second);

        // First handle is gone.
        string[] memory stored = projectHandle.ensNamePartsOf(chainId, projectId, projectOwner);
        assertEq(stored.length, 2);
        assertEq(keccak256(bytes(stored[0])), keccak256(bytes("dao")));
        assertEq(keccak256(bytes(stored[1])), keccak256(bytes("bob")));
    }

    //*********************************************************************//
    // -------------------- setter isolation tests ----------------------- //
    //*********************************************************************//

    /// @notice Two different callers can set different handles for the same project.
    function test_setterIsolation_differentSettersDontInterfere() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory ownerParts = new string[](1);
        ownerParts[0] = "owner";

        string[] memory otherParts = new string[](1);
        otherParts[0] = "other";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, ownerParts);

        vm.prank(otherUser);
        projectHandle.setEnsNamePartsFor(chainId, projectId, otherParts);

        // Each setter has their own record.
        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, projectOwner), ownerParts);
        assertEq(projectHandle.ensNamePartsOf(chainId, projectId, otherUser), otherParts);
    }

    /// @notice Same setter, same project, different chains = independent records.
    function test_setterIsolation_differentChainsAreIndependent() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory mainnetParts = new string[](1);
        mainnetParts[0] = "mainnet";

        string[] memory optimismParts = new string[](1);
        optimismParts[0] = "optimism";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(1, projectId, mainnetParts);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(10, projectId, optimismParts);

        assertEq(projectHandle.ensNamePartsOf(1, projectId, projectOwner), mainnetParts);
        assertEq(projectHandle.ensNamePartsOf(10, projectId, projectOwner), optimismParts);
    }

    //*********************************************************************//
    // ------------------------ handleOf tests --------------------------- //
    //*********************************************************************//

    /// @notice handleOf returns empty when no parts have been set for the given setter.
    function test_handleOf_returnsEmptyWhenNoHandleSet(uint256 chainId, uint256 projectId) public view {
        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    /// @notice handleOf returns empty when parts are set but ENS resolver returns address(0).
    function test_handleOf_returnsEmptyWhenResolverIsZero() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        // Set the name parts first.
        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Mock ENS resolver to return address(0).
        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(0))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    /// @notice handleOf returns empty when parts are set and resolver exists but text record doesn't match.
    function test_handleOf_returnsEmptyWhenTextRecordMismatch() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        // Set the name parts.
        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Mock resolver to exist.
        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        // Mock text record to return a wrong value.
        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), projectHandle.TEXT_KEY()),
            abi.encode("999:999")
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    /// @notice handleOf returns empty when resolver reverts (try-catch gracefully handles failure).
    function test_handleOf_returnsEmptyWhenResolverReverts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCallRevert(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), projectHandle.TEXT_KEY()),
            abi.encodeWithSignature("ResolverFailure()")
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    /// @notice handleOf returns empty when text record matches a different chainId.
    function test_handleOf_returnsEmptyWhenChainIdMismatch() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        // Text record has wrong chainId (10 instead of 1).
        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), projectHandle.TEXT_KEY()),
            abi.encode(string.concat("10:", Strings.toString(projectId)))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    /// @notice handleOf returns the verified handle for a single-part name.
    function test_handleOf_returnsVerifiedSinglePartHandle() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), projectHandle.TEXT_KEY()),
            abi.encode(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId)))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "alice");
    }

    /// @notice handleOf returns the verified handle for a multi-part name (fuzz).
    function test_handleOf_returnsVerifiedHandle(
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length > 0 && bytes(subdomain).length > 0 && bytes(subsubdomain).length > 0);

        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        // Skip inputs with dots — they'd revert in setEnsNamePartsFor.
        if (_hasRejectedByteInAny(nameParts)) return;

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ENS_REGISTRY),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), projectHandle.TEXT_KEY()),
            abi.encode(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId)))
        );

        assertEq(
            projectHandle.handleOf(chainId, projectId, projectOwner),
            string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain))
        );
    }

    /// @notice handleOf for one setter does not resolve for a different setter.
    function test_handleOf_doesNotResolveForDifferentSetter() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "alice";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // otherUser never set parts — should return empty.
        assertEq(projectHandle.handleOf(chainId, projectId, otherUser), "");
    }

    //*********************************************************************//
    // ----------------------- namehash tests ---------------------------- //
    //*********************************************************************//

    /// @notice Verify namehash against known ENS values.
    function test_namehash_matchesKnownValues() public {
        // eth namehash = keccak256(bytes32(0), keccak256("eth"))
        bytes32 ethNode = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked("eth"))));

        // alice.eth
        string[] memory aliceParts = new string[](1);
        aliceParts[0] = "alice";
        bytes32 aliceExpected = keccak256(abi.encodePacked(ethNode, keccak256(abi.encodePacked("alice"))));
        assertEq(_namehash(aliceParts), aliceExpected);

        // sub.alice.eth
        string[] memory subParts = new string[](2);
        subParts[0] = "alice";
        subParts[1] = "sub";
        bytes32 subExpected = keccak256(abi.encodePacked(aliceExpected, keccak256(abi.encodePacked("sub"))));
        assertEq(_namehash(subParts), subExpected);
    }

    //*********************************************************************//
    // -------------------- ERC2771 meta-tx tests ------------------------ //
    //*********************************************************************//

    /// @notice Meta-transaction via trusted forwarder sets parts under the forwarded sender.
    function test_erc2771_metaTransactionSetsPartsUnderForwardedSender() public {
        address trustedForwarder = address(0x1234);
        JBProjectHandles erc2771Handle = new JBProjectHandles(trustedForwarder);

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "meta";

        // Simulate trusted forwarder call: append the real sender (projectOwner) to calldata.
        bytes memory callData =
            abi.encodeWithSelector(JBProjectHandles.setEnsNamePartsFor.selector, chainId, projectId, nameParts);
        bytes memory forwardedCall = abi.encodePacked(callData, projectOwner);

        vm.prank(trustedForwarder);
        (bool success,) = address(erc2771Handle).call(forwardedCall);
        assertTrue(success, "ERC2771 forwarded call failed");

        // Parts should be stored under projectOwner, not trustedForwarder.
        assertEq(erc2771Handle.ensNamePartsOf(chainId, projectId, projectOwner), nameParts);

        // Forwarder's own record should be empty.
        assertEq(erc2771Handle.ensNamePartsOf(chainId, projectId, trustedForwarder), new string[](0));
    }

    /// @notice Non-forwarder call stores parts under msg.sender, not appended address.
    function test_erc2771_nonForwarderCallStoresUnderMsgSender() public {
        address trustedForwarder = address(0x1234);
        JBProjectHandles erc2771Handle = new JBProjectHandles(trustedForwarder);

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = "direct";

        // Direct call (not from forwarder).
        vm.prank(projectOwner);
        erc2771Handle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Stored under projectOwner.
        assertEq(erc2771Handle.ensNamePartsOf(chainId, projectId, projectOwner), nameParts);
    }

    //*********************************************************************//
    // -------------------- constants / immutables ----------------------- //
    //*********************************************************************//

    function test_constants_textKeyIsJuicebox() public view {
        assertEq(keccak256(bytes(projectHandle.TEXT_KEY())), keccak256(bytes("juicebox")));
    }

    function test_constants_ensRegistryAddress() public view {
        assertEq(address(projectHandle.ENS_REGISTRY()), 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    }

    //*********************************************************************//
    // -------------------- dot validation edge cases -------------------- //
    //*********************************************************************//

    /// @notice Dot at the very start of a part.
    function test_setEnsNamePartsFor_dotAtStartReverts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](1);
        nameParts[0] = ".leading";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, ".leading"));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);
    }

    /// @notice Dot at the very end of a part.
    function test_setEnsNamePartsFor_dotAtEndReverts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](1);
        nameParts[0] = "trailing.";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, "trailing."));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);
    }

    /// @notice Part that is just a dot.
    function test_setEnsNamePartsFor_singleDotReverts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](1);
        nameParts[0] = ".";

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(JBProjectHandles.JBProjectHandles_InvalidNamePart.selector, "."));
        projectHandle.setEnsNamePartsFor(1, projectId, nameParts);
    }

    //*********************************************************************//
    // ------------------------------ helpers ---------------------------- //
    //*********************************************************************//

    /// @notice Assert equals between two string arrays.
    function assertEq(string[] memory first, string[] memory second) internal pure override {
        assertEq(first.length, second.length);
        for (uint256 i; i < first.length; i++) {
            assertEq(keccak256(bytes(first[i])), keccak256(bytes(second[i])));
        }
    }

    /// @notice Compute a namehash for an ENS name.
    function _namehash(string[] memory ensName) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        bytes memory handle = bytes(_formatHandle(ensName));
        uint256 labelEnd = handle.length;

        for (uint256 i = handle.length; i > 0; i--) {
            if (handle[i - 1] != ".") continue;

            namehash =
                keccak256(abi.encodePacked(namehash, keccak256(_slice({input: handle, start: i, end: labelEnd}))));
            labelEnd = i - 1;
        }

        namehash = keccak256(abi.encodePacked(namehash, keccak256(_slice({input: handle, start: 0, end: labelEnd}))));
    }

    function _formatHandle(string[] memory ensNameParts) internal pure returns (string memory handle) {
        for (uint256 i = 1; i <= ensNameParts.length; i++) {
            handle = string(abi.encodePacked(handle, ensNameParts[ensNameParts.length - i]));
            if (i < ensNameParts.length) handle = string(abi.encodePacked(handle, "."));
        }
    }

    function _slice(bytes memory input, uint256 start, uint256 end) internal pure returns (bytes memory output) {
        output = new bytes(end - start);

        for (uint256 i; i < output.length; i++) {
            output[i] = input[start + i];
        }
    }

    /// @notice Check if any part in the array contains a byte sequence rejected by `setEnsNamePartsFor`.
    function _hasRejectedByteInAny(string[] memory parts) internal pure returns (bool) {
        for (uint256 i; i < parts.length; i++) {
            bytes memory b = bytes(parts[i]);
            for (uint256 j; j < b.length; j++) {
                if (
                    b[j] < 0x20 || b[j] == 0x7f || _isDisallowedUnicodeFormat(b, j)
                        || (b[j] == "." && (j == 0 || j == b.length - 1 || b[j - 1] == "."))
                ) return true;
            }
        }
        return false;
    }

    function _isDisallowedUnicodeFormat(bytes memory input, uint256 index) internal pure returns (bool) {
        uint256 length = input.length;

        if (input[index] == 0xd8) return index + 1 < length && input[index + 1] == 0x9c;

        if (input[index] == 0xe2) {
            if (index + 2 >= length) return false;

            bytes1 second = input[index + 1];
            bytes1 third = input[index + 2];

            if (second == 0x80) return (third >= 0x8b && third <= 0x8f) || (third >= 0xaa && third <= 0xae);
            if (second == 0x81) return third >= 0xa6 && third <= 0xa9;

            return false;
        }

        if (input[index] == 0xef) {
            return index + 2 < length && input[index + 1] == 0xbb && input[index + 2] == 0xbf;
        }

        return false;
    }
}
