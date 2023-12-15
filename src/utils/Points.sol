// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/// @notice Simple onchain points allocation protocol.
/// @custom:version 0.0.0
contract Points {
    address internal immutable _OWNER; // Signatory.
    uint256 internal immutable _RATE; // Issuance.
    mapping(address => uint256) public claimed;

    constructor(address owner, uint8 rate) payable {
        _OWNER = owner;
        _RATE = rate;
    }

    function check(address user, uint256 start, uint256 bonus, bytes calldata signature)
        public
        view
        returns (uint256 score)
    {
        if (
            IERC1271.isValidSignature.selector
                == IERC1271(_OWNER).isValidSignature(
                    keccak256((abi.encodePacked(user, start, bonus))), signature
                )
        ) score = (bonus + (_RATE * (block.timestamp - start))) - claimed[user];
    }

    function claim(IERC20 token, uint256 start, uint256 bonus, bytes calldata signature)
        public
        payable
    {
        unchecked {
            token.transfer(
                msg.sender, claimed[msg.sender] += check(msg.sender, start, bonus, signature)
            );
        }
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}

interface IERC1271 {
    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4);
}
