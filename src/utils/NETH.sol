// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/tokens/ERC20.sol";
import "@solady/src/utils/SafeTransferLib.sol";

/// @notice Simple wrapped ERC4337 implementation with paymaster and yield functions.
/// @dev The strategy for ether (ETH) deposits defaults to Lido but can be overridden.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/utils/NETH.sol)
/// @custom:version 0.0.0
contract NETH is Ownable, ERC20 {
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
    function entryPoint() public view virtual returns (address payable) {
        return payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    }

    /// ========================== STRATEGY ========================== ///

    /// @dev Returns the canonical ETH strategy contract (Lido).
    /// Override this function to return a different strategy.
    function strategy() public view virtual returns (address payable) {
        return payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    /// Owned by tx origin.
    constructor() payable {
        _setOwner(tx.origin);
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

    /// ===================== STAKING OPERATIONS ===================== ///

    /// @dev Add stake for this paymaster. Further sets a staking delay timestamp.
    function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner {
        NETH(entryPoint()).addStake{value: msg.value}(unstakeDelaySec);
    }

    /// @dev Unlock the stake, in order to withdraw it.
    function unlockStake() public payable virtual onlyOwner {
        NETH(entryPoint()).unlockStake();
    }

    /// @dev Withdraw the entire paymaster's stake. Can select a recipient of this withdrawal.
    function withdrawStake(address payable withdrawAddress) public payable virtual onlyOwner {
        NETH(entryPoint()).withdrawStake(withdrawAddress);
    }

    /// ==================== FALLBACK OPERATIONS ==================== ///

    /// @dev Equivalent to `deposit()`.
    receive() external payable virtual {
        deposit();
    }
}
