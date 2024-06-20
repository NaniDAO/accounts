// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import {EIP712, SignatureCheckerLib, ERC1271} from "@solady/src/accounts/ERC1271.sol";

/// @notice Simple extendable smart account implementation. Includes plugin tooling.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// @dev Prehash of `keccak256("")` for validation efficiency.
    bytes32 internal constant _NULL_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

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
        return ("NANI", "1.2.0");
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
    ) internal view virtual returns (bytes32 digest) {
        // We will use `digest` to store the `userOp.sender` to save a bit of gas.
        assembly ("memory-safe") {
            digest := calldataload(userOp)
        }
        return EIP712._hashTypedData(
            keccak256(
                abi.encode(
                    _VALIDATE_TYPEHASH,
                    digest, // Optimize.
                    userOp.nonce,
                    userOp.initCode.length == 0 ? _NULL_HASH : _calldataKeccak(userOp.initCode),
                    _calldataKeccak(userOp.callData),
                    userOp.accountGasLimits,
                    userOp.preVerificationGas,
                    userOp.gasFees,
                    userOp.paymasterAndData.length == 0
                        ? _NULL_HASH
                        : _calldataKeccak(userOp.paymasterAndData),
                    validUntil,
                    validAfter
                )
            )
        );
    }

    /// @dev Keccak function over calldata. This is more efficient than letting solidity do it.
    function _calldataKeccak(bytes calldata data) internal pure virtual returns (bytes32 hash) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            let l := data.length
            calldatacopy(m, data.offset, l)
            hash := keccak256(m, l)
        }
    }

    /// @dev Extends ERC4337 userOp validation in stored ERC7582 validator plugin.
    function _validateUserOp() internal virtual returns (uint256 validationData) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            calldatacopy(0x00, 0x00, calldatasize())
            if or(
                lt(returndatasize(), 0x20),
                iszero(
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
                )
            ) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            validationData := mload(0x00)
            mstore(0x40, m) // Restore the free memory pointer.
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
