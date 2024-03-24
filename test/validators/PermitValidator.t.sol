// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";
import "@solady/test/utils/TestPlus.sol";

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {LibClone} from "@solady/src/utils/LibClone.sol";
import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

import {PermitValidator} from "../../src/validators/PermitValidator.sol";
import {Account as NaniAccount} from "../../src/Account.sol";

contract PermitValidatorTester {
    enum State {
        PENDING,
        APPROVED,
        REJECTED,
        CANCELLED,
        EXECUTED,
        EXPIRED,
        FAILED
    }

    struct StaticTuple {
        address a;
        uint256 b;
        bool c;
    }

    constructor() payable {}

    function getRandomState() public pure returns (uint256[] memory) {
        uint256[] memory randomStates = new uint256[](7);
        for (uint256 i = 0; i < 7; i++) {
            randomStates[i] = uint256(State(i));
        }
        return randomStates;
    }

    function dataUint(uint256 data) public pure returns (uint256) {
        return data;
    }

    function dataInt(int256 data) public pure returns (int256) {
        return data;
    }

    function dataAddress(address data) public pure returns (address) {
        return data;
    }

    function dataValue() public payable returns (uint256) {
        return msg.value;
    }

    function dataBool(bool data) public pure returns (bool) {
        return data;
    }
}

