// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple deadline (dead man's switch) validator for smart accounts.
contract DeadlineValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new guardians of an account.
    event GuardiansSet(address indexed account, address[] guardians);

    /// @dev Logs the new deadline of an account.
    event DeadlineSet(address indexed account, uint256 deadline);

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
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Stores mappings of guardians to accounts.
    mapping(address => address[]) internal _guardians;

    /// @dev Stores mappings of deadlines to accounts.
    mapping(address => uint256) internal _deadlines;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

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
        bool success;
        address[] memory guardians = _guardians[msg.sender];
        bool validAfter = block.timestamp > _deadlines[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < guardians.length;) {
            success = SignatureCheckerLib.isValidSignatureNowCalldata(
                guardians[i], hash, userOp.signature
            );
            if (success) break;
            unchecked {
                ++i;
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            validationData := iszero(and(success, validAfter))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GUARDIAN OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the guardians of an account.
    function guardiansOf(address account) public view virtual returns (address[] memory) {
        return _guardians[account];
    }

    /// @dev Sets the new guardians of an account.
    function setGuardians(address[] calldata newGuardians) public payable virtual {
        LibSort.sort(newGuardians);
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = newGuardians);
    }

    /// @dev Sets the guardian validation deadline of an account.
    function setDeadline(uint256 deadline) public payable virtual {
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = deadline);
    }

    /// @dev Installs the new guardians of an account from `data`,
    /// as well as sets the deadline from which guardians validate.
    function install(bytes calldata data) public payable virtual {
        (address[] memory newGuardians, uint256 deadline) = abi.decode(data, (address[], uint256));
        LibSort.sort(newGuardians);
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = deadline);
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = newGuardians);
    }

    /// @dev Uninstalls the guardians and deadline of an account.
    function uninstall(bytes calldata) public payable virtual {
        delete _deadlines[msg.sender];
        delete _guardians[msg.sender];
        emit DeadlineSet(msg.sender, 0);
        emit GuardiansSet(msg.sender, new address[](0));
    }
}
