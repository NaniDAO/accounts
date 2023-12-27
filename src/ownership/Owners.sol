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

    /// @dev Voting period has not begun for an account.
    error VotePending();

    /// @dev Voting period has ended for an account.
    error VoteEnded();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the metadata settings for an account.
    event URISet(address indexed account, string uri);

    /// @dev Logs the token authority for an account.
    event AuthSet(address indexed account, ITokenAuth auth);

    /// @dev Logs the ownership threshold for an account.
    event ThresholdSet(address indexed account, uint88 threshold);

    /// @dev Logs the token ownership strategy for an account.
    event TokenSet(address indexed account, ITokenOwner tkn, TokenStandard std);

    /// @dev Logs the creation of a proposal to an account.
    event ProposalCreated(
        address indexed proposer,
        address indexed account,
        address target,
        uint96 value,
        bytes data,
        string info
    );

    /// ========================== STRUCTS ========================== ///

    /// @dev The account proposal struct.
    struct Proposal {
        address proposer;
        address target;
        uint96 value;
        bytes data;
        bytes32 info;
        uint32 start;
        uint32 end;
        uint128 yes;
        uint128 no;
    }

    /// @dev The account proposal period struct.
    struct Period {
        uint32 voteDelay;
        uint112 votePeriod;
        uint112 gracePeriod;
    }

    /// @dev The account ownership settings struct.
    struct Settings {
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

    /// @dev The user voting actions enum.
    /// Modified from Moloch:
    /// https://github.com/MolochVentures/moloch/blob/master/contracts/Moloch.sol
    enum Vote {
        NULL,
        YES,
        NO
    }

    /// @dev The token interface standards enum.
    enum TokenStandard {
        ERC20,
        ERC721,
        ERC1155,
        ERC6909
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mapping of IDs to account proposals.
    mapping(uint256 => Proposal) public props;

    /// @dev Stores mapping of proposal periods to accounts.
    mapping(address => Period) public periods;

    /// @dev Stores mapping of metadata settings to accounts.
    mapping(uint256 => string) public uris;

    /// @dev Stores mapping of state authorities to accounts.
    mapping(uint256 => ITokenAuth) public auths;

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
                            : ITokenOwner(set.tkn).balanceOf(
                                owner, uint256(keccak256(abi.encodePacked(msg.sender)))
                            );
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
        ) validationData = 0x01; // Failure code.
    }

    /// ==================== PROPOSAL OPERATIONS ==================== ///

    /// @dev Proposes an operation to an account.
    /// The proposal ID is derived from content.
    function propose(
        address account,
        address target,
        uint96 value,
        bytes calldata data,
        string calldata info
    ) public payable virtual returns (uint256 propId) {
        Period storage period = periods[account];
        bytes32 infoHash = keccak256(bytes(info));
        propId = _hashProposalId(account, target, value, data, infoHash);
        unchecked {
            uint32 start = uint32(block.timestamp + period.voteDelay);
            props[propId] = Proposal({
                proposer: msg.sender,
                target: target,
                value: value,
                data: data,
                info: infoHash,
                start: start,
                end: uint32(start + period.votePeriod),
                yes: 0,
                no: 0
            });
        }
        emit ProposalCreated(msg.sender, account, target, value, data, info);
    }

    /// @dev Hash proposal ID from contents.
    function _hashProposalId(
        address account,
        address target,
        uint96 value,
        bytes calldata data,
        bytes32 info
    ) internal pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(account, target, value, data, info)));
    }

    /// @dev Casts vote on registered proposal. Reverts if non-existent.
    function vote(address account, uint256 propId, Vote action) public payable virtual {
        Proposal storage prop = props[propId];
        Settings storage set = settings[account];

        if (block.timestamp < prop.start) revert VotePending();
        if (block.timestamp > prop.end) revert VoteEnded();

        prop.yes += set.tkn == ITokenOwner(address(0))
            ? uint128(balanceOf(msg.sender, uint256(keccak256(abi.encodePacked(msg.sender)))))
            : set.std == TokenStandard.ERC20 || set.std == TokenStandard.ERC721
                ? uint128(ITokenOwner(set.tkn).balanceOf(msg.sender))
                : uint128(
                    ITokenOwner(set.tkn).balanceOf(
                        msg.sender, uint256(keccak256(abi.encodePacked(msg.sender)))
                    )
                );
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
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender)));
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

    /// @dev Sets new token metadata URI for the caller account.
    function setURI(string calldata uri) public payable virtual {
        emit URISet(msg.sender, (uris[uint256(keccak256(abi.encodePacked(msg.sender)))] = uri));
    }

    /// @dev Sets new token authority for the caller account.
    function setAuth(ITokenAuth auth) public payable virtual {
        emit AuthSet(msg.sender, (auths[uint256(keccak256(abi.encodePacked(msg.sender)))] = auth));
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
                            : set.tkn.totalSupply(uint256(keccak256(abi.encodePacked(msg.sender))))
                )
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
        if (auth != ITokenAuth(address(0))) {
            auths[id].canTransfer(from, to, id, amount);
        }
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