contract PermitValidatorTest is Test, TestPlus {
    address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    PermitValidator permissions;

    address payable erc4337;
    address payable account;

    address alice;
    uint256 aliceKey;
    address bob;
    uint256 bobKey;

    MockERC20 mockERC20;
    PermitValidatorTester tester;

    function setUp() public payable {
        (alice, aliceKey) = makeAddrAndKey("alice");
        (bob, bobKey) = makeAddrAndKey("bob");
        permissions = new PermitValidator();
        erc4337 = payable(address(new NaniAccount()));
        account = payable(address(LibClone.deployERC1967(erc4337)));
        mockERC20 = new MockERC20("Token", "TKN", 18);
        mockERC20.mint(account, 10 ether);
        NaniAccount(account).initialize(alice);
        tester = new PermitValidatorTester();
    }

    function testInstall() public {
        address[] memory _authorized = getTargets(8, alice);
        vm.startPrank(account);
        permissions.install(_authorized);
        address[] memory authorized = permissions.getAuthorizers(account);
        assertEq(authorized.length, _authorized.length);
        for (uint256 i = 0; i < authorized.length; i++) {
            assertEq(authorized[i], _authorized[i]);
        }
        permissions.uninstall();
    }

    function testValuePermission(uint256 value, uint256 maxValue) public {
        vm.assume(value <= type(uint128).max);
        vm.assume(value <= maxValue);
        vm.assume(maxValue <= type(uint128).max);
        if (value > maxValue) {
            return;
        }
        address[] memory targets = getTargets(0, alice);
        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });
        string memory intent = "send money";
        PermitValidator.Permit memory permit = createPermit(
            targets,
            uint192(maxValue),
            uint32(0),
            bytes4(0),
            intent,
            spans,
            new PermitValidator.Arg[](0)
        );
        uint256 assertion = value <= permit.allowance ? 0 : 1;

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, alice, value, hex"0000"
                )
            ),
            assertion
        );
    }

    function testTimePermissions() public {
        PermitValidator.Span[] memory spans = new PermitValidator.Span[](3);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });
        spans[1] = PermitValidator.Span({
            validAfter: uint32(block.timestamp + 100000),
            validUntil: uint32(block.timestamp + 200000)
        });
        spans[2] = PermitValidator.Span({
            validAfter: uint32(block.timestamp + 200000),
            validUntil: uint32(block.timestamp + 300000)
        });
        // count should be a random value between 0-2
        uint256 count = uint256(block.timestamp) % 3;

        address[] memory targets = getTargets(0, alice);
        string memory intent = "ping alice";

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), bytes4(0), intent, spans, new PermitValidator.Arg[](0)
        );

        uint256 assertion = (
            spans[count].validAfter > block.timestamp && spans[count].validUntil < block.timestamp
        ) ? 0 : 1;

        if (assertion == 1) {
            vm.expectRevert();
            permissions.validatePermit(
                permit,
                spans[count],
                abi.encodeWithSelector(NaniAccount(account).execute.selector, alice, 0, hex"0000")
            );
        } else {
            assertEq(
                permissions.validatePermit(
                    permit,
                    spans[count],
                    abi.encodeWithSelector(
                        NaniAccount(account).execute.selector, alice, 0, hex"0000"
                    )
                ),
                0
            );
        }
    }

    function testUintPermission(uint256 amt, uint256 min, uint256 max) public {
        vm.assume(amt > min || amt < max);
        if ((amt < min) || (amt > max)) return;
        if (amt == 0) return;
        uint256 assertion = (amt >= min && amt <= max) ? 0 : 1;

        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](1);
        args[0]._type = PermitValidator.Type.Uint;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(min, max);
        args[0].length = 32;
        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), tester.dataUint.selector, intent, spans, args
        );

        bytes memory callData = abi.encodeWithSelector(tester.dataUint.selector, (amt));

        vm.warp(42);

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, targets[0], 0, callData
                )
            ),
            assertion
        );
    }

    function testEnumPermission(uint256 num) public {
        num = bound(num, 0, uint8(PermitValidatorTester.State.FAILED));

        uint256[] memory n = new uint256[](1);
        n[0] = num;

        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](1);
        args[0]._type = PermitValidator.Type.Uint8;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(n);
        args[0].length = 32;

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), tester.dataUint.selector, intent, spans, args
        );

        bytes memory callData = abi.encodeWithSelector(tester.dataUint.selector, (num));

        uint256 assertion = (num <= uint8(PermitValidatorTester.State.FAILED)) ? 0 : 1;

        vm.warp(42);

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, targets[0], 0, callData
                )
            ),
            assertion
        );
    }

    function testAddressPermission(address addr) public {
        vm.assume(addr != address(0));

        address[] memory n = new address[](1);
        n[0] = addr;

        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](1);
        args[0]._type = PermitValidator.Type.Address;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(n);
        args[0].length = 32;

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), tester.dataAddress.selector, intent, spans, args
        );

        bytes memory callData = abi.encodeWithSelector(tester.dataAddress.selector, (addr));

        uint256 assertion = (addr > address(0)) ? 0 : 1;

        vm.warp(42);

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, targets[0], 0, callData
                )
            ),
            assertion
        );
    }

    function testBoolPermission(bool b) public {
        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](1);
        args[0]._type = PermitValidator.Type.Bool;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(b);
        args[0].length = 32;

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), tester.dataBool.selector, intent, spans, args
        );

        bytes memory callData = abi.encodeWithSelector(tester.dataBool.selector, (b));

        uint256 assertion = b == b ? 0 : 1;

        vm.warp(42);

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, targets[0], 0, callData
                )
            ),
            assertion
        );
    }

    function testTransferPermission(address to, uint256 amt, uint256 min, uint256 max) public {
        vm.assume(to != address(0));
        vm.assume(amt > min || amt < max);
        if ((amt < min) || (amt > max)) return;
        if (amt == 0) return;
        uint256 assertion = (amt >= min && amt <= max && (to > address(0))) ? 0 : 1;

        address[] memory a = new address[](1);
        a[0] = to;

        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](2);
        args[0]._type = PermitValidator.Type.Address;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(a);
        args[0].length = 32;

        args[1]._type = PermitValidator.Type.Uint;
        args[1].offset = 4 + 32 + 32 + 32 + 32 + 4 + 32;
        args[1].bounds = abi.encode(min, max);
        args[1].length = 32;

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), mockERC20.transfer.selector, intent, spans, args
        );

        bytes memory callData = abi.encodeWithSelector(mockERC20.transfer.selector, to, amt);

        vm.warp(42);

        assertEq(
            permissions.validatePermit(
                permit,
                spans[0],
                abi.encodeWithSelector(
                    NaniAccount(account).execute.selector, targets[0], 0, callData
                )
            ),
            assertion
        );
    }

    /*function testTransferPermissionValidation(address to, uint256 amt, uint256 min, uint256 max)
        public
    {
        vm.assume(to != address(0) && amt != 0);
        vm.assume((amt >= min || amt <= max) && amt <= 10 ether);
        uint256 assertion = (amt >= min && amt <= max && (to > address(0))) ? 0 : 1;

        address[] memory a = new address[](1);
        a[0] = to;

        address[] memory targets = new address[](1);
        targets[0] = address(tester);

        PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
        spans[0] = PermitValidator.Span({
            validAfter: uint32(block.timestamp),
            validUntil: uint32(block.timestamp + 100000)
        });

        string memory intent = "";

        PermitValidator.Arg[] memory args = new PermitValidator.Arg[](2);
        args[0]._type = PermitValidator.Type.Address;
        args[0].offset = 4 + 32 + 32 + 32 + 32 + 4;
        args[0].bounds = abi.encode(a);

        args[1]._type = PermitValidator.Type.Uint;
        args[1].offset = 4 + 32 + 32 + 32 + 32 + 4 + 32;
        args[1].bounds = abi.encode(min, max);

        PermitValidator.Permit memory permit = createPermit(
            targets, uint192(0), uint32(0), mockERC20.transfer.selector, intent, spans, args
        );

        vm.prank(account);
        permissions.setPermitHash(permit);

        bytes32 permitHash = permissions.getPermitHash(account, permit);
        uint192 key = type(uint192).max;

        address[] memory authorizers = new address[](1);
        authorizers[0] = bob;

        NaniAccount.Call[] memory calls = new NaniAccount.Call[](2);
        calls[0].target = address(permissions);
        calls[0].value = 0 ether;
        calls[0].data = abi.encodeWithSelector(permissions.install.selector, authorizers);

        calls[1].target = address(account);
        calls[1].value = 0 ether;
        calls[1].data = abi.encodeWithSelector(
            ERC4337(account).storageStore.selector,
            bytes32(abi.encodePacked(key)),
            bytes32(abi.encodePacked(address(permissions)))
        );
        vm.startPrank(alice);
        ERC4337(account).executeBatch(calls);

        bytes memory stored = ERC4337(account).execute(
            address(account),
            0 ether,
            abi.encodeWithSelector(
                ERC4337(account).storageLoad.selector, bytes32(abi.encodePacked(key))
            )
        );
        assertEq(bytes20(bytes32(stored)), bytes20(address(permissions)));

        NaniAccount.UserOperation memory userOp;
        userOp.sender = address(account);
        userOp.callData = abi.encodeWithSelector(
            ERC4337(account).execute.selector,
            address(this),
            0 ether,
            abi.encodeWithSelector(mockERC20.transfer.selector, to, amt)
        );

        userOp.nonce = 0 | (uint256(key) << 64);
        bytes32 userOpHash = hex"00";
        userOp.signature =
            abi.encode(permitHash, _sign(bobKey, _toEthSignedMessageHash(userOpHash)));

        vm.warp(42);
        vm.startPrank(_ENTRY_POINT);
        uint256 validationData = ERC4337(account).validateUserOp(userOp, userOpHash, 0);
        if (validationData == 0) {
            console.log("validationData is 0");
            vm.startPrank(_ENTRY_POINT);
            ERC4337(account).execute(
                address(account),
                0 ether,
                abi.encodeWithSelector(mockERC20.transfer.selector, to, amt)
            );
        }
    }*/

    // function testStaticTuple(PermissionsTester.StaticTuple memory s) public {
    //     PermissionsTester tester = new PermissionsTester();
    //     address[] memory targets = getTargets(0, alice);

    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](1);
    //      PermitValidator.Param[] memory bounds = new PermitValidator.Param[](s.length);
    //     arguments[0] = Param({
    //         _type: PermitValidator.TYPE.TUPLE,
    //         offset: 4,
    //         rules: abi.encode(),
    //         length: 3
    //     });

    //     Slip memory permit = createPermit(
    //         targets,
    //         0,
    //         tester.dataUint.selector,
    //         arguments,
    //         5,
    //         uint32(block.timestamp),
    //         uint32(block.timestamp + 100000)
    //     );

    //     Call memory call =
    //         Call({to: alice, value: 0, data: abi.encodeCall(tester.dataUint, (uint(1)))});

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);

    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));
    //     assertEq(permissions.checkPermission(account, sig, permit, call), true);
    // }

    // function testCheckTransferPermission() public {
    //     MockERC20 token = new MockERC20("Token", "TKN", 18);

    //     address[] memory targets = new address[](1);
    //     targets[0] = address(token);

    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](2);
    //     arguments[0] = Param({
    //         _type: PermitValidator.TYPE.ADDRESS,
    //         offset: 4,
    //         rules: abi.encodePacked(address(this), alice),
    //         length: 0
    //     });
    //     arguments[1] = Param({
    //         _type: PermitValidator.TYPE.UINT,
    //         offset: 36,
    //         rules: abi.encodePacked(uint(2 ether)),
    //         length: 0
    //     });

    //     Slip memory permit = createPermit(
    //         targets,
    //         0,
    //         token.transfer.selector,
    //         arguments,
    //         5,
    //         uint32(block.timestamp),
    //         uint32(block.timestamp + 100000)
    //     );
    //     Call memory call = Call({
    //         to: address(token),
    //         value: 0,
    //         data: abi.encodeWithSelector(token.transfer.selector, address(this), 1.5 ether)
    //     });

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);
    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));

    //     assertTrue(permissions.checkPermission(account, sig, permit, call));
    // }

    // function testFailCheckTransferPermission() public {
    //     MockERC20 token = new MockERC20("Token", "TKN", 18);

    //     address[] memory targets = new address[](1);
    //     targets[0] = address(token);

    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](2);
    //     arguments[0] = Param({
    //         _type: PermitValidator.TYPE.ADDRESS,
    //         offset: 4,
    //         rules: abi.encodePacked(address(this), alice),
    //         length: 0
    //     });
    //     arguments[1] = Param({
    //         _type: PermitValidator.TYPE.UINT,
    //         offset: 36,
    //         rules: abi.encodePacked(uint(2 ether)),
    //         length: 0
    //     });

    //     Slip memory permit = createPermit(
    //         targets,
    //         0,
    //         token.transfer.selector,
    //         arguments,
    //         5,
    //         uint32(block.timestamp),
    //         uint32(block.timestamp + 100000)
    //     );
    //     Call memory call = Call({
    //         to: bob,
    //         value: 0,
    //         data: abi.encodeWithSelector(token.transfer.selector, address(this), 1.5 ether)
    //     });

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);
    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));

    //     assertTrue(permissions.checkPermission(account, sig, permit, call));
    // }

    // function testBoolPermissions(bool value, bool bound) public {
    //     PermitValidatorTester tester = new PermitValidatorTester();

    //     address[] memory targets = getTargets(0, alice);

    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](1);
    //     arguments[0] = PermitValidator.Param({
    //         _type: PermitValidator.TYPE.BOOL,
    //         offset: 4,
    //         rules: abi.encode(bound),
    //         length: 0
    //     });
    //     PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
    //     spans[0] = PermitValidator.Span({
    //         validAfter: uint32(block.timestamp),
    //         validUntil: uint32(block.timestamp + 100000)
    //     });
    //     PermitValidator.Permit memory permit =
    //         createPermit(targets, 0, tester.dataBool.selector, arguments, spans);
    //     PermitValidator.Call memory call = PermitValidator.Call({
    //         target: alice,
    //         value: 0,
    //         data: abi.encodeCall(tester.dataBool, (value))
    //     });

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);
    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));

    //     assertEq(permissions.checkPermission(account, sig, permit, call), value == bound);
    // }

    // function testAddressPermission(address value, address[] memory bounds) public {
    //     vm.assume(bounds.length != 0);
    //     vm.assume(bounds.length <= type(uint8).max);
    //     require(bounds.length != 0);
    //     require(bounds.length <= type(uint8).max);

    //     LibSort.sort(bounds);
    //     (bool assertion, uint256 index) = LibSort.searchSorted(bounds, value);
    //     console.log("found", assertion);
    //     console.log("index", index);
    //     console.log("found value", bounds[index]);

    //     PermitValidatorTester tester = new PermitValidatorTester();
    //     address[] memory targets = getTargets(0, alice);
    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](1);
    //     arguments[0] = PermitValidator.Param({
    //         _type: PermitValidator.TYPE.ADDRESS,
    //         offset: 4,
    //         rules: abi.encode(bounds),
    //         length: 0
    //     });

    //     PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
    //     spans[0] = PermitValidator.Span({
    //         validAfter: uint32(block.timestamp),
    //         validUntil: uint32(block.timestamp + 100000)
    //     });
    //     PermitValidator.Permit memory permit =
    //         createPermit(targets, 0, tester.dataAddress.selector, arguments, spans);

    //     PermitValidator.Call memory call = PermitValidator.Call({
    //         target: alice,
    //         value: 0,
    //         data: abi.encodeCall(tester.dataAddress, (value))
    //     });

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);

    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));
    //     console.log("length", bounds.length);
    //     assertEq(permissions.checkPermission(address(account), sig, permit, call), assertion);
    // }

    // function testIntPermission(int256 a, int256 min, int256 max) public {
    //     // prevent overflows;
    //     a = bound(a, type(int256).min, type(int256).max);
    //     min = bound(min, type(int256).min, type(int256).max);
    //     max = bound(max, type(int256).min, type(int256).max);

    //     vm.assume(min < max);
    //     vm.assume(a <= type(int256).max && a >= type(int256).min);
    //     vm.assume(min <= type(int256).max && min >= type(int256).min);
    //     vm.assume(max <= type(int256).max && max >= type(int256).min);
    //     require(min <= max);

    //     bool assertion = !(a > max || a < min);

    //     PermitValidatorTester tester = new PermitValidatorTester();

    //     address[] memory targets = new address[](1);
    //     targets[0] = address(tester);

    //     PermitValidator.Param[] memory arguments = new PermitValidator.Param[](1);
    //     arguments[0] = PermitValidator.Param({
    //         _type: PermitValidator.TYPE.INT,
    //         offset: 4,
    //         rules: abi.encode(min, max),
    //         length: 0
    //     });

    //     PermitValidator.Span[] memory spans = new PermitValidator.Span[](1);
    //     spans[0] = PermitValidator.Span({
    //         validAfter: uint32(block.timestamp),
    //         validUntil: uint32(block.timestamp + 100000)
    //     });
    //     PermitValidator.Permit memory permit =
    //         createPermit(targets, 0, tester.dataInt.selector, arguments, spans);

    //     PermitValidator.Call memory call = PermitValidator.Call({
    //         target: address(tester),
    //         value: 0,
    //         data: abi.encodeCall(tester.dataInt, (a))
    //     });

    //     bytes32 permitHash = permissions.getPermitHash(account, permit);
    //     bytes memory sig = sign(aliceKey, SignatureCheckerLib.toEthSignedMessageHash(permitHash));

    //     assert(permissions.validatePermit(account, sig, permit, call) == assertion);
    // }

    function createPermit(
        address[] memory targets,
        uint192 allowance,
        uint32 timesUsed,
        bytes4 selector,
        string memory intent,
        PermitValidator.Span[] memory spans,
        PermitValidator.Arg[] memory args
    ) public pure returns (PermitValidator.Permit memory permit) {
        return PermitValidator.Permit({
            targets: targets,
            allowance: allowance,
            timesUsed: timesUsed,
            selector: selector,
            intent: intent,
            spans: spans,
            args: args
        });
    }

    function getTargets(uint8 length, address include)
        internal
        returns (address[] memory targets)
    {
        bool toInclude = include != address(0);
        targets = new address[](toInclude ? length + 1 : length);

        if (length != 0) {
            for (uint8 i = 0; i < length - 1; i++) {
                targets[i] = _randomAddress();
            }
        }

        if (toInclude) {
            targets[length] = include;
        }
    }

    function _sign(uint256 pK, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pK, hash);
        return abi.encodePacked(r, s, v);
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        return SignatureCheckerLib.toEthSignedMessageHash(hash);
    }
}
