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
        owner = accounts.getAddress(bytes32(0));
    }

    function testDeploy() public {
        Account account = new Account();
        new Accounts(address(account));
    }

    function testDelegate(bytes4 selector, address executor) public {
        vm.prank(owner);
        accounts.set(selector, executor);
        accounts.get(selector);
        assertEq(executor, accounts.get(selector));
    }

    function testFailDelegate(bytes4 selector, address executor) public {
        accounts.set(selector, executor);
    }

    function testDelegatedFunc(bytes32 key) public {
        if (key == bytes32(0)) {
            return;
        }

        Foo foo = new Foo();

        vm.startPrank(owner);
        accounts.set(foo.foo.selector, address(foo));
        accounts.get(foo.foo.selector);
        assertEq(address(foo), accounts.get(foo.foo.selector));

        Foo(address(accounts)).foo(key);

        accounts.set(foo.getFoos.selector, address(foo));
        accounts.get(foo.getFoos.selector);
        assertEq(address(foo), accounts.get(foo.getFoos.selector));

        assertEq(Foo(address(accounts)).getFoos(key), 1);
    }
}

contract Foo {
    mapping(bytes32 => uint256) public foos;

    function foo(bytes32 key) public {
        unchecked {
            foos[key]++;
        }
    }

    function getFoos(bytes32 key) public view returns (uint256) {
        return foos[key];
    }
}
