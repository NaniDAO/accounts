// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/tokens/ERC20.sol";
import "@solady/src/utils/SafeTransferLib.sol";

/// @notice Simple Wrapped ERC4337 entry point implementation with paymaster functions.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/utils/NETH.sol)
/// @custom:version 0.0.0
contract NETH is ERC20 {
    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner.
    address internal immutable _OWNER;

    /// ======================= ERC20 METADATA ======================= ///

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return "Nani Ether";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return "NETH";
    }

    /// ========================= ENTRYPOINT ========================= ///

    /// @dev Returns the canonical ERC4337 EntryPoint contract.
    /// Override this function to return a different EntryPoint.
    function entryPoint() public view virtual returns (address) {
        return 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs this wrapper for delegated deposit functions.
    /// Additionally, sets owner account for peripheral concerns.
    constructor() payable {
        _OWNER = tx.origin;
    }

    /// ===================== DELEGATE SETTINGS ===================== ///

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

    /// ===================== DEPOSIT OPERATIONS ===================== ///

    /// @dev Deposits `msg.value` ETH of the caller and mints `msg.value` NETH to the caller.
    function deposit() public payable virtual {
        depositTo(msg.sender);
    }

    /// @dev Deposits `msg.value` ETH of the caller and mints `msg.value` NETH to the `to`.
    function depositTo(address to) public payable virtual {
        SafeTransferLib.safeTransferETH(entryPoint(), msg.value);
        _mint(to, msg.value);
    }

    /// ==================== WITHDRAW OPERATIONS ==================== ///

    /// @dev Burns `amount` NETH of the caller and sends `amount` ETH to the caller.
    function withdraw(uint256 amount) public virtual {
        withdrawFrom(msg.sender, msg.sender, amount);
    }

    /// @dev Burns `amount` NETH of the `from` and sends `amount` ETH to the `to`.
    function withdrawFrom(address from, address to, uint256 amount) public virtual {
        if (msg.sender != from) _spendAllowance(from, msg.sender, amount);
        address ep = entryPoint();
        _burn(from, amount);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x205c2878000000000000000000000000) // `withdrawTo(address,uint256)`.
            if iszero(mul(extcodesize(ep), call(gas(), ep, 0, 0x10, 0x44, codesize(), 0x00))) {
                returndatacopy(mload(0x40), 0x00, returndatasize())
                revert(mload(0x40), returndatasize())
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// ==================== FALLBACK OPERATIONS ==================== ///

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

    /// @dev Equivalent to `deposit()`.
    receive() external payable virtual {
        deposit();
    }
}
