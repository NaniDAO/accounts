// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple deadline (dead man's switch) validator for smart accounts.
contract DeadlineValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new deadline of an account.
    event DeadlineSet(address indexed account, uint256 deadline);

    /// @dev Logs the new guardians of an account.
    event GuardiansSet(address indexed account, address[] guardians);

    /// @dev Logs the new userOpHash of an account.
    event UserOpHashSet(address indexed account, bytes32 userOpHash);

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

    /// @dev Stores mappings of deadlines to accounts.
    mapping(address => uint256) internal _deadlines;

    /// @dev Stores mappings of guardians to accounts.
    mapping(address => address[]) internal _guardians;

    /// @dev Stores mappings of userOpHash(es) to accounts.
    mapping(address => bytes32) internal _userOpHashes;

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
        uint256 deadline = _deadlines[msg.sender];
        address[] memory guardians = _guardians[msg.sender];
        bool validAfter = (block.timestamp > deadline) && (deadline != 0);
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
        // If a guardian validated `userOp` and `userOpHash` is stored
        // for the caller, assert and check this matches the validated.
        // This effectively allows this deadline validator to ensure
        // that only an account's countersigned userOp can execute.
        if (validationData == 0) {
            if (_userOpHashes[msg.sender] != "") {
                assert(userOpHash == _userOpHashes[msg.sender]);
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GUARDIAN OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the guardian validation deadline of an account.
    function deadlineOf(address account) public view virtual returns (uint256) {
        return _deadlines[account];
    }

    /// @dev Returns the guardians of an account.
    function guardiansOf(address account) public view virtual returns (address[] memory) {
        return _guardians[account];
    }

    /// @dev Returns the userOpHash of an account.
    function userOpHashOf(address account) public view virtual returns (bytes32) {
        return _userOpHashes[account];
    }

    /// @dev Sets the new guardian validation deadline of an account.
    function setDeadline(uint256 deadline) public payable virtual {
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = deadline);
    }

    /// @dev Sets the new guardians of an account.
    function setGuardians(address[] calldata guardians) public payable virtual {
        LibSort.sort(guardians);
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = guardians);
    }

    /// @dev Sets the new userOpHash of an account.
    function setUserOpHash(bytes32 userOpHash) public payable virtual {
        emit UserOpHashSet(msg.sender, _userOpHashes[msg.sender] = userOpHash);
    }

    /// @dev Installs the new guardians of an account from `data`,
    /// sets the deadline from which guardians validate, as well as
    /// an optional userOpHash to limit such validation operations.
    function install(bytes calldata data) public payable virtual {
        (uint256 deadline, bytes32 userOpHash, address[] memory guardians) =
            abi.decode(data, (uint256, bytes32, address[]));
        LibSort.sort(guardians);
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = deadline);
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = guardians);
        emit UserOpHashSet(msg.sender, _userOpHashes[msg.sender] = userOpHash);
    }

    /// @dev Uninstalls the guardians, deadline and userOpHash
    /// of an account such that deadline validation will revert.
    function uninstall(bytes calldata) public payable virtual {
        emit DeadlineSet(msg.sender, _deadlines[msg.sender] = 0);
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = new address[](0));
        emit UserOpHashSet(msg.sender, _userOpHashes[msg.sender] = "");
    }
}
