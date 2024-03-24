// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";
import "@solady/test/utils/mocks/MockERC721.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {IAuth, Keys} from "../../src/ownership/Keys.sol";

contract MockAuth {
    function validateTransfer(address, address, uint256, uint256)
        public
        payable
        returns (uint256)
    {
        return 0;
    }

    function validateCall(address, address, uint256, bytes calldata)
        public
        payable
        returns (uint256)
    {
        return 0;
    }
}

contract KeysTest is Test {
    address internal alice;
    uint256 internal alicePk;

    address internal erc721;
    address internal mockAuth;

    NaniAccount internal account;
    Keys internal keys;

    address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function setUp() public payable {
        (alice, alicePk) = makeAddrAndKey("alice");

        // Etch something onto `_ENTRY_POINT` such that we can deploy the account implementation.
        vm.etch(_ENTRY_POINT, hex"00");
        account = NaniAccount(payable(address(LibClone.deployERC1967(address(new NaniAccount())))));
        account.initialize(alice);

        keys = new Keys();

        erc721 = address(new MockERC721());
        MockERC721(erc721).mint(alice, 0);

        mockAuth = address(new MockAuth());
    }

    function testDeploy() public payable {
        new Keys();
    }

    function testInstall() public payable {
        keys.install(erc721, 0, IAuth(address(0)));
        vm.prank(alice);
        account.transferOwnership(address(keys));
    }

    function testKeys() public payable {
        keys.install(erc721, 0, IAuth(address(0)));
        vm.prank(alice);
        account.transferOwnership(address(keys));
        bytes32 hash = _toEthSignedMessageHash(keccak256("So signed."));
        assertEq(keys.isValidSignature(hash, _sign(alicePk, hash)), keys.isValidSignature.selector);
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
