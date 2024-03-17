// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/// @notice Simple summoner for Nani (𒀭) token-bound accounts.
/// @custom:version 0.0.0
contract Keysmith {
    address internal constant KEYS = 0x000000000000082ffb07deF3DdfB5D3AFA9b9668;
    IAccounts internal constant FACTORY = IAccounts(0x000000000000dD366cc2E4432bB998e41DFD47C7);

    constructor() payable {}

    function summon(address nft, uint256 id, bytes12 salt) public payable returns (IAccounts account) {
        account = IAccounts(FACTORY.createAccount{value: msg.value}(address(this), bytes32(abi.encodePacked(this, salt))));
        account.execute(KEYS, 0, abi.encodeWithSignature("install(address,uint256,address)", nft, id, address(0)));
        account.execute(address(account), 0, abi.encodeWithSignature("transferOwnership(address)", KEYS));
    }
}

/// @dev Simple interface for Nani (𒀭) user account creation and setup.
interface IAccounts {
    function createAccount(address, bytes32) external payable returns (address);
    function execute(address, uint256, bytes calldata) external payable returns (bytes memory);
}
