// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";
import {Token} from "../../src/governance/Token.sol";

contract TokenTest is Test {
    Token token;

    address constant alice = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38; // DefaultSender.

    address bob;
    uint256 bobPk;

    uint256 constant MAX = 1e27;

    function setUp() public {
        (bob, bobPk) = makeAddrAndKey("bob");
        token = new Token();
    }

    function testDeploy() public {
        new Token();
    }

    function testNameAndSymbolAndDecimals() public {
        assertEq(token.name(), "NANI");
        assertEq(token.symbol(), unicode"❂");
        assertEq(token.decimals(), 18);
    }

    function testTotalSupply() public {
        assertEq(token.totalSupply(), MAX);
    }

    function testInitBalance() public {
        assertEq(token.balanceOf(alice), MAX);
    }

    function testTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token) && to != alice);
        vm.assume(amount <= MAX);
        assertEq(token.balanceOf(alice), MAX);
        vm.prank(alice);
        token.transfer(to, amount);
        assertEq(token.balanceOf(alice), MAX - amount);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), MAX);
    }

    function testFailUnsafeTransfer(address to) public {
        vm.assume(to != address(0) && to != address(token));
        vm.prank(alice);
        token.transfer(to, MAX + 1);
    }

    function testFailTransferBeyondBalance(address to) public {
        vm.assume(to != address(0) && to != address(token));
        vm.prank(alice);
        token.transfer(to, 1 ether);
        vm.prank(to);
        token.transfer(alice, 1 ether + 1);
    }

    function testTransferFromOwner(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));
        vm.assume(amount <= MAX);
        assertEq(token.balanceOf(alice), MAX);
        vm.prank(alice);
        token.transferFrom(alice, to, amount);
        assertEq(token.balanceOf(alice), MAX - amount);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), MAX);
    }
}
