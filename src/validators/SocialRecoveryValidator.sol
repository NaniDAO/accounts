// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple social recovery validator for smart accounts.
/// @dev Operationally this validator works as one-time recovery
/// multisig singleton by allowing accounts to set trusted users
/// and threshold for these guardians to execute a 4337 operation.
contract SocialRecoveryValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev Guardians or threshold are invalid for a setting.
    error InvalidSetting();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the guardians for an account.
    event GuardiansSet(address indexed account, address[] guardians);

    /// @dev Logs the guardians' threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

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
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Storage mapping of guardians to an account.
    mapping(address => address[]) internal guardians;

    /// @dev Storage mapping of thresholds to an account.
    mapping(address => uint256) public thresholds;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

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
        bytes[] memory sigs = _splitSignature(userOp.signature);
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);

        if (msg.sender != account) revert Unauthorized();
        if (sigs.length < threshold) revert Unauthorized();

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

    /// @dev Returns bytes array from split signature.
    function _splitSignature(bytes calldata signature)
        internal
        view
        virtual
        returns (bytes[] memory sigs)
    {
        unchecked {
            if (signature.length % 65 != 0) revert InvalidSetting();
            sigs = new bytes[](signature.length / 65);
            uint256 pos;
            for (uint256 i; i < sigs.length;) {
                sigs[i] = signature[pos:pos += 65];
                ++i;
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GUARDIAN OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the guardians for an account.
    function getGuardians(address account) public view virtual returns (address[] memory) {
        return guardians[account];
    }

    /// @dev Sets the guardians for an account.
    function setGuardians(address[] calldata newGuardians) public payable virtual {
        LibSort.sort(newGuardians);
        if (thresholds[msg.sender] > newGuardians.length) revert InvalidSetting();
        emit GuardiansSet(msg.sender, guardians[msg.sender] = newGuardians);
    }

    /// @dev Sets the guardians' threshold for an account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > guardians[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, thresholds[msg.sender] = threshold);
    }

    /// @dev Installs new guardians and threshold for an account.
    function install(address[] calldata newGuardians, uint256 threshold) public payable virtual {
        setGuardians(newGuardians);
        setThreshold(threshold);
    }

    /// @dev Uninstalls new guardians and threshold for an account.
    function uninstall() public payable virtual {
        delete guardians[msg.sender];
        delete thresholds[msg.sender];
        emit GuardiansSet(msg.sender, new address[](0));
        emit ThresholdSet(msg.sender, 0);
    }
}
