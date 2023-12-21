// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ERC4337 Paymaster.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/Paymaster.sol)
/// @custom:version 0.0.0
contract Paymaster {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// ========================= CONSTANTS ========================= ///

    /// @dev The canonical ERC4337 EntryPoint contract.
    address payable internal constant _ENTRY_POINT =
        payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner for this contract.
    address payable internal immutable _OWNER;

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

    /// ========================= MODIFIERS ========================= ///

    /// @dev Requires that the caller is the EntryPoint.
    modifier onlyEntryPoint() virtual {
        if (msg.sender != _ENTRY_POINT) revert Unauthorized();
        _;
    }

    /// @dev Requires that the caller is the owner.
    modifier onlyOwner() virtual {
        if (msg.sender != _OWNER) revert Unauthorized();
        _;
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs this owned implementation.
    constructor(address payable owner) payable {
        _OWNER = owner;
    }

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Paymaster validation: check that contract owner signed off.
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 /*maxCost*/
    ) public payable virtual onlyEntryPoint returns (bytes memory, uint256) {
        (uint48 validUntil, uint48 validAfter) =
            abi.decode(userOp.paymasterAndData[20:84], (uint48, uint48));
        bytes memory signature = userOp.paymasterAndData[84:];

        if (
            SignatureCheckerLib.isValidSignatureNow(
                _OWNER, _hashSignedUserOp(userOp, validUntil, validAfter), signature
            )
        ) {
            return ("", _packValidationData(false, validUntil, validAfter));
        } else {
            return ("", _packValidationData(true, validUntil, validAfter));
        }
    }

    /// @dev Returns the packed validation data for `validatePaymasterUserOp`.
    function _packValidationData(bool sigFailed, uint48 validUntil, uint48 validAfter)
        internal
        pure
        virtual
        returns (uint256)
    {
        return
            (sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
    }

    /// @dev Returns the eth-signed message hash of the userOp within context of paymaster and user.
    function _hashSignedUserOp(UserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
        internal
        view
        virtual
        returns (bytes32)
    {
        return SignatureCheckerLib.toEthSignedMessageHash(
            keccak256(
                abi.encode(
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas,
                    block.chainid,
                    address(this),
                    validUntil,
                    validAfter
                )
            )
        );
    }

    /// ===================== STAKING OPERATIONS ===================== ///

    /// @dev Add stake for this paymaster. Further sets a staking delay timestamp.
    function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner {
        Paymaster(_ENTRY_POINT).addStake{value: msg.value}(unstakeDelaySec);
    }

    /// @dev Unlock the stake, in order to withdraw it.
    function unlockStake() public payable virtual onlyOwner {
        Paymaster(_ENTRY_POINT).unlockStake();
    }

    /// @dev Withdraw the entire paymaster's stake. Can select a recipient of this withdrawal.
    function withdrawStake(address payable withdrawAddress) public payable virtual onlyOwner {
        Paymaster(_ENTRY_POINT).withdrawStake(withdrawAddress);
    }
}
