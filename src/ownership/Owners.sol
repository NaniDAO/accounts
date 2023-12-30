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

    /// @dev Logs new metadata settings for an account.
    event URISet(address indexed account, string uri);

    /// @dev Logs new token authority for an account.
    event AuthSet(address indexed account, ITokenAuth auth);

    /// @dev Logs new ownership threshold for an account.
    event ThresholdSet(address indexed account, uint88 threshold);

    /// @dev Logs new token ownership strategy for an account.
    event TokenSet(address indexed account, ITokenOwner tkn, TokenStandard std);

    /// ========================== STRUCTS ========================== ///

    /// @dev The account ownership settings struct.
    struct Setting {
        ITokenOwner tkn;
        uint88 threshold;
        TokenStandard std;
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

    /// =========================== ENUMS =========================== ///

    /// @dev The token interface standards enum.
    enum TokenStandard {
        OWN,
        ERC20,
        ERC721,
        ERC1155,
        ERC6909
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mapping of metadata settings to accounts.
    mapping(uint256 => string) internal _uris;

    /// @dev Stores mapping of state authorities to accounts.
    mapping(uint256 => ITokenAuth) public auths;

    /// @dev Stores mapping of ownership settings to accounts.
    mapping(address => Setting) public settings;

    /// @dev Stores mapping of share balance supplies to accounts.
    /// This is used for ownership settings without external tokens.
    mapping(uint256 => uint256) public totalSupply;

    /// ====================== ERC6909 METADATA ====================== ///

    /// @dev Returns the name for token `id` using this contract.
    function name() public view virtual override(ERC6909) returns (string memory) {
        return "Owners";
    }

    /// @dev Returns the symbol for token `id` using this contract.
    function symbol() public view virtual override(ERC6909) returns (string memory) {
        return "OWN";
    }

    /// @dev Returns the URI for token `id` using this contract.
    function tokenURI(uint256 id) public view virtual override(ERC6909) returns (string memory) {
        return _uris[id];
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
        unchecked {
            Setting storage set = settings[msg.sender];
            uint256 pos;
            address prev;
            address owner;
            uint256 tally;
            // Check if the owners' signature is valid:
            for (uint256 i; i < signature.length / 85; ++i) {
                if (
                    SignatureCheckerLib.isValidSignatureNow(
                        owner = address(bytes20(signature[pos:pos + 20])),
                        hash,
                        signature[pos + 20:pos + 85]
                    ) && prev < owner
                ) {
                    pos += 85;
                    prev = owner;
                    tally += set.std == TokenStandard.OWN
                        ? balanceOf(owner, uint256(uint160(msg.sender)))
                        : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                            ? set.tkn.balanceOf(owner)
                            : set.tkn.balanceOf(owner, uint256(uint160(msg.sender)));
                } else {
                    return 0xffffffff; // Failure code.
                }
            }
            // Check if the ownership tally has been met:
            if (tally >= set.threshold) {
                return this.isValidSignature.selector;
            } else {
                return 0xffffffff; // Failure code.
            }
        }
    }

    /// @dev Validates ERC4337 userOp with additional auth logic flow among owners.
    /// note: This is expected to be called in a validator plugin-like userOp flow.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 /*missingAccountFunds*/
    ) public payable virtual returns (uint256 validationData) {
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
    function install(
        address[] calldata owners,
        uint256[] calldata shares,
        ITokenOwner tkn,
        TokenStandard std,
        uint88 threshold,
        string calldata uri,
        ITokenAuth auth
    ) public payable virtual {
        uint256 id = uint256(uint160(msg.sender));
        if (owners.length != 0) {
            if (owners.length != shares.length) revert InvalidSetting();
            uint256 supply;
            for (uint256 i; i < owners.length;) {
                _mint(owners[i], id, shares[i]);
                supply += shares[i];
                unchecked {
                    ++i;
                }
            }
            unchecked {
                totalSupply[id] += supply;
            }
        }
        setToken(tkn, std);
        setThreshold(threshold);
        if (bytes(uri).length != 0) setURI(uri);
        if (auth != ITokenAuth(address(0))) auths[id] = auth;
        IOwnable(msg.sender).requestOwnershipHandover();
    }

    /// ===================== OWNERSHIP SETTINGS ===================== ///

    /// @dev Mints shares for an owner of the caller account.
    function mint(address owner, uint256 shares) public payable virtual {
        uint256 id = uint256(uint160(msg.sender));
        totalSupply[id] += shares;
        _mint(owner, id, shares);
    }

    /// @dev Burns shares from an owner of the caller account.
    function burn(address owner, uint256 shares) public payable virtual {
        uint256 id = uint256(uint160(msg.sender));
        unchecked {
            if (settings[msg.sender].threshold > (totalSupply[id] -= shares)) {
                revert InvalidSetting();
            }
        }
        _burn(owner, id, shares);
    }

    /// @dev Sets new token metadata URI for the caller account.
    function setURI(string calldata uri) public payable virtual {
        emit URISet(msg.sender, (_uris[uint256(uint160(msg.sender))] = uri));
    }

    /// @dev Sets new token authority for the caller account.
    function setAuth(ITokenAuth auth) public payable virtual {
        emit AuthSet(msg.sender, (auths[uint256(uint160(msg.sender))] = auth));
    }

    /// @dev Sets new token ownership strategy for the caller account.
    function setToken(ITokenOwner tkn, TokenStandard std) public payable virtual {
        settings[msg.sender].tkn = tkn;
        settings[msg.sender].std = std;
        emit TokenSet(msg.sender, tkn, std);
    }

    /// @dev Sets new ownership threshold for the caller account.
    function setThreshold(uint88 threshold) public payable virtual {
        Setting storage set = settings[msg.sender];
        if (
            threshold
                > (
                    set.std == TokenStandard.OWN
                        ? totalSupply[uint256(uint160(msg.sender))]
                        : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                            ? set.tkn.totalSupply()
                            : set.tkn.totalSupply(uint256(uint160(msg.sender)))
                ) || threshold == 0
        ) revert InvalidSetting();
        emit ThresholdSet(msg.sender, (set.threshold = threshold));
    }

    /// ========================= OVERRIDES ========================= ///

    /// @dev Hook that is called before any transfer of tokens.
    /// This includes minting and burning. Requests authority for the token transfer.
    function _beforeTokenTransfer(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909)
    {
        ITokenAuth auth = auths[id];
        if (auth != ITokenAuth(address(0))) auth.canTransfer(from, to, id, amount);
    }
}

/// @notice Simple interface for ownership requests.
interface IOwnable {
    function requestOwnershipHandover() external payable;
}

/// @notice Simple authority interface for token transfers.
interface ITokenAuth {
    function canTransfer(address, address, uint256, uint256) external payable;
}

/// @notice Generalized fungible token ownership interface.
interface ITokenOwner {
    function balanceOf(address) external view returns (uint256);
    function balanceOf(address, uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalSupply(uint256) external view returns (uint256);
}
