// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337Factory} from "@solady/src/accounts/ERC4337Factory.sol";

/// @notice Simple extendable smart account factory. ERC1271/ERC4337. Version 1.2.3.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Accounts.sol)
contract Accounts is ERC4337Factory {
    constructor(address Account) payable ERC4337Factory(Account) {}
}
