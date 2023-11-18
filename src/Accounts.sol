// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337Factory} from "@solady/src/accounts/ERC4337Factory.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Accounts.sol)
contract Accounts is ERC4337Factory {
    /// @dev Holds an immutable owner.
    address internal immutable _OWNER;

    /// @dev Constructs this factory to deploy the implementation.
    /// Additionally, sets owner account for peripheral concerns.
    constructor(address erc4337) payable ERC4337Factory(erc4337) {
        _OWNER = createAccount(tx.origin, bytes32(0));
    }

    /// @dev Tracks mappings of selectors to executors the owner has delegated to.
    function get(bytes4 selector) public view virtual returns (address executor) {
        /// @solidity memory-safe-assembly
        assembly {
            executor := sload(selector)
        }
    }

    /// @dev Delegates peripheral call concerns. Can only be called by owner.
    function set(bytes4 selector, address executor) public payable virtual {
        assert(msg.sender == _OWNER);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(selector, executor)
        }
    }

    /// @dev Falls back to delegated calls.
    fallback() external payable {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            // Forwards the calldata to `executor` via delegatecall.
            if iszero(
                delegatecall(
                    gas(),
                    /*executor*/
                    sload( /*selector*/ shl(224, shr(224, calldataload(0)))),
                    0x00,
                    calldatasize(),
                    codesize(),
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
