// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";
import "@forge/Test.sol";

contract SocialRecoveryValidator {
    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The array has an invalid length in context.
    error ArrayLengthsMismatch();

    /// @dev No guardians are set for the account.
    error NoGuardiansSet();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC4337 user operation (userOp) struct.
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event GuardiansSet(address indexed account, address[] guardians);

    event ThresholdSet(address indexed account, uint256 threshold);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         STORAGE                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    mapping(address => address[]) internal guardians;

    mapping(address => uint256) public thresholds;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   VALIDATION OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Validates ERC4337 userOp with additional auth logic flow among guardians.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        console.log("SocialRecoveryValidator.validateUserOp");
        address account = userOp.sender;
        console.log(account);
        if (msg.sender != account) revert Unauthorized();
        console.log("msg.sender == account");
        bytes[] memory sigs = _splitSigs(userOp.signature);
        console.log("sigs.length");
        console.log(sigs.length);

        // The signatures need to be in the order of the guardians.
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < sigs.length;) {
            console.log("i", i);
            address guard = guardians[account][i];
            console.log("guard", guard);

            if (!SignatureCheckerLib.isValidSignatureNow(guard, hash, sigs[i])) {
                console.log("invalid sig");
                return 1; // `validationData` is `0` on success, `1` on failure.
            }

            unchecked {
                ++i;
            }
        }

        uninstall();
    }

    function _splitSigs(bytes calldata sig) internal view virtual returns (bytes[] memory sigs) {
        unchecked {
            if (sig.length % 65 != 0) revert Unauthorized();
            console.log("sig.length");
            console.log(sig.length);
            sigs = new bytes[](sig.length / 65);
            console.log("sigs.length");
            console.log(sigs.length);
            uint256 pos;
            console.log("looping", sig.length / 65);
            for (uint256 i; i < sig.length / 65;) {
                console.log("i", i);
                console.log("pos", pos);
                sigs[i] = sig[pos:pos + 65];
                console.log("sigs[i]");
                console.logBytes(sigs[i]);
                pos += 65;
                ++i;
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     GUARDIAN OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getGuardians(address account) public view virtual returns (address[] memory) {
        return guardians[account];
    }

    function setGuardians(address[] calldata newGuardians) public payable virtual {
        if (thresholds[msg.sender] > newGuardians.length) revert ArrayLengthsMismatch();
        emit GuardiansSet(msg.sender, guardians[msg.sender] = newGuardians);
    }

    function setThreshold(uint256 threshold) public payable virtual {
        if (threshold > guardians[msg.sender].length) revert ArrayLengthsMismatch();
        emit ThresholdSet(msg.sender, thresholds[msg.sender] = threshold);
    }

    function install(address[] calldata newGuardians, uint256 threshold) public payable virtual {
        setGuardians(newGuardians);
        setThreshold(threshold);
    }

    function uninstall() public payable virtual {
        delete guardians[msg.sender];
        emit GuardiansSet(msg.sender, new address[](0));
        delete thresholds[msg.sender];
        emit ThresholdSet(msg.sender, 0);
    }
}
