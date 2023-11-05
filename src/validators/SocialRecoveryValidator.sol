// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

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
        public
        payable
        virtual
        returns (uint256 validationData)
    {
        address account = userOp.sender;
        if (msg.sender != account) revert Unauthorized();
        bytes[] memory sigs = _splitSigs(userOp.signature);
        // The signatures need to be in the order of the guardians.
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < sigs.length;) {
            address guard = guardians[account][i];
            if (!SignatureCheckerLib.isValidSignatureNow(guard, hash, sigs[i])) {
                return 1; // `validationData` is `0` on success, `1` on failure.
            }
            unchecked {
                ++i;
            }
        }
        uninstall();
    }

    function _splitSigs(bytes calldata sig) internal pure virtual returns (bytes[] memory sigs) {
        unchecked {
            if (sig.length % 65 != 0) revert Unauthorized();
            sigs = new bytes[](sig.length / 65);
            uint256 pos;
            for (uint256 i; i < sig.length;) {
                sigs[i] = sig[pos:65];
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
