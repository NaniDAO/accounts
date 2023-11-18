// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple social recovery validator for smart accounts.
/// @dev Operationally this validator works as a one-time recovery
/// multisig singleton by allowing accounts to program authorizers
/// and thresholds for such authorizers to validate user operations.
contract RecoveryValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Authorizers or threshold are invalid for a setting.
    error InvalidSetting();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new deadline for an account.
    event DeadlineSet(address indexed account, uint256 deadline);

    /// @dev Logs the new authorizers' threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the new userOp hash for an account.
    event UserOpHashSet(address indexed account, bytes32 userOpHash);

    /// @dev Logs the new authorizers for an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

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

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) internal _thresholds;

    /// @dev Stores mappings of userOp hashes to accounts.
    mapping(address => bytes32) internal _userOpHashes;

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   VALIDATION OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
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
        bytes[] memory sigs = _splitSignature(userOp.signature);
        address[] memory authorizers = _authorizers[userOp.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        if (sigs.length < threshold) revert InvalidSetting();
        for (uint256 i; i < threshold;) {
            unchecked {
                for (uint256 j; j < authorizers.length;) {
                    if (SignatureCheckerLib.isValidSignatureNow(authorizers[j], hash, sigs[i])) {
                        ++i;
                        break;
                    } else {
                        if (j == (authorizers.length - 1)) return 0x01; // Return digit on failure.
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
        // If authorizers validated the userOp and `userOpHash` is stored
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
    /*                    AUTHORIZER OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the validation deadline for an account,
    /// threshold, userOp hash, as well as the authorizers.
    function getSettings(address account)
        public
        view
        virtual
        returns (
            uint256 deadline,
            uint256 threshold,
            bytes32 userOpHash,
            address[] memory authorizers
        )
    {
        return (
            _deadlines[account], _thresholds[account], _userOpHashes[account], _authorizers[account]
        );
    }

    /// @dev Sets the new authorizer validation deadline for an account.
    function setDeadline(uint256 deadline) public payable virtual {
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = deadline));
    }

    /// @dev Sets the new authorizers' threshold for an account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _authorizers[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
    }

    /// @dev Sets the new userOp hash for an account.
    function setUserOpHash(bytes32 userOpHash) public payable virtual {
        emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = userOpHash));
    }

    /// @dev Sets the new authorizers for an account.
    function setAuthorizers(address[] memory authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_thresholds[msg.sender] > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   AUTHORIZER INSTALLATION                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Installs the validation deadline for an account,
    /// threshold, userOp hash, as well as the authorizers.
    function install(
        uint256 deadline,
        uint256 threshold,
        bytes32 userOpHash,
        address[] memory authorizers
    ) public payable virtual {
        if (deadline != 0) emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = deadline));
        if (authorizers.length >= threshold) {
            emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
        }
        if (userOpHash != bytes32(0)) {
            emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = userOpHash));
        }
        if (authorizers.length != 0) {
            LibSort.sort(authorizers);
            LibSort.uniquifySorted(authorizers);
            emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
        }
    }

    /// @dev Uninstalls the validation deadline for an account,
    /// threshold, userOp hash, as well as the authorizers.
    function uninstall() public payable virtual {
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = 0));
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = 0));
        emit UserOpHashSet(msg.sender, (_userOpHashes[msg.sender] = bytes32(0)));
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
