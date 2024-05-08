// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import {EIP712, SignatureCheckerLib, ERC1271} from "@solady/src/accounts/ERC1271.sol";

/// @notice Simple extendable smart account implementation. Includes plugin tooling.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// @dev EIP712 typehash as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    /// Derived from `userOp` without the signature and the time fields of `validUntil` and `validAfter`.
    bytes32 internal constant _VALIDATE_TYPEHASH =
        0xa9a214c6f6d90f71d094504e32920cfd4d8d53e5d7cf626f9a26c88af60081c7;

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// @dev Returns domain name
    /// & version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override(EIP712)
        returns (string memory, string memory)
    {
        return ("NANI", "1.1.1");
    }

    /// @dev Validates userOp
    /// with nonce handling.
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
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
        return
            userOp.nonce < type(uint64).max ? _validateUserOpSignature(userOp) : _validateUserOp();
    }

    /// @dev Validates `userOp.signature` for the EIP712-encoded `userOp`.
    function _validateUserOpSignature(PackedUserOperation calldata userOp)
        internal
        virtual
        returns (uint256)
    {
        (uint48 validUntil, uint48 validAfter) =
            (uint48(bytes6(userOp.signature[:6])), uint48(bytes6(userOp.signature[6:12])));
        bool valid = SignatureCheckerLib.isValidSignatureNowCalldata(
            owner(), __hashTypedData(userOp, validUntil, validAfter), userOp.signature[12:]
        );
        return (valid ? 0 : 1) | (uint256(validUntil) << 160) | (uint256(validAfter) << 208);
    }

    /// @dev Encodes `userOp` and extracted time window within EIP712 syntax.
    function __hashTypedData(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) internal view virtual returns (bytes32) {
        address sender;
        assembly ("memory-safe") {
            sender := calldataload(userOp)
        }
        return EIP712._hashTypedData(
            keccak256(
                abi.encode(
                    _VALIDATE_TYPEHASH,
                    sender,
                    userOp.nonce,
                    userOp.initCode.length == 0 ? bytes32(0) : keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.accountGasLimits,
                    userOp.preVerificationGas,
                    userOp.gasFees,
                    userOp.initCode.length == 0 ? bytes32(0) : keccak256(userOp.paymasterAndData),
                    validUntil,
                    validAfter
                )
            )
        );
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
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            validationData := mload(0x00)
        }
    }

    /// @dev Validates ERC1271 signature. Plugin activated if stored.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        override(ERC1271)
        returns (bytes4)
    {
        address validator = address(bytes20(storageLoad(this.isValidSignature.selector)));
        if (validator == address(0)) return super.isValidSignature(hash, signature);
        else return Account(payable(validator)).isValidSignature(hash, signature);
    }
}
