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
    event DelaySet(address indexed account, uint256 deadline);

    /// @dev Logs the new deadline for an account to renew custody.
    event DeadlineSet(address indexed account, uint256 deadline);

    /// @dev Logs the new authorizers' threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the new authorizers for an account.
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

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of delays to accounts.
    mapping(address => uint256) internal _delays;

    /// @dev Stores mappings of deadlines to accounts.
    mapping(address => uint256) internal _deadlines;

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) internal _thresholds;

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
    /// Generally, this should be used to execute `transferOwnership` to backup owners.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        bool success;
        uint256 deadline = _deadlines[msg.sender];
        if (deadline == 0) revert Unauthorized();
        bool validAfter = block.timestamp > deadline;
        uint256 threshold = _thresholds[msg.sender];
        address[] memory authorizers = _authorizers[msg.sender];
        bytes[] memory signatures = _splitSignature(userOp.signature);
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        //if (bytes4(userOp.callData[:]) != bytes4(keccak256("transferOwnership(address)"))) {
        //    revert InvalidExecute();
        //}
        for (uint256 i; i < threshold;) {
            unchecked {
                for (uint256 j; j < authorizers.length;) {
                    if (
                        SignatureCheckerLib.isValidSignatureNow(authorizers[j], hash, signatures[i])
                    ) {
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

    /// @dev Returns the validation time status,
    /// threshold, as well as the authorizers
    /// of the registered account.
    function getSettings(address account)
        public
        view
        virtual
        returns (uint256 delay, uint256 deadline, uint256 threshold, address[] memory authorizers)
    {
        return (_delays[account], _deadlines[account], _thresholds[account], _authorizers[account]);
    }

    /// @dev Sets new authorizer validation delay for the caller account.
    function setDelay(uint256 delay) public payable virtual {
        emit DelaySet(msg.sender, (_delays[msg.sender] = delay));
    }

    /// @dev Sets new authorizers' threshold for the caller account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _authorizers[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
    }

    /// @dev Sets new authorizers for the caller account.
    function setAuthorizers(address[] memory authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_thresholds[msg.sender] > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Initiates an authorizer handover for the account.
    /// This function can only be called by an authorizer and
    /// sets a new deadline for the account to cancel request.
    function requestOwnershipHandover(address account) public payable virtual {
        address[] memory authorizers = _authorizers[account];
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
        emit DeadlineSet(account, _deadlines[account] = block.timestamp + _delays[account]);
    }

    /// @dev Cancels authorizer handovers for the caller account.
    function cancelOwnershipHandover() public payable virtual {
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = 0);
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the validator settings for the caller account.
    function install(uint256 delay, uint256 threshold, address[] memory authorizers)
        public
        payable
        virtual
    {
        if (delay != 0) emit DelaySet(msg.sender, (_delays[msg.sender] = delay));
        if (authorizers.length >= threshold) {
            emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
        }
        if (authorizers.length != 0) {
            LibSort.sort(authorizers);
            LibSort.uniquifySorted(authorizers);
            emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
        }
    }

    /// @dev Uninstalls the validator settings for the registered caller account.
    function uninstall() public payable virtual {
        emit DelaySet(msg.sender, (_delays[msg.sender] = 0));
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = 0));
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = 0));
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
