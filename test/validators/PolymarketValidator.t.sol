// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";

import {LibClone} from "@solady/src/utils/LibClone.sol";
import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import {Account as NaniAccount} from "../../src/Account.sol";
import {PolymarketValidator} from "../../src/validators/PolymarketValidator.sol";

contract PolymarketValidatorTest is Test {
    address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    NaniAccount internal account;
    PolymarketValidator internal validator;

    address internal owner;
    uint256 internal ownerKey;
    address internal bot1;
    uint256 internal bot1Key;
    address internal bot2;
    uint256 internal bot2Key;
    address internal unauthorized;
    uint256 internal unauthorizedKey;

    bytes32 internal constant MOCK_HASH = keccak256("polymarket-order-hash");

    function setUp() public {
        vm.etch(_ENTRY_POINT, hex"00");
        address impl = address(new NaniAccount());
        account = NaniAccount(payable(LibClone.deployERC1967(impl)));
        validator = new PolymarketValidator();

        (owner, ownerKey) = makeAddrAndKey("owner");
        (bot1, bot1Key) = makeAddrAndKey("bot1");
        (bot2, bot2Key) = makeAddrAndKey("bot2");
        (unauthorized, unauthorizedKey) = makeAddrAndKey("unauthorized");

        vm.deal(address(account), 1 ether);
        account.initialize(owner);
    }

    /// @dev Helper: install validator with signers and set the ERC-1271 plugin slot.
    function _installValidator(uint48 validAfter, uint48 validUntil, address[] memory signers)
        internal
    {
        ERC4337.Call[] memory calls = new ERC4337.Call[](2);
        calls[0] = ERC4337.Call(
            address(validator),
            0,
            abi.encodeCall(PolymarketValidator.install, (validAfter, validUntil, signers))
        );
        calls[1] = ERC4337.Call(
            address(account),
            0,
            abi.encodeCall(
                account.storageStore,
                (
                    bytes4(0x1626ba7e),
                    bytes32(bytes20(address(validator)))
                )
            )
        );
        vm.prank(owner);
        account.executeBatch(calls);
    }

    /// @dev Helper: sign a hash with a private key (raw ECDSA, r+s+v packed).
    function _sign(uint256 privateKey, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    // ========================= TESTS ========================= //

    function testDeploy() public {
        new PolymarketValidator();
    }

    function testInstall() public {
        address[] memory signers = new address[](2);
        signers[0] = bot1;
        signers[1] = bot2;

        _installValidator(0, 0, signers);

        (uint48 validAfter, uint48 validUntil, address[] memory storedSigners) =
            validator.getSettings(address(account));
        assertEq(validAfter, 0);
        assertEq(validUntil, 0);
        assertEq(storedSigners.length, 2);
        assertEq(storedSigners[0], bot1);
        assertEq(storedSigners[1], bot2);
    }

    function testInstallRevertNoSigners() public {
        address[] memory signers = new address[](0);
        vm.prank(owner);
        vm.expectRevert(PolymarketValidator.NoSigners.selector);
        account.execute(
            address(validator),
            0,
            abi.encodeCall(PolymarketValidator.install, (0, 0, signers))
        );
    }

    function testUninstall() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;
        _installValidator(0, 0, signers);

        // Uninstall.
        vm.prank(owner);
        account.execute(
            address(validator), 0, abi.encodeCall(PolymarketValidator.uninstall, ())
        );

        (, , address[] memory storedSigners) = validator.getSettings(address(account));
        assertEq(storedSigners.length, 0);
    }

    function testBotSignerValid() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;
        _installValidator(0, 0, signers);

        bytes memory sig = _sign(bot1Key, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, sig);
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testBotSignerUnauthorized() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;
        _installValidator(0, 0, signers);

        bytes memory sig = _sign(unauthorizedKey, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, sig);
        assertEq(result, bytes4(0xffffffff));
    }

    function testOwnerFallback() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;
        _installValidator(0, 0, signers);

        // Owner signs the hash directly (raw ECDSA).
        bytes memory sig = _sign(ownerKey, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, sig);
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testTimeWindowBefore() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;

        // validAfter = 1000, current timestamp = 1 (before window).
        vm.warp(1);
        _installValidator(1000, 2000, signers);

        // Bot sig should fail (outside time window).
        bytes memory botSig = _sign(bot1Key, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, botSig);
        // Owner fallback should still pass.
        bytes memory ownerSig = _sign(ownerKey, MOCK_HASH);
        bytes4 ownerResult = account.isValidSignature(MOCK_HASH, ownerSig);

        assertEq(result, bytes4(0xffffffff));
        assertEq(ownerResult, bytes4(0x1626ba7e));
    }

    function testTimeWindowExpired() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;

        _installValidator(100, 200, signers);
        vm.warp(300); // After validUntil.

        // Bot sig should fail (expired).
        bytes memory botSig = _sign(bot1Key, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, botSig);
        // Owner fallback should still pass.
        bytes memory ownerSig = _sign(ownerKey, MOCK_HASH);
        bytes4 ownerResult = account.isValidSignature(MOCK_HASH, ownerSig);

        assertEq(result, bytes4(0xffffffff));
        assertEq(ownerResult, bytes4(0x1626ba7e));
    }

    function testTimeWindowValid() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;

        _installValidator(100, 200, signers);
        vm.warp(150); // Within window.

        bytes memory sig = _sign(bot1Key, MOCK_HASH);
        bytes4 result = account.isValidSignature(MOCK_HASH, sig);
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testMultipleSigners() public {
        address[] memory signers = new address[](2);
        signers[0] = bot1;
        signers[1] = bot2;
        _installValidator(0, 0, signers);

        // Both bots can sign.
        bytes memory sig1 = _sign(bot1Key, MOCK_HASH);
        bytes4 result1 = account.isValidSignature(MOCK_HASH, sig1);
        assertEq(result1, bytes4(0x1626ba7e));

        bytes memory sig2 = _sign(bot2Key, MOCK_HASH);
        bytes4 result2 = account.isValidSignature(MOCK_HASH, sig2);
        assertEq(result2, bytes4(0x1626ba7e));
    }

    function testSetSigners() public {
        address[] memory signers = new address[](1);
        signers[0] = bot1;
        _installValidator(0, 0, signers);

        // Verify bot1 works.
        bytes memory sig1 = _sign(bot1Key, MOCK_HASH);
        assertEq(account.isValidSignature(MOCK_HASH, sig1), bytes4(0x1626ba7e));

        // Update signers to bot2 only.
        address[] memory newSigners = new address[](1);
        newSigners[0] = bot2;
        vm.prank(owner);
        account.execute(
            address(validator),
            0,
            abi.encodeCall(PolymarketValidator.setSigners, (0, 0, newSigners))
        );

        // Old signer (bot1) should fail.
        assertEq(account.isValidSignature(MOCK_HASH, sig1), bytes4(0xffffffff));

        // New signer (bot2) should pass.
        bytes memory sig2 = _sign(bot2Key, MOCK_HASH);
        assertEq(account.isValidSignature(MOCK_HASH, sig2), bytes4(0x1626ba7e));
    }

    function testGetSigners() public {
        address[] memory signers = new address[](2);
        signers[0] = bot1;
        signers[1] = bot2;
        _installValidator(0, 0, signers);

        address[] memory result = validator.getSigners(address(account));
        assertEq(result.length, 2);
        assertEq(result[0], bot1);
        assertEq(result[1], bot2);
    }
}
