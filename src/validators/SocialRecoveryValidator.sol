// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

contract SocialRecoveryValidator {
    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev Guardians or threshold are invalid for a setting.
    error InvalidSetting();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC4337 user operation (userOp) struct.
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event GuardiansSet(address indexed account, address[] guardians);

    event ThresholdSet(address indexed account, uint256 threshold);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         STORAGE                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    mapping(address => address[]) internal guardians;

    mapping(address => uint256) public thresholds;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   VALIDATION OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Validates ERC4337 userOp with additional auth logic flow among guardians.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        address account = userOp.sender;
        uint256 threshold = thresholds[account];
        address[] memory guards = guardians[account];
        bytes[] memory sigs = _splitSigs(userOp.signature);
        if (msg.sender != account) revert Unauthorized();
        if (sigs.length < threshold) revert Unauthorized();
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < threshold;) {
            unchecked {
                for (uint256 j; j < guards.length;) {
                    if (SignatureCheckerLib.isValidSignatureNow(guards[j], hash, sigs[i])) {
                        ++i;
                        break;
                    } else {
                        if (j == guards.length - 1) return 0x01;
                        ++j;
                    }
                }
            }
        }
        uninstall();
    }

    function _splitSigs(bytes calldata sig) internal view virtual returns (bytes[] memory sigs) {
        unchecked {
            if (sig.length % 65 != 0) revert InvalidSetting();
            sigs = new bytes[](sig.length / 65);
            uint256 pos;
            for (uint256 i; i < sigs.length;) {
                sigs[i] = sig[pos:pos + 65];
                pos += 65;
                ++i;
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     GUARDIAN OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getGuardians(address account) public view virtual returns (address[] memory) {
        return guardians[account];
    }

    function setGuardians(address[] calldata newGuardians) public payable virtual {
        LibSort.sort(newGuardians);
        if (thresholds[msg.sender] > newGuardians.length) revert InvalidSetting();
        emit GuardiansSet(msg.sender, guardians[msg.sender] = newGuardians);
    }

    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > guardians[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, thresholds[msg.sender] = threshold);
    }

    function install(address[] calldata newGuardians, uint256 threshold) public payable virtual {
        setGuardians(newGuardians);
        setThreshold(threshold);
    }

    function uninstall() public payable virtual {
        delete guardians[msg.sender];
        delete thresholds[msg.sender];
        emit GuardiansSet(msg.sender, new address[](0));
        emit ThresholdSet(msg.sender, 0);
    }
}
