// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ownership singleton for smart accounts.
/// @custom:version 0.0.0
contract Owners {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Inputs are invalid for an ownership setting.
    error InvalidSetting();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the ownership threshold for an account.
    event ThresholdSet(address indexed account, uint256 threshold);

    /// @dev Logs the ownership share balance for an account owner.
    event Transfer(address indexed from, address indexed to, uint256 shares);

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

    /// @dev The account ownership settings struct.
    struct Settings {
        uint128 threshold;
        uint128 totalSupply;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of settings to accounts.
    mapping(address => Settings) public settings;

    /// @dev Stores mappings of share balances to account owners.
    mapping(address => mapping(address => uint256)) public balanceOf;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC1271 signature with additional auth logic flow among owners.
    /// note: This implementation is designed to be the transferred-to owner of accounts.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4)
    {
        unchecked {
            uint256 i;
            uint256 pos;
            address prev;
            address owner;
            uint256 tally;
            uint256 len = signature.length / 85;
            // Check if the owners' signature is valid:
            for (i; i < len; ++i) {
                if (
                    SignatureCheckerLib.isValidSignatureNow(
                        owner = address(bytes20(signature[pos:pos + 20])),
                        hash,
                        signature[pos + 20:pos + 65]
                    ) && prev < owner
                ) {
                    tally += balanceOf[msg.sender][owner];
                    prev = owner;
                    pos += 85;
                } else {
                    return 0xffffffff; // Failure code.
                }
            }
            // Check if the ownership tally has been met:
            if (tally >= settings[msg.sender].threshold) {
                return this.isValidSignature.selector;
            } else {
                return 0xffffffff; // Failure code.
            }
        }
    }

    /// ======================= OWNER SETTINGS ======================= ///

    /// @dev Mints shares for an owner of the caller account.
    function mint(address owner, uint128 shares) public payable virtual {
        settings[msg.sender].totalSupply += shares;
        unchecked {
            balanceOf[msg.sender][owner] += shares;
            emit Transfer(address(0), owner, shares);
        }
    }

    /// @dev Burns shares from an owner of the caller account.
    function burn(address owner, uint128 shares) public payable virtual {
        unchecked {
            if (settings[msg.sender].threshold > (settings[msg.sender].totalSupply -= shares)) {
                revert InvalidSetting();
            }
        }
        balanceOf[msg.sender][owner] -= shares;
        emit Transfer(owner, address(0), shares);
    }

    /// @dev Sets new ownership threshold for the caller account.
    function setThreshold(uint128 threshold) public payable virtual {
        if (threshold > settings[msg.sender].totalSupply) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (settings[msg.sender].threshold = threshold));
    }
}
