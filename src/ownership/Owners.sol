// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC6909} from "@solady/src/tokens/ERC6909.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple ownership singleton for smart accounts.
/// @custom:version 0.0.0
contract Owners is ERC6909 {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Inputs are invalid for an ownership setting.
    error InvalidSetting();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the ownership threshold for an account.
    event ThresholdSet(address indexed account, uint88 threshold);

    /// @dev Logs the tokenized ownership details for an account.
    event TokenSet(address indexed account, ITokenOwner tkn, TokenStandard std);

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
        uint88 threshold;
        TokenStandard std;
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

    /// @dev Stores mapping of auth settings to accounts.
    mapping(address => IAuthority) public auth;

    /// @dev Stores mapping of metadata settings to accounts.
    mapping(uint256 => string) public uris;

    /// @dev Stores mapping of ownership settings to accounts.
    mapping(address => Settings) public settings;

    /// @dev Stores mapping of share balance supplies to accounts.
    /// This is used for ownership settings without external tokens.
    mapping(uint256 => uint256) public totalSupply;

    /// ====================== ERC6909 METADATA ====================== ///

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return "Owners";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return "OWN";
    }

    /// @dev Returns the URI of the token ID.
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        string memory uri = uris[id];
        return bytes(uri).length != 0 ? uri : "";
    }

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
            uint256 pos;
            address prev;
            address owner;
            uint256 tally;
            uint256 len = signature.length / 85;
            // Check if the owners' signature is valid:
            for (uint256 i; i < len; ++i) {
                if (
                    SignatureCheckerLib.isValidSignatureNow(
                        owner = address(bytes20(signature[pos:pos + 20])),
                        hash,
                        signature[pos + 20:pos + 65]
                    ) && prev < owner
                ) {
                    tally += set.tkn == ITokenOwner(address(0))
                        ? balanceOf(owner, uint256(keccak256(abi.encodePacked(msg.sender))))
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
        uint88 threshold
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
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender)));
        totalSupply[id] += shares;
        _mint(owner, id, shares);
    }

    /// @dev Burns shares from an owner of the caller account.
    function burn(address owner, uint256 shares) public payable virtual {
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender)));
        unchecked {
            if (settings[msg.sender].threshold > (totalSupply[id] -= shares)) {
                revert InvalidSetting();
            }
        }
        _burn(owner, id, shares);
    }

    /// @dev Sets new token ownership details for the caller account.
    function setToken(ITokenOwner tkn, TokenStandard std) public payable virtual {
        settings[msg.sender].tkn = tkn;
        settings[msg.sender].std = std;
        emit TokenSet(msg.sender, tkn, std);
    }

    /// @dev Sets new ownership threshold for the caller account.
    function setThreshold(uint88 threshold) public payable virtual {
        Settings storage set = settings[msg.sender];
        if (
            threshold
                > (
                    set.tkn == ITokenOwner(address(0))
                        ? totalSupply[uint256(keccak256(abi.encodePacked(msg.sender)))]
                        : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                            ? set.tkn.totalSupply()
                            : set.tkn.totalSupply(0)
                )
        ) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (set.threshold = threshold));
    }
}

/// @notice Simple auth interface.
interface IAuthority {
    function canCall(address user, address target, bytes4 functionSig)
        external
        view
        returns (bool);
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
