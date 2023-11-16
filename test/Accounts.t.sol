// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;


import {Account} from "../src/Account.sol";
import {Accounts} from "../src/Accounts.sol";

import "@solady/test/utils/SoladyTest.sol";

contract AccountsTest is Test {
    address internal owner;
    Account internal erc4337;
    Accounts internal accounts;

    function setUp() public {
        erc4337 = new Account();
        accounts = new Accounts(address(erc4337), bytes32(0));
        owner = accounts.getAddress(bytes32(0));
    }

    function testDeploy() public {
        Account account = new Account();
        new Accounts(address(account), bytes32(0));
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

    function testDelegatedFunc() public {
        Foo foo = new Foo();

        vm.startPrank(owner);
        accounts.delegate(foo.foo.selector, address(foo));
        accounts.get(foo.foo.selector);
        assertEq(address(foo), accounts.get(foo.foo.selector));

        uint256 foos = Foo(address(accounts)).foo();
        //assertEq(Foo(address(accounts)).foos(), 1);
    }
}

contract Foo {
    uint256 public foos;

    function foo() public returns (uint256 foos) {
        console.log("foo called");
        unchecked {
            foos = ++foos;
        }
    }
}
