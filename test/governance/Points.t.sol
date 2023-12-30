// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {Token} from "../../src/governance/Token.sol";
import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {IERC20, Points} from "../../src/governance/Points.sol";

contract PointsTest is Test {
    address internal alice;
    uint256 internal alicePk;
    address internal bob;

    address internal erc4337;
    NaniAccount internal account;

    Points internal points;
    address internal token;

    uint256 internal constant _POT = 1_000_000_000;
    address internal constant _ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        // Etch something onto `_ENTRY_POINT` such that we can deploy the account implementation.
        vm.etch(_ENTRY_POINT, hex"00");
        erc4337 = address(new NaniAccount());
        account = NaniAccount(payable(address(LibClone.deployERC1967(erc4337))));
        account.initialize(alice);
        points = new Points(address(account), 1);
        token = address(new Token());
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        Token(token).transfer(address(points), _POT);
    }

    // -- TESTS

    function testDeploy() public {
        account = NaniAccount(payable(address(LibClone.deployERC1967(erc4337))));
        account.initialize(alice);
    }

    function testCheck(uint256 bonus) public {
        vm.assume(bonus < _POT);
        uint256 start = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePk, _toEthSignedMessageHash(keccak256(abi.encodePacked(bob, start, bonus)))
        );
        vm.warp(42);
        uint256 bal = points.check(bob, start, bonus, abi.encodePacked(r, s, v));
        assertEq(bal, bonus + 41);
    }

    function testClaim(uint256 bonus) public {
        vm.assume(bonus < _POT);
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
        vm.assume(bonus < _POT);
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
