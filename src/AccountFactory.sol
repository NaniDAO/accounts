// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibClone} from "@solady/src/utils/LibClone.sol";

/// @notice Simple extendable smart account factory implementation.
/// @author nani.eth (https://github.com/nanidao/account/blob/main/src/AccountFactory.sol)
/// @author Modified from Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC4337Factory.sol)
contract AccountFactory {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         IMMUTABLES                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Address of the Account implementation.
    address internal immutable implementation;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(address account) payable {
        implementation = account;
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
}
