// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ERC4337 Paymaster.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/Paymaster.sol)
/// @custom:version 1.0.0
contract Paymaster {
    /// ========================= CONSTANTS ========================= ///

    /// @dev The canonical ERC4337 EntryPoint contract (0.7).
    address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner for this contract.
    address internal immutable OWNER;

    /// ========================== STRUCTS ========================== ///

    /// @dev The packed ERC4337 userOp struct (0.7).
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

    /// ========================= MODIFIERS ========================= ///

    /// @dev Requires that the caller is the owner.
    modifier onlyOwner() virtual {
        address owner = OWNER;
        assembly ("memory-safe") {
            if iszero(eq(caller(), owner)) { revert(codesize(), 0x00) }
        }
        _;
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs this owned implementation.
    constructor(address owner) payable {
        OWNER = owner;
    }

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Paymaster validation: check that contract owner signed off.
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 /*maxCost*/
    ) public payable virtual returns (bytes memory, uint256) {
        assembly ("memory-safe") {
            if iszero(eq(caller(), ENTRY_POINT)) { revert(codesize(), 0x00) }
        }
        (uint48 validUntil, uint48 validAfter) =
            abi.decode(userOp.paymasterAndData[20:84], (uint48, uint48));
        bytes calldata signature = userOp.paymasterAndData[84:];
        if (
            SignatureCheckerLib.isValidSignatureNowCalldata(
                OWNER, _hashSignedUserOp(userOp, validUntil, validAfter), signature
            )
        ) {
            return ("", _packValidationData(true, validUntil, validAfter));
        } else {
            return ("", _packValidationData(false, validUntil, validAfter));
        }
    }

    /// @dev Returns the eth-signed message hash of the userOp within the context of the paymaster and user.
    function _hashSignedUserOp(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) internal view virtual returns (bytes32) {
        return SignatureCheckerLib.toEthSignedMessageHash(
            keccak256(
                abi.encode(
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.accountGasLimits,
                    uint256(bytes32(userOp.paymasterAndData[20:52])),
                    userOp.preVerificationGas,
                    userOp.gasFees,
                    block.chainid,
                    address(this),
                    validUntil,
                    validAfter
                )
            )
        );
    }

    /// @dev Returns the packed validation data for `validatePaymasterUserOp`.
    function _packValidationData(bool valid, uint48 validUntil, uint48 validAfter)
        internal
        pure
        virtual
        returns (uint256)
    {
        return valid ? 0 : 1 | validUntil << 160 | validAfter << 208;
    }

    /// ===================== STAKING OPERATIONS ===================== ///

    /// @dev Add stake for this paymaster. Further sets a staking delay timestamp.
    function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner {
        Paymaster(ENTRY_POINT).addStake{value: msg.value}(unstakeDelaySec);
    }

    /// @dev Unlock the stake, in order to withdraw it.
    function unlockStake() public payable virtual onlyOwner {
        Paymaster(ENTRY_POINT).unlockStake();
    }

    /// @dev Withdraw the entire paymaster's stake. Can select a recipient of this withdrawal.
    function withdrawStake(address payable withdrawAddress) public payable virtual onlyOwner {
        Paymaster(ENTRY_POINT).withdrawStake(withdrawAddress);
    }
}
