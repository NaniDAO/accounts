// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple interface to read the owner of a smart account.
interface IOwnable {
    function owner() external view returns (address);
}

/// @notice ERC-1271 validator that authorizes bot EOAs to sign Polymarket CLOB orders
/// on behalf of a smart account, with owner signature fallback.
/// @author nani.eth
/// @custom:version 1.0.0
contract PolymarketValidator {
    /// =========================== EVENTS =========================== ///

    /// @dev Logs updated settings for an account.
    event SettingsSet(
        address indexed account, uint48 validAfter, uint48 validUntil, address[] signers
    );

    /// =========================== ERRORS =========================== ///

    /// @dev Reverts when no signers are provided on install.
    error NoSigners();

    /// ========================== STRUCTS ========================== ///

    /// @dev Configuration for an account's authorized signers and time window.
    struct Settings {
        uint48 validAfter;
        uint48 validUntil;
        address[] signers;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores settings keyed by account address (msg.sender).
    mapping(address => Settings) internal _settings;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC-1271 signature. Checks authorized bot signers within time window,
    /// then falls back to account owner signature.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        Settings storage settings = _settings[msg.sender];
        address[] storage signers = settings.signers;
        uint256 len = signers.length;

        // Check bot signers if configured and within time window.
        if (len != 0) {
            uint256 t = block.timestamp;
            if (t >= settings.validAfter && (settings.validUntil == 0 || t <= settings.validUntil))
            {
                for (uint256 i; i != len;) {
                    if (
                        SignatureCheckerLib.isValidSignatureNowCalldata(
                            signers[i], hash, signature
                        )
                    ) {
                        return bytes4(0x1626ba7e);
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }

        // Fallback: check account owner signature.
        if (
            SignatureCheckerLib.isValidSignatureNowCalldata(
                IOwnable(msg.sender).owner(), hash, signature
            )
        ) {
            return bytes4(0x1626ba7e);
        }

        return bytes4(0xffffffff);
    }

    /// =================== CONFIGURATION OPERATIONS =================== ///

    /// @dev Installs settings for the caller account. Reverts if no signers provided.
    function install(uint48 validAfter, uint48 validUntil, address[] calldata signers)
        external
        payable
    {
        if (signers.length == 0) revert NoSigners();
        _settings[msg.sender] =
            Settings({validAfter: validAfter, validUntil: validUntil, signers: signers});
        emit SettingsSet(msg.sender, validAfter, validUntil, signers);
    }

    /// @dev Uninstalls settings for the caller account.
    function uninstall() external payable {
        delete _settings[msg.sender];
        emit SettingsSet(msg.sender, 0, 0, new address[](0));
    }

    /// @dev Updates settings without reinstalling. Reverts if no signers provided.
    function setSigners(uint48 validAfter, uint48 validUntil, address[] calldata signers)
        external
        payable
    {
        if (signers.length == 0) revert NoSigners();
        _settings[msg.sender] =
            Settings({validAfter: validAfter, validUntil: validUntil, signers: signers});
        emit SettingsSet(msg.sender, validAfter, validUntil, signers);
    }

    /// ====================== VIEW OPERATIONS ====================== ///

    /// @dev Returns the full settings for an account.
    function getSettings(address account)
        external
        view
        returns (uint48 validAfter, uint48 validUntil, address[] memory signers)
    {
        Settings storage s = _settings[account];
        return (s.validAfter, s.validUntil, s.signers);
    }

    /// @dev Returns the authorized signers for an account.
    function getSigners(address account) external view returns (address[] memory) {
        return _settings[account].signers;
    }
}
