// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";
import {Invites} from "../../src/governance/Invites.sol";

contract InvitesTest is Test {
    Invites invites;
    address internal alice;
    uint256 internal alicePk;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        vm.prank(alice, alice);
        invites = new Invites();
    }

    function testMint() public {
        vm.prank(alice, alice);
        string memory message = "god's cutest soldier";
        invites.invite(address(this), message);
        assertEq(invites.balanceOf(address(this)), 1);

        string memory uri = invites.tokenURI(uint256(keccak256(bytes(message))));
        console.log(uri);
    }
}
