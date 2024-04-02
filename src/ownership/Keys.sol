// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple token-bound ownership singleton for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/ownership/Keys.sol)
/// @dev The Keys singleton approximates ERC6551 token-bound account ownership with NFTs.
/// @custom:version 1.0.0
contract Keys {
    /// =========================== EVENTS =========================== ///

    /// @dev Logs new authority contract for an account.
    event AuthSet(address indexed account, IAuth auth);

    /// @dev Logs new NFT ownership settings for an account.
    event TokenSet(address indexed account, address NFT, uint256 id);

    /// ========================== STRUCTS ========================== ///

    /// @dev The NFT ownership settings struct.
    struct Settings {
        address nft;
        uint256 id;
        IAuth auth;
    }

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
        Settings storage set = _settings[msg.sender];
        return _validateReturn(
            SignatureCheckerLib.isValidSignatureNowCalldata(
                _ownerOf(set.nft, set.id), hash, signature
            )
        );
    }

    /// @dev Validates ERC4337 userOp with additional auth logic flow among owners.
    /// note: This is expected to be called in a validator plugin-like userOp flow.
    function validateUserOp(
        PackedUserOperation calldata userOp,
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

    /// @dev Returns the `owner` of the given `nft` `id`.
    function _ownerOf(address nft, uint256 id) internal view virtual returns (address owner) {
        assembly ("memory-safe") {
            mstore(0x00, 0x6352211e) // `ownerOf(uint256)`.
            mstore(0x20, id) // Store the `id` argument.
            pop(staticcall(gas(), nft, 0x1c, 0x24, 0x20, 0x20))
            owner := mload(0x20)
        }
    }

    /// @dev Returns validated signature result within the conventional ERC1271 syntax.
    function _validateReturn(bool success) internal pure virtual returns (bytes4 result) {
        assembly ("memory-safe") {
            // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
            result := shl(224, or(0x1626ba7e, sub(0, iszero(success))))
        }
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Initializes ownership settings for the caller account.
    /// note: Finalizes with transfer request in two-step pattern.
    /// See, e.g., Ownable.sol:
    /// https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol
    function install(address nft, uint256 id, IAuth auth) public payable virtual {
        setToken(nft, id);
        if (auth != IAuth(address(0))) setAuth(auth);
        try IOwnable(msg.sender).requestOwnershipHandover() {} catch {} // Avoid revert.
    }

    /// ===================== OWNERSHIP SETTINGS ===================== ///

    /// @dev Returns the account settings.
    function getSettings(address account) public view virtual returns (address, uint256, IAuth) {
        Settings storage set = _settings[account];
        return (set.nft, set.id, set.auth);
    }

    /// @dev Sets new authority contract for the caller account.
    function setAuth(IAuth auth) public payable virtual {
        emit AuthSet(msg.sender, (_settings[msg.sender].auth = auth));
    }

    /// @dev Sets new NFT ownership details for the caller account.
    function setToken(address nft, uint256 id) public payable virtual {
        emit TokenSet(msg.sender, _settings[msg.sender].nft = nft, _settings[msg.sender].id = id);
    }
}

/// @notice Simple authority interface for contracts.
interface IAuth {
    function validateCall(address, address, uint256, bytes calldata)
        external
        payable
        returns (uint256);
}

/// @notice Simple ownership interface for handover requests.
interface IOwnable {
    function requestOwnershipHandover() external payable;
}
