// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ERC4337 Paymaster.
/// @custom:version 0.0.0
contract Paymaster {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The current time range is invalid for the signature.
    error InvalidTimestamp();

    /// ========================= CONSTANTS ========================= ///

    /// @dev The canonical ERC4337 EntryPoint contract.
    address payable internal constant _ENTRY_POINT =
        payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner.
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

    /// @dev Payment validation: check if paymaster agrees to pay.
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 /*maxCost*/
    ) public payable virtual onlyEntryPoint returns (bytes memory, uint256) {
        address sender;
        assembly ("memory-safe") {
            sender := calldataload(userOp)
        }
        (uint48 validUntil, uint48 validAfter, bytes memory signature) =
            abi.decode(userOp.paymasterAndData[20:], (uint48, uint48, bytes));
        if (block.timestamp > validUntil) revert InvalidTimestamp();
        if (block.timestamp < validAfter) revert InvalidTimestamp();
        if (
            SignatureCheckerLib.isValidSignatureNow(
                _OWNER,
                SignatureCheckerLib.toEthSignedMessageHash(
                    getHash(sender, userOp, validUntil, validAfter)
                ),
                signature
            )
        ) {
            return (abi.encode(sender), 0);
        } else {
            return ("", 1);
        }
    }

    /// @dev Perfunctory post-operation (postOp) handler.
    function postOp(PostOpMode, bytes calldata, uint256) public payable virtual onlyEntryPoint {
        return;
    }

    /// @dev Returns the hash the owner will sign offchain and validate onchain.
    /// note: This covers all fields of the userOp, except `paymasterAndData`.
    function getHash(
        address sender,
        UserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) public view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                sender,
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

/// @notice Modes for ERC4337 postOp.
enum PostOpMode {
    opSucceeded,
    opReverted,
    postOpReverted
}
