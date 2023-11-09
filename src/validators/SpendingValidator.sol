// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Smart account interface.
interface IAccount {
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result);
}

/// @notice ERC20 token interface.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice Simple spending plan validator for smart accounts.
contract SpendingValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new guardians of an account.
    event GuardiansSet(address indexed account, address[] guardians);

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

    /// @dev Stores mappings of spending plans to accounts.
    mapping(address => mapping(address => uint256)) _plans;

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
        // The userOp must be a call to `execute` from `sender` account.
        assert(bytes4(userOp.callData[:4]) == IAccount.execute.selector);
        assert(address(bytes20(userOp.callData[4:24])) == userOp.sender);

        // The userOp `execute` must be a call to ERC20 `transfer` method.
        assert(bytes4(userOp.callData[24:28]) == IERC20.transfer.selector);

        // The userOp must `transfer` `to` an `amount` within the `sender` account plan.
        (address token, address to, uint256 amount) =
            abi.decode(userOp.callData[28:100], (address, address, uint256));
        // The `amount` must be within plan.
        _plans[msg.sender][token] >= amount;

        // The planned spend must be validated by guardians.
        address[] memory guardians = _guardians[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);

        for (uint256 i; i < guardians.length;) {
            if (
                SignatureCheckerLib.isValidSignatureNowCalldata(
                    guardians[i], hash, userOp.signature
                )
            ) {
                validationData = 0x01;
                break;
            }
            unchecked {
                ++i;
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            validationData := iszero(validationData)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GUARDIAN OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the guardians of an account.
    function getGuardians(address account) public view virtual returns (address[] memory) {
        return _guardians[account];
    }

    /// @dev Installs the new guardians of an account.
    function install(address[] calldata guardians) public payable virtual {
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = guardians);
    }

    /// @dev Uninstalls the guardians of an account.
    function uninstall() public payable virtual {
        emit GuardiansSet(msg.sender, _guardians[msg.sender] = new address[](0));
    }
}
