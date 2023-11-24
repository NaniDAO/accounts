// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {RecoveryValidator} from "../../src/validators/RecoveryValidator.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

interface IEntryPoint {
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    function getUserOpHash(NaniAccount.UserOperation calldata userOp)
        external
        view
        returns (bytes32);

    function handleOps(NaniAccount.UserOperation[] calldata ops, address payable beneficiary)
        external;
}

contract RecoveryValidatorTest is Test {
    address internal constant _ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    address internal erc4337;
    NaniAccount internal account;
    RecoveryValidator internal socialRecoveryValidator;

    address internal guardian1;
    uint256 internal guardian1key;
    address internal guardian2;
    uint256 internal guardian2key;
    address internal guardian3;
    uint256 internal guardian3key;

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

    function setUp() public {
        // Etch something onto `_ENTRY_POINT` such that we can deploy the account implementation.
        vm.etch(_ENTRY_POINT, hex"00");
        erc4337 = address(new NaniAccount());
        account = NaniAccount(payable(LibClone.deployERC1967(erc4337)));
        socialRecoveryValidator = new RecoveryValidator();

        (guardian1, guardian1key) = makeAddrAndKey("guardian1");
        (guardian2, guardian2key) = makeAddrAndKey("guardian2");
        (guardian3, guardian3key) = makeAddrAndKey("guardian3");
    }

    function testDeploy() public {
        new RecoveryValidator();
    }

    function testInstall() public {
        vm.deal(address(account), 1 ether);
        account.initialize(address(this));

        address _guardian1 = guardian1;
        address _guardian2 = guardian2;
        address _guardian3 = guardian3;

        address[] memory guardians = new address[](3);
        guardians[0] = _guardian1;
        guardians[1] = _guardian2;
        guardians[2] = _guardian3;

        account.execute(
            address(socialRecoveryValidator),
            0 ether,
            abi.encodeWithSelector(RecoveryValidator.install.selector, 0, 3, guardians)
        );

        guardians = socialRecoveryValidator.getAuthorizers(address(account));
        address guardianOne = guardians[0];
        address guardianTwo = guardians[1];
        address guardianThree = guardians[2];
        assertEq(guardianOne, _guardian1);
        assertEq(guardianTwo, _guardian2);
        assertEq(guardianThree, _guardian3);
    }

    function testUninstall() public {
        vm.deal(address(account), 1 ether);
        account.initialize(address(this));

        address _guardian1 = guardian1;
        address _guardian2 = guardian2;
        address _guardian3 = guardian3;

        address[] memory guardians = new address[](3);
        guardians[0] = _guardian1;
        guardians[1] = _guardian2;
        guardians[2] = _guardian3;

        account.execute(
            address(socialRecoveryValidator),
            0 ether,
            abi.encodeWithSelector(socialRecoveryValidator.install.selector, 0, 3, guardians)
        );

        guardians = socialRecoveryValidator.getAuthorizers(address(account));
        address guardianOne = guardians[0];
        address guardianTwo = guardians[1];
        address guardianThree = guardians[2];
        assertEq(guardianOne, _guardian1);
        assertEq(guardianTwo, _guardian2);
        assertEq(guardianThree, _guardian3);

        account.execute(
            address(socialRecoveryValidator),
            0 ether,
            abi.encodeWithSelector(socialRecoveryValidator.uninstall.selector)
        );

        guardians = socialRecoveryValidator.getAuthorizers(address(account));
        assertEq(guardians, new address[](0));
    }

    function testSetGuardians() public {
        vm.startPrank(guardian1);
        vm.deal(address(account), 1 ether);

        address _guardian1 = guardian1;
        address _guardian2 = guardian2;
        address _guardian3 = guardian3;

        address[] memory guardians = new address[](3);
        guardians[0] = _guardian1;
        guardians[1] = _guardian2;
        guardians[2] = _guardian3;

        account.initialize(_guardian1);

        account.execute(
            address(socialRecoveryValidator),
            0 ether,
            abi.encodeWithSelector(socialRecoveryValidator.install.selector, 0, 3, guardians)
        );
        guardians = socialRecoveryValidator.getAuthorizers(address(account));
        address guardianOne = guardians[0];
        address guardianTwo = guardians[1];
        address guardianThree = guardians[2];
        assertEq(guardianOne, _guardian1);
        assertEq(guardianTwo, _guardian2);
        assertEq(guardianThree, _guardian3);
    }

    function testSocialRecovery() public {
        uint192 key = type(uint192).max;
        address _guardian1 = guardian1;
        address _guardian2 = guardian2;
        address _guardian3 = guardian3;

        address[] memory guardians = new address[](2);
        guardians[0] = _guardian2;
        guardians[1] = _guardian3;

        account.initialize(_guardian1);

        NaniAccount.Call[] memory calls = new NaniAccount.Call[](2);
        calls[0].target = address(socialRecoveryValidator);
        calls[0].value = 0 ether;
        calls[0].data =
            abi.encodeWithSelector(socialRecoveryValidator.install.selector, 2 days, 2, guardians);

        calls[1].target = address(account);
        calls[1].value = 0 ether;
        calls[1].data = abi.encodeWithSelector(
            account.storageStore.selector,
            bytes32(abi.encodePacked(key)),
            bytes32(abi.encodePacked(address(socialRecoveryValidator)))
        );
        vm.startPrank(_guardian1);
        account.executeBatch(calls);

        bytes memory stored = account.execute(
            address(account),
            0 ether,
            abi.encodeWithSelector(account.storageLoad.selector, bytes32(abi.encodePacked(key)))
        );
        assertEq(bytes20(bytes32(stored)), bytes20(address(socialRecoveryValidator)));

        NaniAccount.UserOperation memory userOp;
        userOp.sender = address(account);
        userOp.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(this),
            0 ether,
            abi.encodeWithSelector(account.transferOwnership.selector, _guardian2)
        );

        userOp.nonce = 0 | (uint256(key) << 64);
        bytes32 userOpHash = hex"00";
        userOp.signature = abi.encodePacked(
            _sign(guardian2key, _toEthSignedMessageHash(userOpHash)),
            _sign(guardian3key, _toEthSignedMessageHash(userOpHash))
        );

        vm.startPrank(_guardian2);
        socialRecoveryValidator.requestOwnershipHandover(address(account));

        // 3 days later with no owner cancellation...
        vm.warp(3 days);
        vm.startPrank(_ENTRY_POINT);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        if (validationData == 0) {
            console.log("validationData is 0");
            vm.startPrank(_ENTRY_POINT);
            account.execute(
                address(account),
                0 ether,
                abi.encodeWithSelector(account.transferOwnership.selector, _guardian2)
            );
        }
        assertEq(account.owner(), _guardian2);
    }

    function testFailSocialRecovery() public {
        uint192 key = type(uint192).max;
        address _guardian2 = guardian2;

        address[] memory guardians = new address[](2);
        guardians[0] = _guardian2;
        guardians[1] = guardian3;

        account.initialize(guardian1);

        NaniAccount.Call[] memory calls = new NaniAccount.Call[](2);
        calls[0].target = address(socialRecoveryValidator);
        calls[0].value = 0 ether;
        calls[0].data =
            abi.encodeWithSelector(socialRecoveryValidator.install.selector, 2 days, 2, guardians);

        calls[1].target = address(account);
        calls[1].value = 0 ether;
        calls[1].data = abi.encodeWithSelector(
            account.storageStore.selector,
            bytes32(abi.encodePacked(key)),
            bytes32(abi.encodePacked(address(socialRecoveryValidator)))
        );

        vm.startPrank(guardian1);
        account.executeBatch(calls);
        bytes memory stored = account.execute(
            address(account),
            0 ether,
            abi.encodeWithSelector(account.storageLoad.selector, bytes32(abi.encodePacked(key)))
        );
        assertEq(bytes20(bytes32(stored)), bytes20(address(socialRecoveryValidator)));

        NaniAccount.UserOperation memory userOp;
        userOp.sender = address(account);
        userOp.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(this),
            0 ether,
            abi.encodeWithSelector(account.transferOwnership.selector, _guardian2)
        );

        userOp.nonce = 0 | (uint256(key) << 64);
        bytes32 userOpHash = hex"00";
        userOp.signature =
            abi.encodePacked(_sign(guardian2key, _toEthSignedMessageHash(userOpHash)));

        vm.startPrank(_guardian2);
        socialRecoveryValidator.requestOwnershipHandover(address(account));

        // 3 days later with no owner cancellation...
        vm.warp(3 days);
        vm.startPrank(_ENTRY_POINT);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _installSocialRecoveryValidator(
        address user,
        uint256 threshold,
        address[] memory guardians
    ) internal {
        vm.deal(user, 1 ether);
        account.initialize(user);

        NaniAccount.Call[] memory calls = new NaniAccount.Call[](2);
        calls[0].target = address(socialRecoveryValidator);
        calls[0].value = 0 ether;
        calls[0].data = abi.encodeWithSelector(
            socialRecoveryValidator.install.selector, 0, threshold, guardians
        );

        calls[1].target = address(account);
        calls[1].value = 0 ether;
        calls[1].data = abi.encodeWithSelector(
            account.storageStore.selector,
            bytes32(abi.encodePacked(uint192(123))),
            bytes32(abi.encodePacked(address(socialRecoveryValidator)))
        );

        account.executeBatch(calls);
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        return SignatureCheckerLib.toEthSignedMessageHash(hash);
    }

    function _sign(uint256 pK, bytes32 hash) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pK, hash);
        console.logBytes32(hash);
        console.logBytes(abi.encodePacked(r, s, v));
        return abi.encodePacked(r, s, v);
    }
}
