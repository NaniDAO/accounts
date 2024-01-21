// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {Ownable} from "@solady/src/

/// @dev A simple NFT contract for stringly worded IDs.
contract Invite is ERC721, Ownable {
    /// ========================== STORAGE ========================== ///
    mapping(uint256 => string) public uri;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// ======================== MINT & BURN ======================== ///

    /// @dev Closed mint function to mint invite with `message`
    function mint(address to, string calldata message, string uri) public payable virtual {
        uint256 tokenId = uint256(keccak256(bytes(message)));
        _mint(to,tokenId);
        uri[tokenId] = uri;
    }

    /// @dev Closed burn function to burn invite with `message`
    function burn(address to, uint256 id) public payable virtual {
        _burn(id);
    }

    /// ====================== ERC721 METADATA ====================== ///

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return "Invite";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return unicode"💌";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return uri[id];
    }
}
