// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple social recovery validator for smart accounts.
/// @dev Operationally this validator works as a one-time recovery
/// multisig singleton by allowing accounts to program authorizers
/// and thresholds for such authorizers to validate user operations.
/// @custom:version 1.3.0
contract RecoveryValidator {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Inputs are invalid for a setting.
    error InvalidSetting();

    /// @dev Calldata method is not `transferOwnership()`.
    error InvalidCalldata();

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The recovery deadline is still pending for resolution.
    error DeadlinePending();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new delay for an account to renew custody.
    event DelaySet(address indexed account, uint32 delay);

    /// @dev Logs the new deadline for an account to renew custody.
    event DeadlineSet(address indexed account, uint32 deadline);

    /// @dev Logs the new authorizer threshold for an account.
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

    /// @dev The packed ERC4337 userOp struct.
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData;
        bytes signature;
    }

    /// @dev The authorizer signature struct.
    struct Signature {
        address signer;
        bytes sign;
    }

    /// @dev The validator settings struct.
    struct Settings {
        uint32 delay;
        uint32 deadline;
        uint192 threshold;
        address[] authorizers;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mapping of settings to accounts.
    mapping(address => Settings) internal _settings;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with recovery auth logic flow among authorizers.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        return _validateUserOp(userOpHash, userOp.callData, userOp.signature);
    }

    /// @dev Validates packed ERC4337 userOp with recovery auth logic flow among authorizers.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        return _validateUserOp(userOpHash, userOp.callData, userOp.signature);
    }

    /// @dev Returns validity of recovery operation based on the signature and calldata of userOp.
    function _validateUserOp(bytes32 userOpHash, bytes calldata callData, bytes calldata signature)
        internal
        virtual
        returns (uint256 validationData)
    {
        Settings storage settings = _settings[msg.sender];
        if (settings.deadline != type(uint32).max) revert DeadlinePending();
        Signature[] memory signatures = abi.decode(signature, (Signature[]));
        if (signatures.length < settings.threshold) revert Unauthorized();
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        if (bytes4(callData[132:136]) != ITransferOwnership.transferOwnership.selector) {
            revert InvalidCalldata();
        }
        address signer;
        bool isAuthorizer;
        bool isRecovered;
        address[] memory recovered = new address[](settings.authorizers.length);
        unchecked {
            for (uint256 i; i != settings.authorizers.length;) {
                signer = signatures[i].signer;
                (isAuthorizer,) = LibSort.searchSorted(settings.authorizers, signer);
                if (!isAuthorizer) return 0x01; // Failure code.
                (isRecovered,) = LibSort.searchSorted(recovered, signer);
                if (isRecovered) return 0x01; // Failure code.
                if (SignatureCheckerLib.isValidSignatureNow(signer, hash, signatures[i].sign)) {
                    recovered[i] = signer;
                    ++i;
                } else {
                    return 0x01; // Failure code.
                }
            }
        }
        emit DeadlineSet(msg.sender, settings.deadline = 0);
    }

    /// =================== AUTHORIZER OPERATIONS =================== ///

    /// @dev Returns the account recovery settings.
    function getSettings(address account) public view virtual returns (Settings memory) {
        return _settings[account];
    }

    /// @dev Returns the authorizers for the account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _settings[account].authorizers;
    }

    /// @dev Sets new authorizer validation delay for the caller account.
    function setDelay(uint32 delay) public payable virtual {
        if (delay == 0) revert InvalidSetting();
        emit DelaySet(msg.sender, (_settings[msg.sender].delay = delay));
    }

    /// @dev Sets new authorizer threshold for the caller account.
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
        (bool isAuthorizer,) = LibSort.searchSorted(_settings[account].authorizers, msg.sender);
        if (!isAuthorizer) revert Unauthorized();
        unchecked {
            emit DeadlineSet(
                account,
                (_settings[account].deadline = (uint32(block.timestamp) + _settings[account].delay))
            );
        }
    }

    /// @dev Complete ownership handover request based on authorized deadline completion.
    function completeOwnershipHandoverRequest(address account) public payable virtual {
        uint32 deadline = _settings[account].deadline;
        if (block.timestamp > deadline && deadline != 0) {
            emit DeadlineSet(account, _settings[account].deadline = type(uint32).max);
        } else {
            revert DeadlinePending();
        }
    }

    /// @dev Cancels authorizer handovers for the caller account.
    function cancelOwnershipHandover() public payable virtual {
        emit DeadlineSet(msg.sender, _settings[msg.sender].deadline = 0);
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the recovery validator settings for the caller account.
    function install(uint32 delay, uint192 threshold, address[] memory authorizers)
        public
        payable
        virtual
    {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (delay == 0) revert InvalidSetting();
        if (authorizers.length < threshold) revert InvalidSetting();
        emit DelaySet(msg.sender, (_settings[msg.sender].delay = delay));
        emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = threshold));
        emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = authorizers));
    }

    /// @dev Uninstalls the recovery validator settings for the caller account.
    function uninstall() public payable virtual {
        delete _settings[msg.sender];
        emit DelaySet(msg.sender, 0);
        emit DeadlineSet(msg.sender, 0);
        emit ThresholdSet(msg.sender, 0);
        emit AuthorizersSet(msg.sender, new address[](0));
    }
}

/// @dev Simple ownership transfer interface.
interface ITransferOwnership {
    function transferOwnership(address) external payable;
}
