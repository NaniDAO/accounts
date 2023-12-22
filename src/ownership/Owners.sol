// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ownership singleton for smart accounts.
/// @custom:version 0.0.0
contract Owners {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Inputs are invalid for a setting.
    error InvalidSetting();

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new guard status for an account.
    event GuardSet(address indexed account, bool guarded);

    /// @dev Logs the new guard permits for an account.
    event PermitsSet(address indexed account, bytes32[] permits);

    /// @dev Logs the new authorizer threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

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

    /// @dev The authorizer settings struct.
    struct Settings {
        bool guarded;
        uint256 threshold;
        bytes32[] permits;
        address[] authorizers;
    }

    /// @dev The authorizer signing struct.
    struct Authorizer {
        address signer;
        bool matched;
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
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        Settings storage settings = _settings[msg.sender];
        bytes[] memory signatures = _splitSignature(userOp.signature);
        if (signatures.length < settings.threshold) revert Unauthorized();
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        Authorizer[] memory authorizers = new Authorizer[](settings.authorizers.length);
        unchecked {
            if (settings.guarded) {
                bool ok;
                for (uint256 i; i < settings.permits.length;) {
                    if (userOpHash == settings.permits[i]) ok = true;
                }
                if (!ok) return 0x01;
            }
            for (uint256 i; i < authorizers.length;) {
                authorizers[i].signer = settings.authorizers[i];
                ++i;
            }
            for (uint256 i; i < settings.threshold;) {
                for (uint256 j; j < authorizers.length;) {
                    if (
                        !authorizers[j].matched
                            && SignatureCheckerLib.isValidSignatureNow(
                                authorizers[j].signer, hash, signatures[i]
                            )
                    ) {
                        authorizers[j].matched = true;
                        ++i;
                        break;
                    } else {
                        ++j;
                        if (j == authorizers.length) {
                            return 0x01;
                        }
                    }
                }
            }
        }
    }

    /// @dev Validates ERC1271 signature with additional auth logic flow among authorizers.
    /// note: This implementation is designed to be the transferred-to owner of smart accounts.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4)
    {
        Settings storage settings = _settings[msg.sender];
        bytes[] memory signatures = _splitSignature(signature);
        if (signatures.length < settings.threshold) revert Unauthorized();
        Authorizer[] memory authorizers = new Authorizer[](settings.authorizers.length);
        unchecked {
            if (settings.guarded) {
                bool ok;
                for (uint256 i; i < settings.permits.length;) {
                    if (hash == settings.permits[i]) ok = true;
                }
                if (!ok) return 0xffffffff;
            }
            for (uint256 i; i < authorizers.length;) {
                authorizers[i].signer = settings.authorizers[i];
                ++i;
            }
            for (uint256 i; i < settings.threshold;) {
                for (uint256 j; j < authorizers.length;) {
                    if (
                        !authorizers[j].matched
                            && SignatureCheckerLib.isValidSignatureNow(
                                authorizers[j].signer, hash, signatures[i]
                            )
                    ) {
                        authorizers[j].matched = true;
                        ++i;
                        break;
                    } else {
                        ++j;
                        if (j == authorizers.length) {
                            return 0xffffffff;
                        }
                    }
                }
            }
        }
        return this.isValidSignature.selector;
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

    /// @dev Returns the permits for the account.
    function getPermits(address account) public view virtual returns (bytes32[] memory) {
        return _settings[account].permits;
    }

    /// @dev Returns the authorizers for the account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _settings[account].authorizers;
    }

    /// @dev Sets new guard status for the caller account.
    function setGuard(address account, bool guarded) public payable virtual {
        emit GuardSet(account, (_settings[msg.sender].guarded = guarded));
    }

    /// @dev Sets new permits for the caller account.
    function setPermits(bytes32[] calldata permits) public payable virtual {
        emit PermitsSet(msg.sender, (_settings[msg.sender].permits = permits));
    }

    /// @dev Sets new authorizer threshold for the caller account.
    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > _settings[msg.sender].authorizers.length) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = threshold));
    }

    /// @dev Sets new authorizers for the caller account.
    function setAuthorizers(address[] calldata authorizers) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (_settings[msg.sender].threshold > authorizers.length) revert InvalidSetting();
        emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = authorizers));
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the settings for the caller account.
    function install(
        bool guarded,
        uint256 threshold,
        bytes32[] calldata permits,
        address[] calldata authorizers
    ) public payable virtual {
        LibSort.sort(authorizers);
        LibSort.uniquifySorted(authorizers);
        if (authorizers.length < threshold) revert InvalidSetting();
        emit GuardSet(msg.sender, _settings[msg.sender].guarded = guarded);
        emit PermitsSet(msg.sender, (_settings[msg.sender].permits = permits));
        emit ThresholdSet(msg.sender, (_settings[msg.sender].threshold = threshold));
        emit AuthorizersSet(msg.sender, (_settings[msg.sender].authorizers = authorizers));
    }

    /// @dev Uninstalls the validator settings for the caller account.
    function uninstall() public payable virtual {
        delete _settings[msg.sender];
        emit GuardSet(msg.sender, false);
        emit ThresholdSet(msg.sender, 0);
        emit PermitsSet(msg.sender, new bytes32[](0));
        emit AuthorizersSet(msg.sender, new address[](0));
    }
}
