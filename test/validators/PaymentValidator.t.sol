// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {PaymentValidator} from "../../src/validators/PaymentValidator.sol";

import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";

interface IEntryPoint {
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    function getUserOpHash(NaniAccount.PackedUserOperation calldata userOp)
        external
        view
        returns (bytes32);

    function handleOps(NaniAccount.PackedUserOperation[] calldata ops, address payable beneficiary)
        external;
}

contract PaymentValidatorTest is Test {
    address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address internal erc4337;
    NaniAccount internal account;
    PaymentValidator internal validator;

    MockERC20 internal mockERC20;

    address internal owner;
    uint256 internal ownerKey;
    address internal guardian1;
    uint256 internal guardian1key;
    address internal guardian2;
    uint256 internal guardian2key;

    struct _TestTemps {
        bytes32 userOpHash;
        bytes32 hash;
        address signer;
        uint256 privateKey;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 missingAccountFunds;
    }

    struct Plan {
        uint192 allowance;
        uint32 validAfter;
        uint32 validUntil;
        address[] validTo;
    }

    function setUp() public {
        // Etch something onto `_ENTRY_POINT` such that we can deploy the account implementation.
        vm.etch(_ENTRY_POINT, hex"00");
        erc4337 = address(new NaniAccount());
        account = NaniAccount(payable(LibClone.deployERC1967(erc4337)));
        validator = new PaymentValidator();

        mockERC20 = new MockERC20("TEST", "TEST", 18);
        mockERC20.mint(address(account), 1 ether);

        (owner, ownerKey) = makeAddrAndKey("owner");
        (guardian1, guardian1key) = makeAddrAndKey("guardian1");
        (guardian2, guardian2key) = makeAddrAndKey("guardian2");
    }

    function testDeploy() public {
        new PaymentValidator();
    }

    function testInstall() public {
        account.initialize(address(this));
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
    }

    function testETHPaymentPlan() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 1 ether, ""));
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
        assertEq(validity, 0);
    }

    function testFailPaymentPlanInvalidAllowance() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 0;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 0, ""));
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
    }

    function testFailPaymentPlanInvalidAfter() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = uint32(block.timestamp + 1);
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 1 ether, ""));
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
    }

    function testFailPaymentPlanInvalidUntil() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = uint32(block.timestamp - 1);
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 1 ether, ""));
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
    }

    function testETHPaymentPlanFailInvalidSignature() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(ownerKey, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 1 ether, ""));
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
        assertEq(validity, 1); // Error code.
    }

    function testFailETHPaymentPlanInvalidValue() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 userOpHash = _toEthSignedMessageHash(bytes32("ok"));
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian1, 2 ether, ""));
        validator.validateUserOp(userOp, userOpHash, 0);
    }

    function testFailETHInvalidTarget() public {
        vm.deal(address(account), 1 ether);
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = ETH;
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 userOpHash = _toEthSignedMessageHash(bytes32("ok"));
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(IAccount.execute, (guardian2, 2 ether, ""));
        validator.validateUserOp(userOp, userOpHash, 0);
    }

    function testERC20PaymentPlan() public {
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20);
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(
            IAccount.execute,
            (address(mockERC20), 0 ether, abi.encodeCall(IERC20.transfer, (guardian1, 1 ether)))
        );
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
        assertEq(validity, 0);
    }

    function testFailERC20PaymentPlanInvalidSelector() public {
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20);
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(
            IAccount.execute,
            (
                address(mockERC20),
                0 ether,
                abi.encodeCall(IBadCall.notTransfer, (guardian1, 1 ether))
            )
        );
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
    }

    function testERC20PaymentPlanFailInvalidSignature() public {
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20);
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 hash = bytes32("ok");
        bytes32 userOpHash = _toEthSignedMessageHash(hash);
        userOp.sender = address(account);
        userOp.signature = _sign(ownerKey, userOpHash);
        userOp.callData = abi.encodeCall(
            IAccount.execute,
            (address(mockERC20), 0 ether, abi.encodeCall(IERC20.transfer, (guardian1, 1 ether)))
        );
        uint256 validity = validator.validateUserOp(userOp, hash, 0);
        assertEq(validity, 1);
    }

    function testFailERC20PaymentPlanInvalidTarget() public {
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20);
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 userOpHash = _toEthSignedMessageHash(bytes32("ok"));
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(
            IAccount.execute,
            (address(mockERC20), 0 ether, abi.encodeCall(IERC20.transfer, (guardian2, 1 ether)))
        );
        validator.validateUserOp(userOp, userOpHash, 0);
    }

    function testFailERC20PaymentPlanInvalidValue() public {
        account.initialize(owner);
        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20);
        Plan[] memory plans = new Plan[](1);
        address[] memory validTos = new address[](1);
        validTos[0] = guardian1;
        plans[0].allowance = 1 ether;
        plans[0].validAfter = 0;
        plans[0].validUntil = type(uint32).max;
        plans[0].validTo = validTos;
        vm.prank(owner);
        account.execute(
            address(validator),
            0 ether,
            abi.encodeWithSelector(PaymentValidator.install.selector, guardians, assets, plans)
        );
        vm.prank(address(account));
        PaymentValidator.UserOperation memory userOp;
        bytes32 userOpHash = _toEthSignedMessageHash(bytes32("ok"));
        userOp.sender = address(account);
        userOp.signature = _sign(guardian1key, userOpHash);
        userOp.callData = abi.encodeCall(
            IAccount.execute,
            (address(mockERC20), 0 ether, abi.encodeCall(IERC20.transfer, (guardian1, 2 ether)))
        );
        validator.validateUserOp(userOp, userOpHash, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }

    function _sign(uint256 pK, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pK, hash);
        return abi.encodePacked(r, s, v);
    }
}

interface IAccount {
    function execute(address, uint256, bytes calldata) external returns (bytes memory);
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}

interface IBadCall {
    function notTransfer(address, uint256) external returns (bool);
}
