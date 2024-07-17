// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {P256} from "@solady/src/utils/P256.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @dev Simple singleton to store passkey ownership and backups for accounts.
contract Passkeys {
    /// =========================== EVENTS =========================== ///

    /// @dev Logs new onchain backup activity status for an account.
    event BackupSet(address indexed account, address backup, bool active);

    /// @dev Logs new passkey `x` `y` pairing for an account.
    /// note: Revocation is done by setting `y` to nothing.
    event PasskeySet(address indexed account, bytes32 x, bytes32 y);

    /// ========================== STRUCTS ========================== ///

    /// @dev Passkey pair.
    struct Passkey {
        bytes32 x;
        bytes32 y;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mapping of onchain backup address activity statuses to accounts.
    mapping(address account => mapping(address backup => bool active)) public backups;

    /// @dev Stores mapping of passkey `x` `y` pairings to accounts. Null revokes.
    mapping(address account => mapping(bytes32 x => bytes32 y)) public passkeys;

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC1271 signature packed as `r`, `s`, `x`, `y`.
    /// note: Includes fallback to check if first 20 bytes is backup.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4 result)
    {
        bool isValid;
        if (signature.length == 160) {
            isValid = P256.verifySignature(
                hash,
                bytes32(signature[:32]),
                bytes32(signature[32:64]),
                bytes32(signature[64:128]),
                bytes32(signature[128:160])
            ) && passkeys[msg.sender][bytes32(signature[96:128])] == bytes32(signature[128:160]);
        } else {
            address backup;
            isValid = SignatureCheckerLib.isValidSignatureNowCalldata(
                backup = address(bytes20(signature[:20])), hash, signature[20:]
            ) && backups[msg.sender][backup];
        }
        assembly ("memory-safe") {
            // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
            // We use `0xffffffff` for invalid, in convention with the reference implementation.
            result := shl(224, or(0x1626ba7e, sub(0, iszero(isValid))))
        }
    }

    /// ======================== INSTALLATION ======================== ///

    /// @dev Adds onchain backup addresses and passkey `x` `y` pairings for the caller account.
    function install(address[] calldata _backups, Passkey[] calldata _passkeys) public virtual {
        if (_backups.length != 0) {
            for (uint256 i; i != _backups.length; ++i) {
                emit BackupSet(msg.sender, _backups[i], (backups[msg.sender][_backups[i]] = true));
            }
        }
        if (_passkeys.length != 0) {
            for (uint256 i; i != _passkeys.length; ++i) {
                emit PasskeySet(
                    msg.sender,
                    _passkeys[i].x,
                    (passkeys[msg.sender][_passkeys[i].x] = _passkeys[i].y)
                );
            }
        }
        try IOwnable(msg.sender).requestOwnershipHandover() {} catch {} // Avoid revert.
    }

    /// @dev Sets onchain backup address activity status for the caller account.
    function setBackup(address backup, bool active) public virtual {
        emit BackupSet(msg.sender, backup, (backups[msg.sender][backup] = active));
    }

    /// @dev Sets passkey `x` `y` pairing for the caller account.
    function setPasskey(bytes32 x, bytes32 y) public virtual {
        emit PasskeySet(msg.sender, x, (passkeys[msg.sender][x] = y));
    }
}

/// @notice Simple ownership interface for handover requests.
interface IOwnable {
    function requestOwnershipHandover() external payable;
}
