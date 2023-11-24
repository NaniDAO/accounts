// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple social recovery validator for smart accounts.
/// @dev Operationally this validator works as a one-time recovery
/// multisig singleton by allowing accounts to program authorizers
/// and thresholds for such authorizers to validate user operations.
contract RecoveryValidator {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Inputs are invalid for a setting.
    error InvalidSetting();

    /// @dev Calldata method is invalid for an execution.
    error InvalidExecute();

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new delay for an account to renew custody.
    event DelaySet(address indexed account, uint32 delay);

    /// @dev Logs the new deadline for an account to renew custody.
    event DeadlineSet(address indexed account, uint32 deadline);

    /// @dev Logs the new authorizers' threshold for an account.
    event ThresholdSet(address indexed account, uint192 threshold);

    /// @dev Logs the new authorizers for an account (i.e., 'multisig').
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// ========================== STRUCTS ========================== ///

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

    /// @dev The validator settings struct.
    struct Settings {
        uint32 delay;
        uint32 deadline;
        uint192 threshold;
        address[] authorizers;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of settings to accounts.
    mapping(address => Settings) internal _settings;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
    /// This must be used to execute `transferOwnership` to backup decided by threshold.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        bool success;
        Settings storage settings = _settings[msg.sender];
        if (settings.deadline == 0) revert Unauthorized();
        bool validAfter = block.timestamp > settings.deadline;
        if (bytes4(userOp.callData[132:136]) != 0xf2fde38b) revert();
        bytes[] memory signatures = _splitSignature(userOp.signature);
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < settings.threshold;) {
            unchecked {
                for (uint256 j; j < settings.authorizers.length;) {
                    if (
                        SignatureCheckerLib.isValidSignatureNow(
                            settings.authorizers[j], hash, signatures[i]
                        )
                    ) {
                        ++i;
                        break;
                    } else {
                        if (j == (settings.authorizers.length - 1)) return 0x01; // Return digit on failure.
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
        uninstall(); // Uninstall the recovery settings.
    }

    /// @dev Returns bytes array from split signature.
    function _splitSignature(bytes calldata signature)
        internal
        view
        virtual
        returns (bytes[] memory signatures)
    {
        unchecked {
            if (signature.length % 65 != 0) revert InvalidSetting();
            signatures = new bytes[](signature.length / 65);
            uint256 pos;
            for (uint256 i; i < signatures.length;) {
                signatures[i] = signature[pos:pos += 65];
                ++i;
            }
        }
    }

    /// =================== AUTHORIZER OPERATIONS =================== ///

    /// @dev Returns the account settings.
    function getSettings(address account) public view virtual returns (Settings memory) {
        return _settings[account];
    }

    /// @dev Returns the authorizers for the account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _settings[account].authorizers;
    }

    /// @dev Sets new authorizer validation delay for the caller account.
    function setDelay(uint32 delay) public payable virtual {
        emit DelaySet(msg.sender, (_settings[msg.sender].delay = delay));
    }

    /// @dev Sets new authorizers' threshold for the caller account.
    function setThreshold(uint192 threshold) public payable virtual {
        if (threshold > _settings[msg.sender].authorizers.length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = threshold));
    }

    /// @dev Sets new authorizers for the caller account.
    function setAuthorizers(address[] memory authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_settings[msg.sender].threshold > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = authorizers));
    }

    /// @dev Initiates an authorizer handover for the account.
    /// This function can only be called by an authorizer and
    /// sets a new deadline for the account to cancel request.
    function requestOwnershipHandover(address account) public payable virtual {
        address[] memory authorizers = _settings[account].authorizers;
        bool isAuthorizer;
        for (uint256 i; i < authorizers.length;) {
            if (msg.sender == authorizers[i]) {
                isAuthorizer = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
        if (!isAuthorizer) revert Unauthorized();
        emit DeadlineSet(
            account,
            (_settings[account].deadline = uint32(block.timestamp) + _settings[account].delay)
        );
    }

    /// @dev Cancels authorizer handovers for the caller account.
    function cancelOwnershipHandover() public payable virtual {
        emit DeadlineSet(msg.sender, _settings[msg.sender].deadline = 0);
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the validator settings for the caller account.
    function install(uint32 delay, uint192 threshold, address[] memory authorizers)
        public
        payable
        virtual
    {
        if (delay != 0) emit DelaySet(msg.sender, (_settings[msg.sender].delay = delay));
        if (authorizers.length >= threshold) {
            emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = threshold));
        }
        if (authorizers.length != 0) {
            LibSort.sort(authorizers);
            LibSort.uniquifySorted(authorizers);
            emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = authorizers));
        }
    }

    /// @dev Uninstalls the validator settings for the registered caller account.
    function uninstall() public payable virtual {
        emit DelaySet(msg.sender, (_settings[msg.sender].delay = 0));
        emit DeadlineSet(msg.sender, (_settings[msg.sender].deadline = 0));
        emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = 0));
        emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = new address[](0)));
    }
}
