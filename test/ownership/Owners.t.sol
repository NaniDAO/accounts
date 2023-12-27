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

    function testIsValidSignature() public {
        /*address[] memory _owners = new address[](1);
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

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        bytes32 userOpHash = keccak256("OWN");
        bytes memory userOpSignature = _sign(alicePk, _toEthSignedMessageHash(userOpHash));
        bytes memory signature = abi.encodePacked(alice, userOpSignature);

        vm.prank(address(account));
        bytes4 result = owners.isValidSignature(userOpHash, signature);
        assert(result == Owners.isValidSignature.selector);*/
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }

    function _sign(uint256 pK, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pK, hash);
        return abi.encodePacked(r, s, v);
    }
}
