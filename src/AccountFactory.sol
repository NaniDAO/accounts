// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {LibClone} from "@solady/src/utils/LibClone.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/nanidao/account/blob/main/src/AccountFactory.sol)
/// @author ERC4337Factory by Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC4337Factory.sol)
contract AccountFactory is Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         IMMUTABLES                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Address of the Account implementation.
    address public immutable implementation;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(address account) payable {
        implementation = account;
        _setOwner(tx.origin);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        ENTRY POINT                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the canonical ERC4337 EntryPoint contract.
    /// Override this function to return a different EntryPoint.
    function entryPoint() public view virtual returns (address) {
        return 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPLOY FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys an Account with `salt` and returns its deterministic address.
    /// If the Account is already deployed, it will simply return its address.
    /// Any `msg.value` will simply be forwarded to the Account, regardless.
    function createAccount(address owner, bytes32 salt) public payable virtual returns (address) {
        // Check that the salt is tied to the owner if required, regardless.
        LibClone.checkStartsWith(salt, owner);
        // Constructor data is optional, and is omitted for easier Etherscan verification.
        (bool alreadyDeployed, address account) =
            LibClone.createDeterministicERC1967(msg.value, implementation, salt);

        if (!alreadyDeployed) {
            /// @solidity memory-safe-assembly
            assembly {
                mstore(0x14, owner) // Store the `owner` argument.
                mstore(0x00, 0xc4d66de8000000000000000000000000) // `initialize(address)`.
                if iszero(call(gas(), account, 0, 0x10, 0x24, codesize(), 0x00)) {
                    returndatacopy(mload(0x40), 0x00, returndatasize())
                    revert(mload(0x40), returndatasize())
                }
            }
        }
        return account;
    }

    /// @dev Returns the deterministic address of the Account created via `createAccount`.
    function getAddress(bytes32 salt) public view virtual returns (address) {
        return LibClone.predictDeterministicAddressERC1967(implementation, salt, address(this));
    }

    /// @dev Returns the initialization code hash of the Account (a minimal ERC1967 proxy).
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash() public view virtual returns (bytes32) {
        return LibClone.initCodeHashERC1967(implementation);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DEPOSIT OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the account's balance on the EntryPoint.
    function getDeposit() public view virtual returns (uint256 result) {
        address ep = entryPoint();
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, address()) // Store the `account` argument.
            mstore(0x00, 0x70a08231) // `balanceOf(address)`.
            result :=
                mul( // Returns 0 if the EntryPoint does not exist.
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), ep, 0x1c, 0x24, 0x20, 0x20)
                    )
                )
        }
    }

    /// @dev Deposit more funds for this account in the EntryPoint.
    function addDeposit() public payable virtual {
        address ep = entryPoint();
        /// @solidity memory-safe-assembly
        assembly {
            // The EntryPoint has balance accounting logic in the `receive()` function.
            // forgefmt: disable-next-item
            if iszero(mul(extcodesize(ep), call(gas(), ep, callvalue(), codesize(), 0x00, codesize(), 0x00))) {
                revert(codesize(), 0x00) // For gas estimation.
            }
        }
    }

    /// @dev Withdraw ETH from the account's deposit on the EntryPoint.
    function withdrawDepositTo(address to, uint256 amount) public payable virtual onlyOwner {
        address ep = entryPoint();
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
}
