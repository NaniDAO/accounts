// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337Factory} from "@solady/src/accounts/ERC4337Factory.sol";
import "@forge/Test.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/nanidao/accounts/blob/main/src/Accounts.sol)
contract Accounts is ERC4337Factory {
    /// @dev Holds an immutable owner.
    address internal immutable _OWNER;

    /// @dev Constructs this factory to deploy the implementation.
    /// Additionally, sets owner account for peripheral concerns.
    constructor(address erc4337, bytes32 salt) payable ERC4337Factory(erc4337) {
        _OWNER = createAccount(tx.origin, salt);
    }

    /// @dev Tracks mappings of peripheral call executors the owner has delegated to.
    function get(bytes4 selector) public view virtual returns (address executor) {
        /// @solidity memory-safe-assembly
        assembly {
            executor := sload(selector)
        }
    }

    /// @dev Delegates peripheral call concerns. Can only be called by the owner.
    function delegate(bytes4 selector, address executor) public payable virtual {
        assert(msg.sender == _OWNER);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(selector, executor)
        }
    }

    /// @dev Falls back to delegated calls.
    fallback(bytes calldata) external returns (bytes memory) {
        // @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, 0x04)
            calldatacopy(0x20, 0x00, calldatasize())
            // Forwards the calldata to `executor` via delegatecall.
            if iszero(
                delegatecall(
                    gas(),
                    /*executor*/
                    sload(/*selector*/calldataload(0x00)),
                    0x20,
                    calldatasize(),
                    0,
                    0x00
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            // Copy and return data from successful call.
            returndatacopy(0x00, 0x00, returndatasize())
            return(0x00, returndatasize())
        }
    }
}
