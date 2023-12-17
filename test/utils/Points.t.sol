// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {Token} from "../../src/utils/Token.sol";
import {IERC20, Points} from "../../src/utils/Points.sol";
import {Account as NaniAccount} from "../../src/Account.sol";

contract PointsTest is Test {
    address alice;
    uint256 alicePk;
    address bob;

    Points points;

    address token;
    uint256 constant POT = 1_000_000_000;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        NaniAccount account = new NaniAccount();
        account.initialize(alice);
        points = new Points(address(account), 1);
        token = address(new Token());
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        Token(token).transfer(address(points), POT);
    }

    // -- TESTS

    function testDeploy() public {
        NaniAccount account = new NaniAccount();
        account.initialize(alice);
        new Points(address(account), 1);
    }

    function testCheck(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePk, _toEthSignedMessageHash(keccak256(abi.encodePacked(bob, start, bonus)))
        );
        vm.warp(42);
        uint256 bal = points.check(bob, start, bonus, abi.encodePacked(r, s, v));
        assertEq(bal, bonus + 41);
    }

    function testClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePk, _toEthSignedMessageHash(keccak256(abi.encodePacked(bob, start, bonus)))
        );
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(Token(token).balanceOf(bob), bonus + 41);
    }

    function testFailDoubleClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePk, _toEthSignedMessageHash(keccak256(abi.encodePacked(bob, start, bonus)))
        );
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(Token(token).balanceOf(bob), bonus);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }
}
