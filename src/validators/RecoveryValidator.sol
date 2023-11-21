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

    /// @dev Authorizers or threshold are invalid for a setting.
    error InvalidSetting();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new deadline for an account to renew custody.
    event DeadlineSet(address indexed account, uint256 deadline);

    /// @dev Logs the new authorizers' threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the new calldata hash for an account.
    event CalldataHashSet(address indexed account, bytes32 calldataHash);

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

    /// @dev Stores mappings of deadlines to accounts.
    mapping(address => uint256) internal _deadlines;

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) internal _thresholds;

    /// @dev Stores mappings of calldata hashes to accounts.
    mapping(address => bytes32) internal _calldataHashes;

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
        bool validAfter = block.timestamp > deadline;
        uint256 threshold = _thresholds[msg.sender];
        address[] memory authorizers = _authorizers[msg.sender];
        bytes[] memory signatures = _splitSignature(userOp.signature);
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        if (signatures.length < threshold) revert InvalidSetting();
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
        // If `calldataHash` is stored for the caller,
        // ensure only countersigned userOp executes.
        if (_calldataHashes[msg.sender] != bytes32(0)) {
            assert(keccak256(userOp.callData) == _calldataHashes[msg.sender]);
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

    /// @dev Returns the validation deadline for an account,
    /// threshold, calldata hash, as well as the authorizers.
    function getSettings(address account)
        public
        view
        virtual
        returns (
            uint256 deadline,
            uint256 threshold,
            bytes32 calldataHash,
            address[] memory authorizers
        )
    {
        return (
            _deadlines[account],
            _thresholds[account],
            _calldataHashes[account],
            _authorizers[account]
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

    /// @dev Sets the new calldata hash for an account.
    function setCalldataHash(bytes32 calldataHash) public payable virtual {
        emit CalldataHashSet(msg.sender, (_calldataHashes[msg.sender] = calldataHash));
    }

    /// @dev Sets the new authorizers for an account.
    function setAuthorizers(address[] memory authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_thresholds[msg.sender] > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the validation deadline for an account,
    /// threshold, calldata hash, as well as the authorizers.
    function install(
        uint256 deadline,
        uint256 threshold,
        bytes32 calldataHash,
        address[] memory authorizers
    ) public payable virtual {
        if (deadline != 0) emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = deadline));
        if (authorizers.length >= threshold) {
            emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
        }
        if (calldataHash != bytes32(0)) {
            emit CalldataHashSet(msg.sender, (_calldataHashes[msg.sender] = calldataHash));
        }
        if (authorizers.length != 0) {
            LibSort.sort(authorizers);
            LibSort.uniquifySorted(authorizers);
            emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
        }
    }

    /// @dev Uninstalls the validation deadline for an account,
    /// threshold, calldata hash, as well as the authorizers.
    function uninstall() public payable virtual {
        emit DeadlineSet(msg.sender, (_deadlines[msg.sender] = 0));
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = 0));
        emit CalldataHashSet(msg.sender, (_calldataHashes[msg.sender] = bytes32(0)));
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
