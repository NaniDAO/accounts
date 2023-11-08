// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {JointValidator} from "../../src/validators/JointValidator.sol";

interface IEntryPoint {
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    function getUserOpHash(NaniAccount.UserOperation calldata userOp)
        external
        view
        returns (bytes32);

    function handleOps(NaniAccount.UserOperation[] calldata ops, address payable beneficiary)
        external;
}

contract JointValidatorTest is Test {
    address internal constant _ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

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
        vm.createSelectFork(vm.rpcUrl("main"));
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
        guardians = jointValidator.getGuardians(address(account));
        address guardianOne = guardians[0];
        address guardianTwo = guardians[1];
        address guardianThree = guardians[2];
        assertEq(guardianOne, guardian1);
        assertEq(guardianTwo, guardian2);
        assertEq(guardianThree, guardian3);
    }

    function testJointUserOp() public {
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
    }
}
