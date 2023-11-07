// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {ERC4337Factory} from "@solady/src/accounts/ERC4337Factory.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/nanidao/account/blob/main/src/AccountFactory.sol)
contract AccountFactory is Ownable, ERC4337Factory {
    /// @dev Constructs this factory to deploy the implementation.
    constructor(address erc4337) payable ERC4337Factory(erc4337) {
        _setOwner(tx.origin);
    }

    /// @dev Execute a call from this factory for staking operations.
    function execute(address target, uint256 value, bytes calldata data)
        public
        payable
        virtual
        onlyOwner
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, data.offset, data.length)
            if iszero(call(gas(), target, value, result, data.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }
}
