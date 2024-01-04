// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC6909} from "@solady/src/tokens/ERC6909.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple token-bound ownership singleton for smart accounts.
/// @custom:version 0.0.0
contract Keys {
    /// =========================== EVENTS =========================== ///

    /// @dev Logs new authority contract for an account.
    event AuthSet(address indexed account, IAuth auth);

    /// @dev Logs new NFT ownership settings for an account.
    event TokenSet(address indexed account, INFTOwner NFT, uint256 id);

    /// ========================== STRUCTS ========================== ///

    /// @dev The NFT ownership settings struct.
    struct Settings {
        INFTOwner nft;
        IAuth auth;
        uint256 id;
    }

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

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mapping of ownership settings to accounts.
    mapping(address account => Settings) internal _settings;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC1271 signature with additional check for NFT ID ownership.
    /// note: This implementation is designed to be the ERC-173-owner-of-4337-accounts.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4)
    {
        Settings memory set = _settings[msg.sender];
        address owner;
        if (
            SignatureCheckerLib.isValidSignatureNow(
                owner = address(bytes20(signature[:20])), hash, signature[20:85]
            ) && owner == set.nft.ownerOf(set.id)
        ) {
            return this.isValidSignature.selector;
        } else {
            return 0xffffffff; // Failure code.
        }
    }

    /// @dev Validates ERC4337 userOp with additional auth logic flow among owners.
    /// note: This is expected to be called in a validator plugin-like userOp flow.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 /*missingAccountFunds*/
    ) public payable virtual returns (uint256 validationData) {
        IAuth auth = _settings[msg.sender].auth;
        if (auth != IAuth(address(0))) {
            (address target, uint256 value, bytes memory data) =
                abi.decode(userOp.callData[4:], (address, uint256, bytes));
            auth.validateCall(msg.sender, target, value, data);
        }
        if (
            isValidSignature(
                SignatureCheckerLib.toEthSignedMessageHash(userOpHash), userOp.signature
            ) != this.isValidSignature.selector
        ) validationData = 0x01; // Failure code.
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Initializes ownership settings for the caller account.
    /// note: Finalizes with transfer request in two-step pattern.
    /// See, e.g., Ownable.sol:
    /// https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol
    function install(INFTOwner nft, uint256 id, IAuth auth) public payable virtual {
        setToken(nft, id);
        if (auth != IAuth(address(0))) setAuth(auth);
        IOwnable(msg.sender).requestOwnershipHandover();
    }

    /// ===================== OWNERSHIP SETTINGS ===================== ///

    /// @dev Returns the account settings.
    function getSettings(address account) public view virtual returns (INFTOwner, IAuth, uint256) {
        Settings storage set = _settings[account];
        return (set.nft, set.auth, set.id);
    }

    /// @dev Sets new authority contract for the caller account.
    function setAuth(IAuth auth) public payable virtual {
        emit AuthSet(msg.sender, (_settings[msg.sender].auth = auth));
    }

    /// @dev Sets new NFT ownership details for the caller account.
    function setToken(INFTOwner nft, uint256 id) public payable virtual {
        emit TokenSet(msg.sender, _settings[msg.sender].nft = nft, _settings[msg.sender].id = id);
    }
}

/// @notice Simple ownership interface for handover requests.
interface IOwnable {
    function requestOwnershipHandover() external payable;
}

/// @notice Simple authority interface for contracts.
interface IAuth {
    function validateCall(address, address, uint256, bytes calldata)
        external
        payable
        returns (uint256);
}

/// @notice Non-fungible token ownership interface, e.g., ERC721.
interface INFTOwner {
    function ownerOf(uint256) external view returns (address);
}
