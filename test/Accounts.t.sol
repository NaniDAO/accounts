// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Account} from "../src/Account.sol";
import {Accounts} from "../src/Accounts.sol";

import "@solady/test/utils/SoladyTest.sol";

contract AccountsTest is SoladyTest {
    address internal owner;
    Account internal erc4337;
    Accounts internal accounts;

    function setUp() public {
        erc4337 = new Account();
        accounts = new Accounts(address(erc4337));
    }

    function testDeploy() public {
        Account account = new Account();
        new Accounts(address(account));
    }
}
