// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple thresholded-ownership validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/MultisigValidator.sol)
/// @custom:version 0.0.0
contract MultisigValidator {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev Authorizers or threshold are invalid for a setting.
    error InvalidSetting();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new authorizers' threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the new authorizers for an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// ========================== STRUCTS ========================== ///

    /// @dev A basic multisignature struct.
    struct Signature {
        address authorizer;
        bytes signature;
    }

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

    /// @dev Stores mappings of thresholds to accounts.
    mapping(address => uint256) internal _thresholds;

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with additional auth logic flow among signers.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        bool success;
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
            validationData := iszero(success)
        }
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

    /// =================== AUTHORIZER OPERATIONS =================== ///

    /// @dev Sets the new authorizers' threshold for an account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _authorizers[msg.sender].length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
    }

    /// @dev Sets the new authorizers for an account.
    function setAuthorizers(address[] memory authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_thresholds[msg.sender] > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the validation threshold and authorizers for an account.
    function install(uint256 threshold, address[] calldata authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (threshold > authorizers.length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = threshold));
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Uninstalls the validation threshold and authorizers for an account.
    function uninstall() public payable virtual {
        emit ThresholdSet(msg.sender, (_thresholds[msg.sender] = 0));
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
