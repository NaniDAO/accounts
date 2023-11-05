// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import "@forge/Test.sol";

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
            validationData = _validateUserOp(userOp, userOpHash, missingAccountFunds);
        }
    }

    /// @dev This implementation decodes `nonce` for a 'key'-stored
    /// authorizer that helps perform additional validation checks.
    function _validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) internal virtual returns (uint256 validationData) {
        console.log("_validateUserOp userOp.nonce key");
        console.log(userOp.nonce >> 64);

        storageStore(
            keccak256(abi.encodePacked(userOp.nonce >> 64)),
            0xf62849f9a0b5bf2913b396098f7c7019b51a820a000000000000000000000000
        );

        bytes32 result = storageLoad(keccak256(abi.encodePacked(userOp.nonce >> 64)));
        Account validator = Account(payable(address(bytes20(result))));

        console.log("_validateUserOp storageLoad result");
        console.logBytes32(result);

        if (result.length == 20) {
            validationData = validator.validateUserOp(userOp, userOpHash, missingAccountFunds);
        } else {
            validationData = uint256(result);
        }
    }
}
