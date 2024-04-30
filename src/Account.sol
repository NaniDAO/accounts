// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {P256} from "@solady/src/utils/P256.sol";
import {SignatureCheckerLib, ERC4337} from "@solady/src/accounts/ERC4337.sol";

/// @notice Simple extendable smart account implementation. Includes secp256r1 auth.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// @dev Returns domain name
    /// & version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory, string memory)
    {
        return ("NANI", "1.0.0");
    }

    /// @dev Validates userOp
    /// with nonce handling.
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        virtual
        override(ERC4337)
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256 validationData)
    {
        return userOp.nonce < type(uint64).max
            ? _validateSignature(userOp, userOpHash)
            : _validateUserOp();
    }

    /// @dev Extends ERC4337 userOp validation with ERC7582 plugin validator flow.
    function _validateUserOp() internal virtual returns (uint256 validationData) {
        assembly ("memory-safe") {
            calldatacopy(0x00, 0x00, calldatasize())
            if iszero(
                call(
                    gas(),
                    /*validator*/
                    shr(96, sload(shl(64, /*key*/ shr(64, /*nonce*/ calldataload(0x84))))),
                    0,
                    0x00,
                    calldatasize(),
                    0x00,
                    0x20
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            // Return `validationData` if call succeeds.
            validationData := mload(0x00)
        }
    }

    /// @dev Extends ERC1271 signature verification with secp256r1.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        override
        returns (bytes4 result)
    {
        if (signature.length == 128) {
            bool success = P256.verifySignature(
                SignatureCheckerLib.toEthSignedMessageHash(hash),
                uint256(bytes32(signature[:32])),
                uint256(bytes32(signature[32:64])),
                uint256(bytes32(signature[64:96])),
                uint256(bytes32(signature[96:128]))
            ) && storageLoad(bytes32(signature[64:96])) /*x*/ == bytes32(signature[96:128]); /*y*/
            assembly ("memory-safe") {
                // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
                // We use `0xffffffff` for invalid, in convention with the reference implementation.
                result := shl(224, or(0x1626ba7e, sub(0, iszero(success))))
            }
        } else {
            result = super.isValidSignature(hash, signature);
        }
    }
}
