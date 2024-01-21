// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {ERC721} from "@solady/src/tokens/ERC721.sol";

/// @dev A simple NFT contract for stringly worded IDs.
contract Words is ERC721 {
    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// ======================== MINT & BURN ======================== ///

    /// @dev Open mint function to claim public chain `word` for `to`.
    function mint(address to, string calldata word) public payable virtual {
        _mint(to, uint256(keccak256(bytes(word))));
    }

    /// @dev Open burn function to unclaim public chain `word`.
    function burn(string calldata word) public payable virtual {
        _burn(msg.sender, uint256(keccak256(bytes(word))));
    }

    /// ====================== ERC721 METADATA ====================== ///

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return "Words";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return unicode"言";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string(abi.encodePacked(id));
    }
}
