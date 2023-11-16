// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/// @notice Simple Wrapped ether (wETH) optimized for extended yield and paymaster functions.
/// @author nani.eth (https://github.com/nanidao/accounts/blob/main/src/periphery/NETH.sol)
contract NETH {
    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner.
    address internal immutable _OWNER;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs this wrapper for delegated deposit functions.
    /// Additionally, sets owner account for peripheral concerns.
    constructor() payable {
        _OWNER = msg.sender;
    }

    /// ================== DELEGATE OPERATIONS ==================== ///

    /// @dev Tracks mappings of peripheral call concerns delegated by the owner.
    function delegates(bytes4 selector) public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(selector)
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
    fallback() external payable virtual {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            // Forwards the calldata to `executor` via delegatecall.
            if iszero(
                delegatecall(
                    gas(),
                    /*executor*/
                    sload( /*selector*/ shr(224, calldataload(0))),
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
