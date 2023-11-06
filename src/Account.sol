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

        (address validator, uint256 validAfter, uint256 validUntil) = decodeStorage(storageLoad(keccak256(abi.encodePacked(uint192(userOp.nonce >> 64)))));
        
        console.log("_validateUserOp storageLoad result");
        console.logAddress(validator);
        console.log(uint256(validAfter));
        console.log(uint256(validUntil));
        if (validAfter == type(uint48).max && validUntil == type(uint48).max) {
            validationData = Account(payable(validator)).validateUserOp(userOp, userOpHash, missingAccountFunds);
        } else {
            validationData = packValidationData(validator, validAfter, validUntil);
        }
    }

    function decodeStorage(bytes32 value) public view  returns (address validator, uint256 validAfter, uint256 validUntil) {
        console.log("decodeStorage value");
        console.logBytes32(value);
        validator = address(bytes20(value));
        validAfter = uint256(value) << 160;
        validUntil = uint256(value) << 208;
    }

    function packValidationData(address validator, uint256 validAfter, uint256 validUntil) public pure returns (uint256 validationData) {
        return type(uint256).min;
    }
}
