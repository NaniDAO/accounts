// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337Factory} from "@solady/src/accounts/ERC4337Factory.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/nanidao/accounts/blob/main/src/Accounts.sol)
contract Accounts is ERC4337Factory {
    /// @dev Holds an immutable owner.
    address internal immutable _OWNER;

    /// @dev Stores mappings of selectors to delegates.
    mapping(bytes4 => address) internal _delegates;

    /// @dev Constructs this factory to deploy the implementation.
    /// Additionally, sets owner account for peripheral concerns.
    constructor(address erc4337) payable ERC4337Factory(erc4337) {
        _OWNER = ERC4337Factory.createAccount(tx.origin, 0);
    }

    /// @dev Executes a call from this factory for peripheral concerns.
    function execute(address target, uint256 value, bytes calldata data)
        public
        payable
        virtual
        returns (bytes memory result)
    {
        // Only the owner can call.
        assert(msg.sender == _OWNER);
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

    /// @dev Sets delegate for peripheral concerns. Can only be called by the owner.
    function setDelegate(bytes4 selector, address delegate) public payable virtual {
        assert(msg.sender == _OWNER);
        _delegates[selector] = delegate;
    }

    /// @dev Falls back to delegated peripherals.
    fallback() external payable virtual {
        address delegate = _delegates[msg.sig];
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            // Forwards the calldata to `delegate` via delegatecall.
            if iszero(delegatecall(gas(), delegate, 0x00, calldatasize(), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            returndatacopy(0x00, 0x00, returndatasize()) // Copy the returndata.
            return(0x00, returndatasize())
        }
    }
}
