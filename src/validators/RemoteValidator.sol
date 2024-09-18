// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {EIP712} from "@solady/src/utils/EIP712.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple remote non-sequential validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/RemoteValidator.sol)
/// @custom:version 1.0.0
contract RemoteValidator is EIP712 {
    /// ========================= CONSTANTS ========================= ///

    /// @dev Prehash of `keccak256("")` for validation efficiency.
    bytes32 internal constant _NULL_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /// @dev EIP712 typehash as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    /// Derived from `userOp` without the signature and the time fields of `validUntil` and `validAfter`.
    bytes32 internal constant _VALIDATE_TYPEHASH =
        0xa9a214c6f6d90f71d094504e32920cfd4d8d53e5d7cf626f9a26c88af60081c7;

    /// @dev Returns domain name
    /// & version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override(EIP712)
        returns (string memory, string memory)
    {
        return ("RemoteValidator", "1.0.0");
    }

    /// ========================== STRUCTS ========================== ///

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

    /// @dev Validates packed ERC4337 userOp in EIP-712-signed non-sequential flow.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        (uint48 validUntil, uint48 validAfter) =
            (uint48(bytes6(userOp.signature[:6])), uint48(bytes6(userOp.signature[6:12])));
        bool valid = SignatureCheckerLib.isValidSignatureNowCalldata(
            IOwnable(msg.sender).owner(),
            __hashTypedData(userOp, validUntil, validAfter),
            userOp.signature[12:]
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
            let mem := mload(0x40)
            let len := data.length
            calldatacopy(mem, data.offset, len)
            hash := keccak256(mem, len)
        }
    }
}

/// @dev Simple ownable contract interface.
interface IOwnable {
    function owner() external view returns (address);
}
