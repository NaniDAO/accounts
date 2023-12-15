// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {MockERC4337} from "@solady/test/utils/mocks/MockERC4337.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";
import {IERC20, Points} from "../../src/utils/Points.sol";
import "@forge/Test.sol";

contract PointsTest is Test {
    address alice;
    uint256 alicePk;
    address bob;
    Points points;
    address token;

    MockERC4337 account;

    uint256 constant POT = 1_000_000_000;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        points = new Points(address(account = new MockERC4337()), 1);
        account.initialize(alice);
        token = address(new MockERC20("TEST", "TEST", 18));
        MockERC20(token).mint(address(points), POT);
    }

    // -- TESTS

    function testDeploy() public {
        new Points(alice, 1);
    }

    function testCheck(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        vm.warp(42);
        uint256 bal = points.check(bob, start, bonus, sign(alicePk, bob, start, bonus));
        assertEq(bal, bonus + 41);
    }

    function testClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, sign(alicePk, bob, start, bonus));
        assertEq(MockERC20(token).balanceOf(bob), bonus + 41);
    }

    function testFailDoubleClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, sign(alicePk, bob, start, bonus));
        assertEq(MockERC20(token).balanceOf(bob), bonus);
        points.claim(IERC20(token), start, bonus, sign(alicePk, bob, start, bonus));
    }

    function sign(uint256 pK, address user, uint256 start, uint256 bonus)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash = keccak256(abi.encodePacked(user, start, bonus));
        bytes32 rehash = keccak256(abi.encodePacked("\x19\x01", _buildDomainSeparator(), hash));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(pK, keccak256(abi.encode(address(account), rehash)));
        return abi.encodePacked(r, s, v);
    }

    /// @dev Returns the EIP-712 domain separator.
    function _buildDomainSeparator() private view returns (bytes32 separator) {
        // We will use `separator` to store the name hash to save a bit of gas.
        separator = keccak256(bytes("NANI"));
        bytes32 versionHash = keccak256(bytes("0.0.0"));
        address _account = address(account);
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), separator) // Name hash.
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), _account)
            separator := keccak256(m, 0xa0)
        }
    }

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 internal constant _DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
}
