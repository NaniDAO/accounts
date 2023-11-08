// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple social recovery validator for smart accounts.
/// @dev Operationally this validator works as a one-time recovery
/// multisig singleton by allowing accounts to set up trusted users
/// and a threshold for such guardians to execute ERC4337 operations.
contract RecoveryValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Guardians or threshold are invalid for a setting.
    error InvalidSetting();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new guardians of an account.
    event GuardiansSet(address indexed account, address[] guardians);

    /// @dev Logs the new guardians' threshold of an account.
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

    /// @dev Stores mappings of guardians to accounts.
    mapping(address => address[]) internal _guardians;

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) public _thresholds;

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
    /// Generally, this should be used to execute `transferOwnership` to backup owner.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        uint256 threshold = _thresholds[userOp.sender];
        address[] memory guardians = _guardians[userOp.sender];
        bytes[] memory sigs = _splitSignature(userOp.signature);
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        if (sigs.length < threshold) revert InvalidSetting();
        for (uint256 i; i < threshold;) {
            unchecked {
                for (uint256 j; j < guardians.length;) {
                    if (SignatureCheckerLib.isValidSignatureNow(guardians[j], hash, sigs[i])) {
                        ++i;
                        break;
                    } else {
                        if (j == (guardians.length - 1)) return 0x01; // Return digit on failure.
                        ++j;
                    }
                }
            }
        }
        uninstall(); // Uninstall the guardians and threshold of caller if validation succeeded.
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

    /// @dev Returns the guardians of an account.
    function guardiansOf(address account) public view virtual returns (address[] memory) {
        return _guardians[account];
    }

    /// @dev Sets the new guardians of an account.
    function setGuardians(address[] memory guardians) public payable virtual {
        LibSort.sort(guardians);
        if (_thresholds[msg.sender] > guardians.length) revert InvalidSetting();
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = guardians);
    }

    /// @dev Sets the new guardians' threshold of an account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _guardians[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, _thresholds[msg.sender] = threshold);
    }

    /// @dev Installs the new guardians and threshold of an account.
    function install(bytes calldata data) public payable virtual {
        (uint256 threshold, address[] memory guardians) = abi.decode(data, (uint256, address[]));
        setGuardians(guardians);
        setThreshold(threshold);
    }

    /// @dev Uninstalls the guardians and threshold of an account.
    function uninstall() public payable virtual {
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = new address[](0));
        emit ThresholdSet(msg.sender, _thresholds[msg.sender] = 0);
    }
}
