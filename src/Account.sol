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
        return ("NANI", "0.0.0");
    }

    /// @dev Validates userOp
    /// with auth logic flow.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        public
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
            validationData = _validateAuth(userOp, userOpHash);
        }
    }

    /// @dev This implementation decodes `nonce` for a 'key'-stored
    /// authorizer address and selector that performs validation checks.
    function _validateAuth(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        returns (uint256 validationData)
    {
        bytes32 result = storageLoad(keccak256(abi.encodePacked(userOp.nonce >> 64)));
        // ToDo: make sure result is not any priority slots like owner, implementation, etc.

        (bool success, bytes memory retData) = address(bytes20(result)).call(
            abi.encodeWithSelector(bytes4(result << 224), userOp, userOpHash)
        );

        if (!success) validationData = 1;
        else return abi.decode(retData, (uint256));
    }
}
