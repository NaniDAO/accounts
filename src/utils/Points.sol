// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/// @notice Simple onchain points allocation protocol.
/// @custom:version 0.0.0
contract Points {
    address public immutable owner; // Signatory.
    uint256 public immutable rate; // Issuance.
    mapping(address => uint256) public claimed;

    constructor(address _owner, uint8 _rate) payable {
        owner = Points(_owner).owner();
        rate = _rate;
    }

    function check(address user, uint256 start, uint256 bonus, bytes calldata signature)
        public
        view
        returns (uint256 score)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }
        if (
            owner
                == ecrecover(
                    _toEthSignedMessageHash(keccak256((abi.encodePacked(user, start, bonus)))), v, r, s
                )
        ) score = (bonus + (rate * (block.timestamp - start))) - claimed[user];
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

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}
