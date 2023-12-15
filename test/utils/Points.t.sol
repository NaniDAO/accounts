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

    uint256 constant POT = 1_000_000_000;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        MockERC4337 account;
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
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        uint256 bal = points.check(bob, start, bonus, abi.encodePacked(r, s, v));
        assertEq(bal, bonus + 41);
    }

    function testClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(MockERC20(token).balanceOf(bob), bonus + 41);
    }

    function testFailDoubleClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(MockERC20(token).balanceOf(bob), bonus);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
    }
}
