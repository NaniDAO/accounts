// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple time window validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/TimeValidator.sol)
/// @custom:version 1.0.0
contract TimeValidator {
    /// ========================== STRUCTS ========================== ///

    /// @dev The ERC4337 user operation (userOp) struct.
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    /// @dev The packed ERC4337 userOp struct.
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData;
        bytes signature;
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with time window unpacking and owner validation.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOpHash, userOp.signature);
    }

    /// @dev Validates packed ERC4337 userOp with time window unpacking and owner validation.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOpHash, userOp.signature);
    }

    /// @dev Returns validity of userOp based on an account owner signature.
    function _validateUserOp(bytes32 userOpHash, bytes calldata signature)
        internal
        virtual
        returns (uint256 validationData)
    {
        (uint48 validUntil, uint48 validAfter) =
            (uint48(bytes6(signature[:6])), uint48(bytes6(signature[6:12])));
        validationData = _packValidationData(
            SignatureCheckerLib.isValidSignatureNowCalldata(
                IOwner(msg.sender).owner(),
                SignatureCheckerLib.toEthSignedMessageHash(
                    keccak256(abi.encodePacked(userOpHash, validUntil, validAfter))
                ),
                signature[12:]
            ),
            validUntil,
            validAfter
        );
    }

    /// @dev Returns the packed validation data for userOp based on validation.
    function _packValidationData(bool valid, uint48 validUntil, uint48 validAfter)
        internal
        pure
        virtual
        returns (uint256 validationData)
    {
        validationData = valid ? 0 : 1 | validUntil << 160 | validAfter << 208;
    }
}

/// @dev Simple ownership interface for smart accounts.
interface IOwner {
    function owner() external view returns (address);
}
