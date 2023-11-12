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

    /// @dev Logs the new deadline of an account.
    event DeadlineSet(address indexed account, uint256 deadline);

    /// @dev Logs the new guardians' threshold of an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the new userOp hash of an account.
    event UserOpHashSet(address indexed account, bytes32 userOpHash);

    /// @dev Logs the new guardians of an account.
    event GuardiansSet(address indexed account, address[] guardians);

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

    /// @dev Stores mappings of deadlines to accounts.
    mapping(address => uint256) internal _deadlines;

    /// @dev Stores mappings of guardians to accounts.
    mapping(address => address[]) internal _guardians;

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) internal _thresholds;

    /// @dev Stores mappings of userOp hashes to accounts.
    mapping(address => bytes32) internal _userOpHashes;

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
        bool success;
        uint256 deadline = _deadlines[msg.sender];
        bool validAfter = (block.timestamp > deadline);
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
                success = true;
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            validationData := iszero(and(success, validAfter))
        }
        // If guardians validated the userOp and `userOpHash` is stored
        // for the caller, assert and check this matches the validated.
        // This effectively ensures only countersigned userOp executes.
        if (validationData == 0) {
            if (_userOpHashes[msg.sender] != bytes32(0)) {
                assert(userOpHash == _userOpHashes[msg.sender]);
            }
        }
        uninstall(); // Uninstall the recovery settings.
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

    /// @dev Returns the validation deadline of an account,
    /// threshold, userOp hash, as well as the guardians.
    function getSettings(address account)
        public
        view
        virtual
        returns (
            uint256 deadline,
            uint256 threshold,
            bytes32 userOpHash,
            address[] memory guardians
        )
    {
        return
            (_deadlines[account], _thresholds[account], _userOpHashes[account], _guardians[account]);
    }

    /// @dev Sets the new guardian validation deadline of an account.
    function setDeadline(uint256 deadline) public payable virtual {
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = deadline));
    }

    /// @dev Sets the new guardians' threshold of an account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _guardians[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
    }

    /// @dev Sets the new userOp hash of an account.
    function setUserOpHash(bytes32 userOpHash) public payable virtual {
        emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = userOpHash));
    }

    /// @dev Sets the new guardians of an account.
    function setGuardians(address[] memory guardians) public payable virtual {
        if (_thresholds[msg.sender] > guardians.length) revert InvalidSetting();
        LibSort.sort(guardians);
        LibSort.uniquifySorted(guardians);
        emit GuardiansSet(msg.sender, (_guardians[msg.sender] = guardians));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 GUARDIAN INSTALLATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Installs the validation deadline of an account,
    /// threshold, userOp hash, as well as the guardians.
    function install(
        uint256 deadline,
        uint256 threshold,
        bytes32 userOpHash,
        address[] memory guardians
    ) public payable virtual {
        if (deadline != 0) emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = deadline));
        if (guardians.length >= threshold) {
            emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
        }
        if (userOpHash != bytes32(0)) {
            emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = userOpHash));
        }
        if (guardians.length != 0) {
            LibSort.sort(guardians);
            LibSort.uniquifySorted(guardians);
            emit GuardiansSet(msg.sender, (_guardians[msg.sender] = guardians));
        }
    }

    //// @dev Uninstalls the validation deadline of an account,
    /// threshold, userOp hash, as well as the guardians.
    function uninstall() public payable virtual {
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = 0));
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = 0));
        emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = bytes32(0)));
        emit GuardiansSet(msg.sender, (_guardians[msg.sender] = new address[](0)));
    }
}
