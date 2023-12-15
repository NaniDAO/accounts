// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/// @notice Simple onchain points allocation protocol.
contract Points {
    address internal immutable OWNER; // Signatory.
    uint256 internal immutable RATE; // Issuance.
    mapping(address => uint256) public claimed;

    constructor(address owner, uint8 rate) payable {
        OWNER = owner;
        RATE = rate;
    }

    function check(address user, uint256 start, uint256 bonus, bytes calldata signature)
        public
        view
        returns (uint256 score)
    {
        // Parse user starting points and bonus with owner's signature.
        bytes32 hash = keccak256((abi.encodePacked(user, start, bonus)));
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }
        if (IERC1271.isValidSignature.selector == IERC1271(OWNER).isValidSignature(hash, signature))
        {
            score = (bonus + (RATE * (block.timestamp - start))) - claimed[user];
        }
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
