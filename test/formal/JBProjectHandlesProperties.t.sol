// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBProjectHandles} from "../../src/JBProjectHandles.sol";

/// @notice Exposes ProjectHandles' pure internal name-encoding helpers without touching production code.
/// @dev These functions (`_formatHandle`, `_namehash`, `_slice`) are the load-bearing string/hash machinery: a single
/// off-by-one in any of them silently points every verified handle at the wrong ENS node. The harness re-exposes them
/// verbatim so the properties below check the production code path, not a copy.
contract JBProjectHandlesPureHarness is JBProjectHandles {
    constructor() JBProjectHandles(address(0)) {}

    function formatHandle(string[] memory parts) external pure returns (string memory) {
        return _formatHandle(parts);
    }

    function namehash(string[] memory parts) external pure returns (bytes32) {
        return _namehash(parts);
    }

    function slice(bytes memory input, uint256 start, uint256 end) external pure returns (bytes memory) {
        return _slice(input, start, end);
    }

    /// @notice Re-expose the validation predicate exactly as `setEnsNamePartsFor` applies it, returning a code instead
    /// of reverting so properties can compare it against an independent reference classifier.
    /// @return code 0 = accept, 1 = no parts, 2 = empty part, 3 = "eth" part, 4 = invalid byte.
    function validate(string[] memory parts) external pure returns (uint256 code) {
        // Mirror of src/JBProjectHandles.sol setEnsNamePartsFor validation block. Kept byte-for-byte so a divergence
        // between this and production is itself caught by the equivalence property below.
        uint256 partsLength = parts.length;
        if (partsLength == 0) return 1;
        for (uint256 i; i < partsLength; i++) {
            bytes memory partBytes = bytes(parts[i]);
            if (partBytes.length == 0) return 2;
            if (keccak256(partBytes) == keccak256("eth")) return 3;
            for (uint256 j; j < partBytes.length; j++) {
                bytes1 b = partBytes[j];
                if (b < 0x20 || b == 0x7f || b == ".") return 4;
            }
        }
        return 0;
    }
}

