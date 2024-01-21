// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Base64} from "@solady/src/utils/Base64.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {LibString} from "@solady/src/utils/LibString.sol";

/// @notice Simple NFT contract for sending out custom invites.
contract Invites is ERC721 {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The time delay is still pending from the last mint.
    error DelayPending();

    /// @dev The `message` exceeds the 20 character limit.
    error MessageTooLong();

    /// ========================= CONSTANTS ========================= ///

    /// @dev Timed delay set for each mint.
    uint256 public constant delay = 1 hours;

    /// ========================== STORAGE ========================== ///

    /// @dev Message for each invite.
    mapping(uint256 id => string message) public messages;

    /// @dev Timestamp for each user's last invitation sent.
    mapping(address user => uint256 timestamp) public lastSent;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {
        _mint(tx.origin, 0);
    }

    /// ============================ MINT ============================ ///

    /// @dev Sends out invite NFT for `to` with `message`.
    /// If not owner (0) account, `msg.sender` must have NFT,
    /// as well as pass the timed delay after their first mint.
    function invite(address to, string calldata message) public payable virtual {
        if (msg.sender != ownerOf(0)) {
            if (balanceOf(msg.sender) == 0) {
                revert Unauthorized();
            }
            unchecked {
                if (block.timestamp < (lastSent[msg.sender] + delay)) {
                    revert DelayPending();
                }
            }
            lastSent[msg.sender] = block.timestamp;
        }
        if (bytes(message).length > 20) {
            revert MessageTooLong();
        }
        uint256 id = uint256(keccak256(bytes(message)));
        messages[id] = message;
        _mint(to, id);
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
        return _createURI(id);
    }

    /// @dev Creates the URI for token `id`.
    function _createURI(uint256 id) internal view virtual returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            LibString.concat(unicode"💌", " Invite"),
                            '","description":"You are cordially invited to alpha test NANI."',
                            ',"image":"',
                            _createImage(id),
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function _createImage(uint256 id) internal view virtual returns (string memory) {
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="101%" height="101%"/><text x="51%" y="21%" dominant-baseline="middle" text-anchor="middle" font-size="6" font-family="\'Courier New\', monospace" fill="#fff">',
                            unicode"ｊｏｉｎ ｕｓ ((¯͒ . ¯͒))",
                            '</text><text x="50%" y="35%" dominant-baseline="middle" text-anchor="middle" font-size="4" font-family="\'Courier New\', monospace" fill="#fff">',
                            unicode"ｆｏｒ ａｌｐｈａ ｔｅｓｔｉｎｇ",
                            '</text><text x="50%" y="60%" dominant-baseline="middle" text-anchor="middle" font-size="15" font-family="\'Courier New\', monospace" fill="#fff">',
                            unicode"【ｎａｎｉ】",
                            '</text><text x="50%" y="80%" dominant-baseline="middle" text-anchor="middle" font-size="4" font-style="italic" font-family="\'Courier New\', monospace" fill="#fff">"',
                            messages[id],
                            '"</text><text x="50%" y="5%" dominant-baseline="start" text-anchor="middle" font-size="3" fill="yellow">',
                            unicode"【⌘】░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░【⌘】",
                            '</text><text x="50%" y="97%" dominant-baseline="start" text-anchor="middle" font-size="3" fill="yellow">',
                            unicode"【⌘】░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░-░【⌘】",
                            '</text><text x="5%" y="10%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="15%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="20%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="25%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="30%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="35%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="40%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="45%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="55%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="60%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="65%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="70%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="75%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="80%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="85%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="5%" y="90%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="10%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="15%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="20%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="25%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="30%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="35%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="40%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="45%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="55%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="60%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="65%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="70%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="75%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="80%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="85%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            '</text><text x="95%" y="90%" dominant-baseline="middle" text-anchor="middle" font-size="3" fill="#fff">',
                            unicode"░",
                            "</text></svg>"
                        )
                    )
                )
            )
        );
    }
}
