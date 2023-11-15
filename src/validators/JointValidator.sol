// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple joint ownership validator for smart accounts.
contract JointValidator {
    /// `````````````````````````````````````
    ///         EVENTS
    /// `````````````````````````````````````

    /// @dev Logs the new authorizers for an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// `````````````````````````````````````
    ///         STRUCTS
    /// `````````````````````````````````````

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

    /// `````````````````````````````````````
    ///         STORAGE
    /// `````````````````````````````````````

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// `````````````````````````````````````
    ///         CONSTRUCTOR
    /// `````````````````````````````````````

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// `````````````````````````````````````
    ///         VALIDATION OPERATIONS
    /// `````````````````````````````````````

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        address[] memory authorizers = _authorizers[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < authorizers.length;) {
            if (
                SignatureCheckerLib.isValidSignatureNowCalldata(
                    authorizers[i], hash, userOp.signature
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

    /// `````````````````````````````````````
    ///         AUTHORIZER OPERATIONS
    /// `````````````````````````````````````

    /// @dev Returns the authorizers for an account.
    function get(address account) public view virtual returns (address[] memory) {
        return _authorizers[account];
    }

    /// @dev Installs the new authorizers for an account.
    function install(address[] calldata authorizers) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Uninstalls the authorizers for an account.
    function uninstall() public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
