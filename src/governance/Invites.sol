// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC721} from "@solady/src/tokens/ERC721.sol";

/// @notice Simple NFT contract for sending out custom invites.
contract Invites is ERC721 {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The time delay is still pending from the last mint.
    error DelayPending();

    /// ========================= CONSTANTS ========================= ///

    /// @dev Timed delay set for each mint.
    uint256 public constant delay = 1 hours;

    /// ========================== STORAGE ========================== ///

    /// @dev Internal token ID metadata mapping.
    mapping(uint256 id => string metadata) internal _uris;

    /// @dev Timestamp for each user's last invitation sent.
    mapping(address user => uint256 timestamp) public lastSent;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {
        _mint(tx.origin, 0);
    }

    /// ============================ MINT ============================ ///

    /// @dev Sends out invite NFT for `to` with `message` and `uri`.
    /// If not the owner (0) account, `msg.sender` must have NFT,
    /// as well as pass the timed delay after their first mint.
    function invite(address to, string calldata message, string calldata uri)
        public
        payable
        virtual
    {
        unchecked {
            if (msg.sender != ownerOf(0) && balanceOf(msg.sender) == 0) {
                revert Unauthorized();
            }
            if (block.timestamp < (lastSent[msg.sender] + delay)) {
                revert DelayPending();
            }
            uint256 tokenId = uint256(keccak256(bytes(message)));
            _uris[tokenId] = uri;
            _mint(to, tokenId);
        }
    }

    /// ====================== ERC721 METADATA ====================== ///

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return "Invites";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return unicode"💌";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return _uris[id];
    }
}
