// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {ITokenOwner, ITokenAuth, Owners} from "../../src/ownership/Owners.sol";
import {Account as NaniAccount} from "../../src/Account.sol";

contract OwnersTest is Test {
    address internal alice;
    uint256 internal alicePk;

    NaniAccount internal account;

    Owners internal owners;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        account = new NaniAccount();
        account.initialize(alice);
        owners = new Owners();
    }

    function testDeploy() public {
        owners = new Owners();
    }

    function testInstall() public {
        address[] memory _owners = new address[](1);
        uint256[] memory _shares = new uint256[](1);
        _owners[0] = alice;
        _shares[0] = 1;

        ITokenOwner tkn = ITokenOwner(address(0));
        Owners.TokenStandard std = Owners.TokenStandard.OWN;

        uint88 threshold = 1;
        string memory uri = "";
        ITokenAuth auth = ITokenAuth(address(0));

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector, _owners, _shares, tkn, std, threshold, uri, auth
            )
        );

        assertEq(account.ownershipHandoverExpiresAt(address(owners)), block.timestamp + 2 days);

        uint256 accountId = uint256(keccak256(abi.encodePacked(address(account))));

        assertEq(owners.balanceOf(alice, accountId), 1);

        (ITokenOwner setTkn, uint88 setThreshold, Owners.TokenStandard setStd) =
            owners.settings(address(account));

        assertEq(address(setTkn), address(tkn));
        assertEq(uint256(setThreshold), uint256(threshold));
        assertEq(uint8(setStd), uint8(std));

        assertEq(owners.uris(accountId), "");
        assertEq(address(owners.auths(accountId)), address(0));
    }
}
