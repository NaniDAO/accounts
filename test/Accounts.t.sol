// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/test/utils/SoladyTest.sol";

import {Account} from "../src/Account.sol";
import {Accounts} from "../src/Accounts.sol";

contract AccountsTest is SoladyTest {
    address internal owner;
    address internal erc4337;
    Accounts internal accounts;

    function setUp() public {
        erc4337 = address(new Account());
        accounts = new Accounts(erc4337, bytes32(0));
        owner = accounts.getAddress(bytes32(0));
    }

    function testDeploy() public {
        new Accounts(erc4337, bytes32(0));
    }

    function testDelegate(bytes4 selector, address executor) public {
        vm.prank(owner);
        accounts.delegate(selector, executor);
        accounts.get(selector);
        assertEq(executor, accounts.get(selector));
    }

    function testFailDelegate(bytes4 selector, address executor) public {
        accounts.delegate(selector, executor);
    }
}
