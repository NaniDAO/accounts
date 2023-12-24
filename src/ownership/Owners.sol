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

    /// @dev Logs the token ownership details for an account.
    event TokenSet(address indexed account, ITokenOwner tkn, TokenStandard std);

    /// @dev Logs share balance updates for account owners.
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
        ITokenOwner tkn;
        uint64 threshold;
        TokenStandard std;
        uint256 totalSupply;
    }

    /// =========================== ENUMS =========================== ///

    /// @dev The token interface standards enum.
    enum TokenStandard {
        ERC20,
        ERC721,
        ERC1155,
        ERC6909
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of ownership settings to accounts.
    mapping(address => Settings) public settings;

    /// @dev Stores mappings of share balances to account owners.
    /// This is used for ownership settings without external tokens.
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
        Settings storage set = settings[msg.sender];
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
                    tally += set.tkn == ITokenOwner(address(0))
                        ? balanceOf[msg.sender][owner]
                        : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                            ? ITokenOwner(set.tkn).balanceOf(owner)
                            : ITokenOwner(set.tkn).balanceOf(owner, 0);
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

    /// @dev Validates ERC4337 userOp with additional auth logic flow among owners.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 /*missingAccountFunds*/
    ) public payable virtual returns (uint256 validationData) {
        if (
            isValidSignature(
                SignatureCheckerLib.toEthSignedMessageHash(userOpHash), userOp.signature
            ) != this.isValidSignature.selector
        ) validationData = 0x01;
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Initializes ownership settings for the caller account.
    /// note: Finalizes with transfer request in two-step pattern.
    /// See, e.g., Ownable.sol:
    /// https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol
    function install(
        address[] calldata owners,
        uint256[] calldata shares,
        ITokenOwner tkn,
        TokenStandard std,
        uint64 threshold
    ) public payable virtual {
        if (owners.length != 0) {
            if (owners.length != shares.length) revert InvalidSetting();
            unchecked {
                for (uint256 i; i < owners.length; ++i) {
                    mint(owners[i], shares[i]);
                }
            }
        }
        setToken(tkn, std);
        setThreshold(threshold);
        IOwnable(msg.sender).requestOwnershipHandover();
    }

    /// ===================== OWNERSHIP SETTINGS ===================== ///

    /// @dev Mints shares for an owner of the caller account.
    function mint(address owner, uint256 shares) public payable virtual {
        settings[msg.sender].totalSupply += shares;
        unchecked {
            balanceOf[msg.sender][owner] += shares;
            emit Transfer(address(0), owner, shares);
        }
    }

    /// @dev Burns shares from an owner of the caller account.
    function burn(address owner, uint256 shares) public payable virtual {
        unchecked {
            if (settings[msg.sender].threshold > (settings[msg.sender].totalSupply -= shares)) {
                revert InvalidSetting();
            }
        }
        balanceOf[msg.sender][owner] -= shares;
        emit Transfer(owner, address(0), shares);
    }

    /// @dev Sets new token ownership details for the caller account.
    function setToken(ITokenOwner tkn, TokenStandard std) public payable virtual {
        settings[msg.sender].tkn = tkn;
        settings[msg.sender].std = std;
        emit TokenSet(msg.sender, tkn, std);
    }

    /// @dev Sets new ownership threshold for the caller account.
    function setThreshold(uint64 threshold) public payable virtual {
        Settings storage set = settings[msg.sender];
        if (
            threshold
                > (
                    set.tkn == ITokenOwner(address(0))
                        ? set.totalSupply
                        : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                            ? set.tkn.totalSupply()
                            : set.tkn.totalSupply(0)
                )
        ) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (set.threshold = threshold));
    }
}

/// @notice Simple ownership interface for account transfer requests.
interface IOwnable {
    function requestOwnershipHandover() external payable;
}

/// @notice Generalized fungible token ownership interface.
interface ITokenOwner {
    function balanceOf(address) external view returns (uint256);
    function balanceOf(address, uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalSupply(uint256) external view returns (uint256);
}
