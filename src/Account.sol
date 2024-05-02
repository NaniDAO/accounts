// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";

/// @notice Simple extendable smart account implementation. Includes plugin tooling.
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
        returns (uint256)
    {
        return userOp.nonce < type(uint64).max
            ? _validateSignature(userOp, userOpHash)
            : _validateUserOp();
    }

    /// @dev Extends ERC4337 userOp validation with stored ERC7582 validator plugins.
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

    /// @dev Extends ERC1271 signature verification with stored validator plugin.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        override
        returns (bytes4)
    {
        address validator = address(bytes20(storageLoad(this.isValidSignature.selector)));
        if (validator == address(0)) {
            return super.isValidSignature(hash, signature);
        } else {
            return Account(payable(validator)).isValidSignature(hash, signature);
        }
    }
}
