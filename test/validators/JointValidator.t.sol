// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {JointValidator} from "../../src/validators/JointValidator.sol";

interface IEntryPoint {
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    function getUserOpHash(NaniAccount.PackedUserOperation calldata userOp)
        external
        view
        returns (bytes32);

    function handleOps(NaniAccount.PackedUserOperation[] calldata ops, address payable beneficiary)
        external;
}

contract JointValidatorTest is Test {
    address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address internal erc4337;
    NaniAccount internal account;
    JointValidator internal jointValidator;

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
        jointValidator = new JointValidator();

        (guardian1, guardian1key) = makeAddrAndKey("guardian1");
        (guardian2, guardian2key) = makeAddrAndKey("guardian2");
        (guardian3, guardian3key) = makeAddrAndKey("guardian3");
    }

    function testDeploy() public {
        new JointValidator();
    }

    function testInstall() public {
        vm.deal(address(account), 1 ether);
        account.initialize(address(this));
        address[] memory guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;
        account.execute(
            address(jointValidator),
            0 ether,
            abi.encodeWithSelector(JointValidator.install.selector, guardians)
        );
        guardians = jointValidator.get(address(account));
        address guardianOne = guardians[0];
        address guardianTwo = guardians[1];
        address guardianThree = guardians[2];
        assertEq(guardianOne, guardian1);
        assertEq(guardianTwo, guardian2);
        assertEq(guardianThree, guardian3);
    }

    function testJointUserOp() public {
        /*uint192 key = type(uint192).max;
        address[] memory guardians = new address[](2);
        guardians[0] = guardian2;
        guardians[1] = guardian3;

        account.initialize(guardian1);

        NaniAccount.Call[] memory calls = new NaniAccount.Call[](2);
        calls[0].target = address(jointValidator);
        calls[0].value = 0 ether;
        calls[0].data = abi.encodeWithSelector(jointValidator.install.selector, guardians);

        calls[1].target = address(account);
        calls[1].value = 0 ether;
        calls[1].data = abi.encodeWithSelector(
            account.storageStore.selector,
            bytes32(abi.encodePacked(key)),
            bytes32(abi.encodePacked(address(jointValidator)))
        );

        vm.startPrank(guardian1);
        account.executeBatch(calls);

        bytes memory stored = account.execute(
            address(account),
            0 ether,
            abi.encodeWithSelector(account.storageLoad.selector, bytes32(abi.encodePacked(key)))
        );
        assertEq(bytes20(bytes32(stored)), bytes20(address(jointValidator)));

        NaniAccount.PackedUserOperation memory userOp;
        userOp.sender = address(account);
        userOp.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(account),
            0 ether,
            abi.encodeWithSelector(account.transferOwnership.selector, guardian2)
        );
        userOp.nonce = 0 | (uint256(key) << 64);
        bytes32 userOpHash = hex"00";
        userOp.signature = abi.encodePacked(
            _sign(guardian2key, _toEthSignedMessageHash(userOpHash)),
            _sign(guardian3key, _toEthSignedMessageHash(userOpHash))
        );
        vm.startPrank(_ENTRY_POINT);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);

        if (validationData == 0) {
            account.execute(
                address(account),
                0 ether,
                abi.encodeWithSelector(account.transferOwnership.selector, guardian2)
            );
        }
        assertEq(account.owner(), guardian2);*/
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