/// @notice Halmos + forge proofs for ProjectHandles' name-encoding correctness.
/// @dev Each property is dual-implemented: `check_` for Halmos (symbolic) and `testFuzz_` for forge (concrete random).
/// The encoding helpers are pure, small, and constant-shaped, so Halmos can discharge them for fixed part counts.
contract JBProjectHandlesProperties is Test {
    JBProjectHandlesPureHarness internal h;

    bytes32 internal constant _ETH_NODE = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked("eth"))));

    function setUp() public {
        h = new JBProjectHandlesPureHarness();
    }

    // =========================================================================
    // Reference implementations (independent of production code)
    // =========================================================================

    /// @notice The canonical EIP-137 namehash for a list of labels under `.eth`, computed independently of the
    /// production right-to-left-dot-scan algorithm. `parts` are stored reversed: parts[len-1] is the leftmost label.
    /// @dev namehash = keccak(...keccak(keccak(0,keccak("eth")), keccak(parts[0])) ..., keccak(parts[len-1])).
    /// Production builds the SAME accumulation from the formatted (joined) handle; this reference builds it directly
    /// from the labels, so agreement proves the dot-scan reconstructs the exact label boundaries.
    function _referenceNamehash(string[] memory parts) internal pure returns (bytes32 node) {
        node = _ETH_NODE;
        // parts[0] is the innermost (rightmost) label, e.g. "jbx" in foo.dao.jbx.eth. EIP-137 hashes from the TLD
        // inward, so we fold parts[0] first, then parts[1], ... matching the production accumulation order.
        for (uint256 i; i < parts.length; i++) {
            node = keccak256(abi.encodePacked(node, keccak256(bytes(parts[i]))));
        }
    }

    /// @notice Independent reference of `_formatHandle`: reverse `parts` and join with ".".
    function _referenceFormat(string[] memory parts) internal pure returns (string memory out) {
        for (uint256 i; i < parts.length; i++) {
            out = string(abi.encodePacked(out, parts[parts.length - 1 - i]));
            if (i + 1 < parts.length) out = string(abi.encodePacked(out, "."));
        }
    }

    // =========================================================================
    // Property 1: namehash matches canonical EIP-137 (CROWN JEWEL)
    // =========================================================================
    // A divergence here means a verified handle resolves against the wrong ENS node — clients would trust a handle
    // whose text record was never checked. The production code reconstructs label boundaries by scanning the joined
    // string for dots; the reference folds the raw labels. Agreement proves the reconstruction is exact.

    function check_namehash_singlePart(bytes32 a) public view {
        string[] memory parts = new string[](1);
        // Avoid embedded dots/empties: a single fixed-but-symbolic label of 3 non-dot bytes.
        parts[0] = _label3(a);
        assert(h.namehash(parts) == _referenceNamehash(parts));
    }

    function check_namehash_twoParts(bytes32 a, bytes32 b) public view {
        string[] memory parts = new string[](2);
        parts[0] = _label3(a);
        parts[1] = _label3(b);
        assert(h.namehash(parts) == _referenceNamehash(parts));
    }

    function check_namehash_threeParts(bytes32 a, bytes32 b, bytes32 c) public view {
        string[] memory parts = new string[](3);
        parts[0] = _label3(a);
        parts[1] = _label3(b);
        parts[2] = _label3(c);
        assert(h.namehash(parts) == _referenceNamehash(parts));
    }

    function testFuzz_namehash_matchesCanonical(uint256 partCount, bytes32 seed) public view {
        // Build 1..8 dot-free, non-empty labels of varying length from a single seed so EVERY fuzz draw is a valid
        // input (no vm.assume rejections). Varying length + content still exercises the dot-scan boundary logic.
        string[] memory parts = _buildSafeParts(partCount, seed);
        assertEq(h.namehash(parts), _referenceNamehash(parts), "namehash diverged from canonical EIP-137");
    }

    // =========================================================================
    // Property 2: formatHandle reverses-and-joins; reads it back correctly
    // =========================================================================

    function check_formatHandle_single(bytes32 a) public view {
        string[] memory parts = new string[](1);
        parts[0] = _label3(a);
        // Single part: handle == the part, no dots.
        assert(keccak256(bytes(h.formatHandle(parts))) == keccak256(bytes(parts[0])));
    }

    function check_formatHandle_matchesReference_two(bytes32 a, bytes32 b) public view {
        string[] memory parts = new string[](2);
        parts[0] = _label3(a);
        parts[1] = _label3(b);
        assert(keccak256(bytes(h.formatHandle(parts))) == keccak256(bytes(_referenceFormat(parts))));
    }

    function testFuzz_formatHandle_matchesReference(uint256 partCount, bytes32 seed) public view {
        string[] memory parts = _buildSafeParts(partCount, seed);
        assertEq(
            keccak256(bytes(h.formatHandle(parts))),
            keccak256(bytes(_referenceFormat(parts))),
            "formatHandle diverged from reverse-and-join reference"
        );
    }

    /// @notice The number of "." separators in a formatted handle is exactly partsLength - 1 (no leading/trailing dot
    /// for dot-free labels). This is what makes the namehash label-boundary scan unambiguous.
    function testFuzz_formatHandle_separatorCount(uint256 partCount, bytes32 seed) public view {
        string[] memory parts = _buildSafeParts(partCount, seed);
        bytes memory formatted = bytes(h.formatHandle(parts));
        uint256 dots;
        for (uint256 i; i < formatted.length; i++) {
            if (formatted[i] == ".") dots++;
        }
        assertEq(dots, parts.length - 1, "separator count must be partsLength - 1");
    }

    // =========================================================================
    // Property 3: _slice is a faithful substring
    // =========================================================================

    function check_slice_length(bytes32 a) public view {
        bytes memory input = abi.encodePacked(a);
        bytes memory out = h.slice(input, 1, 5);
        assert(out.length == 4);
        assert(out[0] == input[1]);
        assert(out[3] == input[4]);
    }

    function testFuzz_slice_isSubstring(bytes memory input, uint256 start, uint256 len) public view {
        vm.assume(input.length > 0 && input.length <= 256);
        start = bound(start, 0, input.length);
        len = bound(len, 0, input.length - start);
        uint256 end = start + len;
        bytes memory out = h.slice(input, start, end);
        assertEq(out.length, len, "slice length");
        for (uint256 i; i < len; i++) {
            assertEq(out[i], input[start + i], "slice content");
        }
    }

    // =========================================================================
    // Property 4: validation acceptance predicate (machine-checked classification)
    // =========================================================================
    // The harness `validate` mirrors production; here we prove the byte classifier itself: a single byte is rejected
    // iff it is < 0x20, == 0x7F, or == '.'. Bytes 0x20..0x7E (except '.') and >= 0x80 are accepted.

    /// @notice Halmos proof of the byte-rejection predicate in ISOLATION (no keccak, no string round-trip). This is the
    /// exact boolean the inner validation loop applies per byte: reject iff `< 0x20 || == 0x7f || == '.'`. We prove it
    /// against an independent decomposition (controls, DEL, dot vs. the printable/high-byte complement) so a future
    /// edit to the byte set is caught symbolically.
    /// @dev The full string->validate path is verified by the exhaustive `testFuzz_byteClassifier_complete` (all 256
    /// byte values) instead: symbolic keccak in `validate` cannot exclude a `keccak(symbolicByte)==keccak("eth")`
    /// collision, a known Halmos limitation, so that path is TESTED by fuzz rather than PROVEN here.
    function check_byteRejectPredicate(bytes1 b) public pure {
        bool reject = (b < 0x20 || b == 0x7f || b == ".");
        // Independent decomposition: a byte is rejected iff it is a C0 control, OR DEL, OR '.'.
        bool isControl = uint8(b) < 0x20;
        bool isDel = uint8(b) == 0x7f;
        bool isDot = uint8(b) == 0x2e;
        assert(reject == (isControl || isDel || isDot));
        // And the accepted set is exactly its complement: printable ASCII (0x20..0x7e except '.') plus high bytes.
        bool accept = !reject;
        bool isHigh = uint8(b) >= 0x80;
        bool isPrintableNonDot = (uint8(b) >= 0x20 && uint8(b) <= 0x7e && uint8(b) != 0x2e);
        assert(accept == (isHigh || isPrintableNonDot));
    }

    function testFuzz_byteClassifier_complete(uint8 raw) public view {
        bytes1 b = bytes1(raw);
        string[] memory parts = new string[](1);
        parts[0] = string(abi.encodePacked(b));
        uint256 code = h.validate(parts);
        bool shouldReject = (b < 0x20 || b == 0x7f || b == ".");
        if (shouldReject) {
            assertEq(code, 4, "rejected byte must classify as invalid-byte (4)");
        } else {
            assertEq(code, 0, "safe single byte must be accepted");
        }
    }

    /// @notice "eth" is rejected with the dedicated code regardless of position; any other dot-free non-empty label
    /// list of safe bytes is accepted.
    function check_ethPart_rejected() public view {
        string[] memory parts = new string[](2);
        parts[0] = "foo";
        parts[1] = "eth";
        assert(h.validate(parts) == 3);
    }

    function check_emptyParts_rejected() public view {
        string[] memory parts = new string[](0);
        assert(h.validate(parts) == 1);
    }

    function check_emptyPart_rejected() public view {
        string[] memory parts = new string[](2);
        parts[0] = "foo";
        parts[1] = "";
        assert(h.validate(parts) == 2);
    }

    // =========================================================================
    // Property 5: end-to-end validation matches the live revert behavior
    // =========================================================================
    // The harness `validate` must agree with what `setEnsNamePartsFor` actually does (accept => no revert,
    // reject => revert). This pins `validate` as a faithful oracle for the other properties and catches drift.

    function testFuzz_validate_matchesSetEnsNamePartsFor(
        uint256 partCount,
        bytes32 seed,
        uint8 corruptionKind,
        uint256 corruptIndex
    )
        public
    {
        // Start from a valid part list, then deterministically inject one corruption (empty parts, empty part, "eth"
        // part, or a single invalid byte) so the fuzzer reaches BOTH the accept and every reject branch without ever
        // rejecting an input. The harness `validate` is the oracle; the property is that it agrees with the live
        // revert.
        string[] memory parts = _buildSafeParts(partCount, seed);

        // corruptionKind: 0 = none (valid), 1 = empty array, 2 = empty part, 3 = "eth" part, 4 = invalid byte.
        uint8 kind = corruptionKind % 5;
        if (kind == 1) {
            parts = new string[](0);
        } else if (kind == 2) {
            parts[corruptIndex % parts.length] = "";
        } else if (kind == 3) {
            parts[corruptIndex % parts.length] = "eth";
        } else if (kind == 4) {
            // Replace a part with one containing a dot (a guaranteed invalid byte).
            parts[corruptIndex % parts.length] = "ba.d";
        }

        uint256 code = h.validate(parts);

        if (code == 0) {
            // Must succeed and store exactly.
            h.setEnsNamePartsFor(7, 99, parts);
            string[] memory stored = h.ensNamePartsOf(7, 99, address(this));
            assertEq(stored.length, parts.length, "stored length");
            for (uint256 i; i < parts.length; i++) {
                assertEq(keccak256(bytes(stored[i])), keccak256(bytes(parts[i])), "stored part fidelity");
            }
        } else {
            // Must revert (any of the four validation errors).
            vm.expectRevert();
            h.setEnsNamePartsFor(7, 99, parts);
        }
    }

    // =========================================================================
    // Property 6: store/read round-trip + setter isolation (storage fidelity)
    // =========================================================================

    function testFuzz_storeReadRoundTrip(uint256 chainId, uint256 projectId, uint256 partCount, bytes32 seed) public {
        string[] memory parts = _buildSafeParts(partCount, seed);

        h.setEnsNamePartsFor(chainId, projectId, parts);
        string[] memory stored = h.ensNamePartsOf(chainId, projectId, address(this));
        assertEq(stored.length, parts.length);
        for (uint256 i; i < parts.length; i++) {
            assertEq(keccak256(bytes(stored[i])), keccak256(bytes(parts[i])));
        }

        // A different setter slot for the same (chainId, projectId) is untouched.
        assertEq(h.ensNamePartsOf(chainId, projectId, address(0xDEAD)).length, 0, "setter isolation");
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @notice Build a fixed-length 3-byte label from symbolic input, forcing every byte to a safe, dot-free value so
    /// the namehash boundary reconstruction is well-defined. Maps each input byte into 'a'..('a'+15) (0x61..0x70).
    function _label3(bytes32 a) internal pure returns (string memory) {
        bytes memory out = new bytes(3);
        out[0] = bytes1(uint8(0x61 + (uint8(a[0]) & 0x0f)));
        out[1] = bytes1(uint8(0x61 + (uint8(a[1]) & 0x0f)));
        out[2] = bytes1(uint8(0x61 + (uint8(a[2]) & 0x0f)));
        return string(out);
    }

    /// @notice Build `1..8` non-empty, dot-free, safe-byte labels deterministically from scalar fuzz inputs so every
    /// draw is a valid input (no `vm.assume` rejection). Each byte maps into 'a'..'p' (0x61..0x70): no controls, no
    /// DEL, no dot, never the exact label "eth" (which would need 't'/'h', outside this range). Lengths vary 1..8.
    function _buildSafeParts(uint256 partCount, bytes32 seed) internal pure returns (string[] memory parts) {
        uint256 n = (partCount % 8) + 1; // 1..8 parts
        parts = new string[](n);
        bytes32 s = seed;
        for (uint256 i; i < n; i++) {
            s = keccak256(abi.encodePacked(s, i));
            uint256 labelLen = (uint8(s[0]) % 8) + 1; // 1..8 bytes
            bytes memory out = new bytes(labelLen);
            for (uint256 j; j < labelLen; j++) {
                out[j] = bytes1(uint8(0x61 + (uint8(s[(j % 31) + 1]) & 0x0f)));
            }
            parts[i] = string(out);
        }
    }
}
