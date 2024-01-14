// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {EIP712} from "@solady/src/utils/EIP712.sol";
import {LibSort} from "@solady/src/utils/LibSort.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple executor permit validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/PermitValidator.sol)
/// @dev Examples:
/// - Send 0.1 ETH to 0x123...789 on 2024-01-01.
/// - Swap between 1-2 WETH for DAI every 3 days.
/// - Vote yes on every proposal made by nani.eth.
contract PermitValidator is EIP712 {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Calldata method is invalid for an execution.
    error InvalidSelector();

    /// @dev Permit usage limit reached by an authorizer.
    error PermitLimited();

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
        uint192 allowance;
        uint32 timesUsed;
        bytes4 selector;
        string intent;
        Span[] spans;
        Arg[] args;
    }

    /// @dev Permit timespan.
    struct Span {
        uint128 validAfter;
        uint128 validUntil;
    }

    /// @dev Calldata precision.
    struct Arg {
        Type _type;
        uint248 offset;
        bytes bounds;
        uint256 length;
    }

    /// @dev Calldata types.
    enum Type {
        Uint,
        Int,
        Address,
        Bool,
        Uint8,
        Bytes,
        String,
        Tuple
    }

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// @dev Stores mappings of permit hashes to permit data.
    mapping(bytes32 permitHash => Permit) internal _permits;

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

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        (bytes32 permitHash, bytes memory signature) =
            abi.decode(userOp.signature, (bytes32, bytes));
        address[] memory authorizers = _authorizers[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i != authorizers.length;) {
            if (SignatureCheckerLib.isValidSignatureNow(authorizers[i], hash, signature)) {
                validationData = 0x01; // Failure code.
                break;
            }
            unchecked {
                ++i;
            }
        }
        if (validationData == 0x00) return 0x01; // Failure code.
        Permit memory permit = _permits[permitHash];
        unchecked {
            uint256 count = permit.timesUsed++;
            if (count >= permit.spans.length) {
                delete _permits[permitHash];
                return 0x01; // Failure code.
            }
            validationData = validatePermit(permit, permit.spans[count], userOp.callData);
        }
    }

    /// ===================== PERMIT OPERATIONS ===================== ///

    /// @dev Returns the permit for a permit hash.
    function getPermit(bytes32 permitHash) public view virtual returns (Permit memory) {
        return _permits[permitHash];
    }

    /// @dev Returns the permit hash for an account and permit.
    function getPermitHash(address account, Permit calldata permit)
        public
        view
        virtual
        returns (bytes32)
    {
        return _hashTypedData(keccak256(abi.encode(account, permit)));
    }

    /// @dev Sets the permit for a permit hash given by the caller.
    /// note: Ensure `timesUsed` is zero unless a rewrite is preferred.
    function setPermitHash(Permit calldata permit) public payable virtual {
        _permits[_hashTypedData(keccak256(abi.encode(msg.sender, permit)))] = permit;
    }

    /// @dev Validates a permit for a given span and call data.
    function validatePermit(Permit memory permit, Span memory span, bytes calldata callData)
        public
        view
        virtual
        returns (uint256 validationData)
    {
        if (span.validAfter != 0 && block.timestamp < span.validAfter) revert PermitLimited();
        if (span.validUntil != 0 && block.timestamp > span.validUntil) revert PermitLimited();
        bytes4 selector = bytes4(callData[:4]);
        (address target, uint256 value, bytes memory data) =
            abi.decode(callData[4:], (address, uint256, bytes));
        if (selector != IExecutor.execute.selector) revert InvalidSelector();
        (bool found,) = LibSort.searchSorted(permit.targets, target);
        if (!found) revert PermitLimited();
        if (value != 0) permit.allowance -= uint192(value);
        if (bytes4(data) != permit.selector) revert InvalidSelector();
        unchecked {
            for (uint256 i; i != permit.args.length; ++i) {
                bytes memory call =
                    callData[permit.args[i].offset:permit.args[i].offset + permit.args[i].length];
                validationData = _validateArg(permit.args[i], call);
            }
        }
    }

    /// @dev Validates a permit argument for a given call data.
    function _validateArg(Arg memory arg, bytes memory callData)
        internal
        view
        virtual
        returns (uint256 validationData)
    {
        unchecked {
            // bytes memory _data = callData[arg.offset:arg.offset + 32];
            if (arg._type == Type.Uint) {
                if (_validateUint(abi.decode(callData, (uint256)), arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Int) {
                if (_validateInt(abi.decode(callData, (int256)), arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Address) {
                if (_validateAddress(abi.decode(callData, (address)), arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Bool) {
                if (_validateBool(abi.decode(callData, (bool)), arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Uint8) {
                if (_validateEnum(abi.decode(callData, (uint8)), arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Bytes) {
                if (_validateData(callData, arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.String) {
                if (_validateData(callData, arg.bounds)) return 0x00;
                return 0x01;
            } else if (arg._type == Type.Tuple) {
                if (_validateTuple(callData, arg.bounds)) return 0x00;
                return 0x01;
            }
        }
    }

    /// @dev Validates an uint256 `object` against given `bounds`.
    function _validateUint(uint256 object, bytes memory bounds)
        internal
        view
        virtual
        returns (bool)
    {
        (uint256 min, uint256 max) = abi.decode(bounds, (uint256, uint256));
        return object >= min && object <= max;
    }

    /// @dev Validates an int256 `object` against given `bounds`.
    function _validateInt(int256 object, bytes memory bounds)
        internal
        pure
        virtual
        returns (bool)
    {
        (int256 min, int256 max) = abi.decode(bounds, (int256, int256));
        return object >= min && object <= max;
    }

    /// @dev Validates an address `object` against given `bounds`.
    function _validateAddress(address object, bytes memory bounds)
        internal
        view
        virtual
        returns (bool found)
    {
        address[] memory addresses = abi.decode(bounds, (address[]));
        (found,) = LibSort.searchSorted(addresses, object);
    }

    /// @dev Validates a bool `object` against given `bounds`.
    function _validateBool(bool object, bytes memory bounds) internal pure virtual returns (bool) {
        return object == abi.decode(bounds, (bool));
    }

    /// @dev Validates an enum `object` against given `bounds`.
    function _validateEnum(uint256 object, bytes memory bounds)
        internal
        pure
        virtual
        returns (bool found)
    {
        (found,) = LibSort.searchSorted(abi.decode(bounds, (uint256[])), object);
    }

    /// @dev Validates a data `object` against given `bounds`.
    function _validateData(bytes memory object, bytes memory bounds)
        internal
        pure
        virtual
        returns (bool)
    {
        return keccak256(object) == keccak256(bounds);
    }

    /// @dev Validates a tuple `object` against given `bounds`.
    function _validateTuple(bytes memory object, bytes memory bounds)
        internal
        view
        virtual
        returns (bool)
    {
        Arg[] memory args = abi.decode(bounds, (Arg[]));
        for (uint256 i; i != args.length;) {
            unchecked {
                ++i;
            }
            if (_validateArg(args[i], object) == 0) break;
            return false;
        }
        return true;
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Returns the authorizers for an account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _authorizers[account];
    }

    /// @dev Installs new authorizers for the caller account.
    function install(address[] calldata authorizers) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Uninstalls the authorizers for the caller account.
    function uninstall() public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}

/// @notice Executor interface.
interface IExecutor {
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result);
}
