// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";

/// @notice Simple extendable smart account implementation.
/// @author nani.eth (https://github.com/nanidao/account/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// @dev Returns domain name and
    /// version of this implementation.
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
    /// with auth logic flow.
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
        if (userOp.nonce < type(uint64).max) {
            validationData = _validateSignature(userOp, userOpHash);
        } else {
            validationData = _validateUserOp(userOp, userOpHash, missingAccountFunds);
        }
    }

    /// @dev Decodes `userOp.nonce` for a 'key'-stored authorizer account
    /// that contains extended validation logic and auth for the `userOp`.
    function _validateUserOp(UserOperation calldata, bytes32, uint256)
        internal
        virtual
        returns (uint256 validationData)
    {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            if or( // Check authorizer returns.
                lt(returndatasize(), 0x20), // At least 32 bytes returned.
                iszero( // Check authorizer in decoded `nonce`
                    call( // to forward calldata in `validateUserOp`.
                        gas(),
                        shr(
                            96, /*authorizer*/ sload(shl(64, shr(64, /*nonce*/ calldataload(0x84))))
                        ),
                        0,
                        0x00, // Call.
                        calldatasize(),
                        0x00, // Return.
                        0x20
                    )
                )
            ) { validationData := iszero(0) } // Failure returns digit.
            if iszero(validationData) { validationData := mload(0x00) } // Success returns data.
        }
    }
}
