// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ECDSA} from "@solady/src/utils/ECDSA.sol";
import {EIP712} from "@solady/src/utils/EIP712.sol";
import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Executor interface.
interface IExecutor {
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result);

    function delegateExecute(address target, bytes calldata data)
        external
        payable
        returns (bytes memory result);
}

/// @notice Simple executor permit validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/PermitValidator.sol)
/// @dev Examples:
/// - Send 0.1 ETH to 0x123...789 on 2024-01-01.
/// - Swap between 1-2 WETH for DAI every 3 days.
/// - Vote yes on every proposal made by nani.eth.
contract PermitValidator is EIP712 {
    /// ======================= CUSTOM ERRORS ======================= ///

    error InvalidCall();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new authorizers for an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// ========================== STRUCTS ========================== ///

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

    /// @dev Permit data struct.
    struct Permit {
        address[] targets;
        uint256 allowance;
        bytes4 selector;
        Span[] spans;
        Param[] arguments;
    }

    /// @dev Calldata types.
    enum Type {
        UINT,
        INT,
        ADDRESS,
        BOOL,
        UINT8,
        BYTES,
        STRING,
        TUPLE
    }

    /// @dev Calldata precision.
    struct Param {
        Type _type;
        uint8 offset;
        uint256 length;
        bytes rules;
    }

    /// @dev Permit timespan.
    struct Span {
        uint32 validAfter;
        uint32 validUntil;
    }

    /// @dev Call struct.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// @dev Stores mappings of permit hashes to usage.
    mapping(bytes32 permitHash => uint256) public uses;

    /// @dev Stores mappings of permit hashes to structs.
    mapping(bytes32 permitHash => Permit) public permits;

    /// @dev Returns domain name
    /// & version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory, string memory)
    {
        return ("PermitValidator", "0.0.0");
    }

    /// =================== VALIDATION OPERATIONS =================== ///

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        // Extract permit hash and signature from `userOp`.
        (bytes32 permitHash, bytes memory signature) =
            abi.decode(userOp.signature, (bytes32, bytes));
        // Ensure `userOpHash` is signed by an account authorizer.
        address[] memory authorizers = _authorizers[userOp.sender];
        for (uint256 i; i < authorizers.length;) {
            if (SignatureCheckerLib.isValidSignatureNow(authorizers[i], userOpHash, signature)) {
                break;
            }
            unchecked {
                ++i;
            }
        }
        // Get permit for userOp from hash pointer.
        Permit memory permit = permits[permitHash];
        unchecked {
            uint256 uses = uses[permitHash]++;
            if (uses == permit.spans.length) return 0x01;
            // Return validation data for permit.
            validationData = validatePermit(
                permit.spans[uses], permit, userOp.callData, userOpHash, signature, msg.sender
            );
        }
    }

    function validatePermit(
        Span memory span,
        Permit memory permit,
        bytes calldata callData,
        bytes32 userOpHash,
        bytes memory signature,
        address account
    ) public view virtual returns (uint256 validationData) {
        // Extract executory details.
        (bytes4 selector, address target, uint256 value, bytes memory data) =
            abi.decode(callData, (bytes4, address, uint256, bytes));
        // Ensure executory intent.
        if (selector != IExecutor.execute.selector) revert InvalidCall();
        // Ensure the permit is within the authorized bounds.
        unchecked {
            // Ensure the permit is within the valid timespan.
            if (span.validAfter != 0 && block.timestamp < span.validAfter) return 0x01;
            if (span.validUntil != 0 && block.timestamp > span.validUntil) return 0x01;
            // Ensure the call `target` is authorized.
            for (uint256 i; i < permit.targets.length; ++i) {
                if (permit.targets[i] == target) break;
                if (i == permit.targets.length - 1) return 0x01;
            }
            // Ensure the call `value` is within allowance.
            if (value > permit.allowance) revert InvalidCall();
        }
        // Check the `callData` against the permit data and bounds.
        if (permit.selector.length != 0 && data.length != 0) {
            // Check the permit selector against the call.
            if (bytes4(data) != permit.selector) return 0x01;
            // Ensure the call params are within permitted bounds.
            Param memory param;
            unchecked {
                for (uint256 i; i < permit.arguments.length; ++i) {
                    param = permit.arguments[i];
                    bytes memory _data = callData[param.offset:param.offset + 32];
                    if (param._type == Type.UINT) {
                        if (_validateUint(abi.decode(_data, (uint256)), param.rules)) break;
                        return 0x01;
                    } else if (param._type == Type.INT) {
                        if (_validateInt(abi.decode(_data, (int256)), param.rules)) break;
                        return 0x01;
                    } else if (param._type == Type.ADDRESS) {
                        if (_validateAddress(abi.decode(_data, (address)), param.rules)) break;
                        return 0x01;
                    } else if (param._type == Type.BOOL) {
                        if (_validateBool(abi.decode(_data, (bool)), param.rules)) break;
                        return 0x01;
                    } else if (param._type == Type.UINT8) {
                        if (_validateEnum(abi.decode(_data, (uint8)), param.rules)) break;
                        return 0x01;
                        // else if (param._type == Type.BYTES) {
                        //     bytes memory bound = abi.decode(param.rules, (bytes));
                        //     bytes memory value = abi.decode(call.data[param.offset:], (bytes));

                        //     if (bound != value) return 1;
                        // } else if (param._type == Type.STRING) {
                        //     string memory bound = abi.decode(param.rules, (string));
                        //     string memory value = abi.decode(call.data[param.offset:], (string));

                        //     if (bound != value) return 1;
                        // }
                    } else if (param._type == Type.TUPLE) {
                        if (_validateTuple(_data, param.rules, param.offset, param.length)) {
                            break;
                        }
                        return 0x01;
                    }
                }
            }
        }
        return 0;
    }

    /// ===================== PERMIT OPERATIONS ===================== ///

    function getPermitHash(address account, Permit memory permit)
        public
        view
        virtual
        returns (bytes32)
    {
        return _hashTypedData(keccak256(abi.encode(account, permit)));
    }

    function _validateUint(uint256 value, bytes memory bounds)
        internal
        pure
        virtual
        returns (bool)
    {
        (uint256 min, uint256 max) = abi.decode(bounds, (uint256, uint256));
        return value >= min && value <= max;
    }

    function _validateInt(int256 value, bytes memory bounds) internal pure virtual returns (bool) {
        (int256 min, int256 max) = abi.decode(bounds, (int256, int256));
        return value >= min && value <= max;
    }

    function _validateAddress(address value, bytes memory rules)
        internal
        view
        virtual
        returns (bool found)
    {
        (found,) = LibSort.searchSorted(abi.decode(rules, (address[])), value);
    }

    function _validateBool(bool value, bytes memory bounds) internal pure virtual returns (bool) {
        return value == abi.decode(bounds, (bool));
    }

    function _validateEnum(uint256 value, bytes memory bounds)
        internal
        pure
        virtual
        returns (bool found)
    {
        (found,) = LibSort.searchSorted(abi.decode(bounds, (uint256[])), value);
    }

    function _validateTuple(bytes memory data, bytes memory bounds, uint8 offset, uint256 length)
        internal
        pure
        virtual
        returns (bool)
    {}

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Returns the authorizers for an account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
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
