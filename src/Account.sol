// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";

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
        return ("Milady", "1");
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

    // @dev This implementation decodes `nonce` for a 'key'-stored
    // authorizer that helps perform additional validation checks.
    function _validateUserOp(UserOperation calldata, bytes32, uint256)
        internal
        virtual
        returns (uint256 validationData)
    {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            if or( // Checks authorizer return.
                iszero(eq(returndatasize(), 0x20)),
                iszero( // Checks authorizer validation.
                    call(
                        gas(),
                        shr(96, sload(shl(64, shr(64, /*authorizer*/ calldataload(0x84))))),
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
