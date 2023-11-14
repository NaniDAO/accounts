// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";

/// @notice Simple extendable smart account implementation.
/// @author nani.eth (https://github.com/nanidao/account/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// @dev Returns domain name &
    /// version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory, string memory)
    {
        return ("NANI", "0.0.0");
    }

    /// @dev Validates userOp
    /// with nonce handling.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        virtual
        override
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256 validationData)
    {
        validationData = userOp.nonce < type(uint64).max
            ? _validateSignature(userOp, userOpHash)
            : _validateUserOp();
    }

    /// @dev Extends validation
    /// with authorizer plugin.
    function _validateUserOp() internal virtual returns (uint256 validationData) {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            if iszero( // Check authorizer in decoded `nonce`
                call( // to forward calldata in `validateUserOp`.
                    gas(),
                    shr(96, /*authorizer*/ sload(shl(64, shr(64, /*nonce*/ calldataload(0x84))))),
                    0,
                    0x00, // Call.
                    calldatasize(),
                    0x00, // Return.
                    0x20
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            validationData := mload(0x00)
        }
    }
}
