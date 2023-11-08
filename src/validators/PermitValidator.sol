// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ECDSA} from "@solady/src/utils/ECDSA.sol";
import {EIP712} from "@solady/src/utils/EIP712.sol";
import {ERC4337} from "@solady/test/utils/mocks/MockERC4337.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";
import {LibSort} from "@solady/src/utils/LibSort.sol";

import "@forge/Test.sol";

/*
Examples
- Send 0.1 ETH to 0x1234...5678 at any time but not after 2024-01-01.
- Swap between 1-2 WETH for DAI every 3 days.
- Vote no on every proposal 
*/

enum TYPE
// uint<M>: unsigned integer type of M bits, 0 < M <= 256, M % 8 == 0
{
    UINT,
    UINT8,
    // int<M>: two’s complement signed integer type of M bits, 0 < M <= 256, M % 8 == 0.
    INT,
    // equivalent to uint160, except for the assumed interpretation and language typing. For computing the function selector, address is used.
    ADDRESS,
    // equivalent to uint8 restricted to the values 0 and 1. For computing the function selector, bool is used.
    BOOL,
    // bytes<M>: binary type of M bytes, 0 < M <= 32
    // bytes: dynamic sized byte sequence
    BYTES,
    // string: dynamic sized unicode string assumed to be UTF-8 encoded.
    STRING,
    TUPLE
}
// FUNCTION
// <type>[]: a variable-length array of elements of the given type.
// (T1,T2,...,Tn): tuple consisting of the types T1, …, Tn, n >= 0

struct Param {
    TYPE _type; // type of the parameter
    uint8 offset; // location of the parameter in the calldata
    // the true location in calldata for dynamic types like bytes, string,
    uint256 length; // in case of bytes, string arrays, tuples, the length of the type
    bytes bounds; // rules for this parameter type
        // tuple - encode Params[]
}

struct Span {
    uint32 validAfter;
    uint32 validUntil;
}

struct Slip {
    address[] targets;
    uint256 maxValue;
    bytes4 selector;
    // uint128 uses;
    // uint32 interval;
    // uint32 validAfter;
    // uint32 validUntil;
    Span[] spans;
    Param[] arguments;
}

/**
 * @title Permissions
 * @dev Permissions contract
 */
contract Permissions is EIP712 {
    error InvalidPayload();

    mapping(bytes32 slipHash => uint256 use) public use;
    mapping(bytes32 slipHash => Slip) public slips;

    function _domainNameAndVersion()
        internal
        pure
        override
        returns (string memory name, string memory version)
    {
        name = "Permissions";
        version = "1";
    }

    function validateUserOp(
        ERC4337.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external payable returns (uint256 validationData) {
        // extract first four bytes of userOp.callData
       
        if (ERC4337.execute.selector != bytes4(userOp.callData[:4])) revert InvalidPayload();
        (address target, uint256 value, bytes memory data) = abi.decode(userOp.callData[4:], (address, uint256, bytes));
      
        // extract slipHash
        (bytes32 slipHash, bytes memory sig) = abi.decode(userOp.signature, (bytes32, bytes));

        
        return uint256(checkPermission(
            userOp.sender,
            userOp.signature,
            slips[slipHash],
            ERC4337.Call(target, value, data)
        ));
    }

    function checkPermission(
        ERC4337 wallet,
        bytes calldata sig,
        Slip calldata slip,
        ERC4337.Call calldata call
    ) public returns (bool) {
        require(slip.targets.length != 0, "Permissions: no targets");
        require(slip.spans.length != 0, "Permissions: no uses");

        bytes32 slipHash = getSlipHash(wallet, slip);
        // check if the slip is authorized
        if (!SignatureCheckerLib.isValidERC1271SignatureNowCalldata(address(wallet), slipHash, sig))
        {
            return false;
        }

        unchecked {
            if (
                slip.spans[use[slipHash]].validAfter != 0
                    && block.timestamp < slip.spans[use[slipHash]].validAfter
            ) return false;
            if (
                slip.spans[use[slipHash]].validUntil != 0
                    && block.timestamp > slip.spans[use[slipHash]].validUntil
            ) return false;
            use[slipHash]++;
        }

        // check if call target is authorized
        unchecked {
            for (uint256 i; i < slip.targets.length; ++i) {
                if (slip.targets[i] == call.target) break;
                if (i == slip.targets.length - 1) return false;
            }
        }

        // check if the call is within value bounds
        if (call.value > slip.maxValue) return false;

        // check selector
        if (slip.selector.length != 0 && call.data.length != 0) {
            if (bytes4(call.data[:4]) != bytes4(slip.selector)) return false;

            // check if the call is within data bounds
            for (uint256 i; i < slip.arguments.length; i++) {
                Param calldata param = slip.arguments[i];

                if (param._type == TYPE.UINT) {
                    if (
                        _validateUint(
                            abi.decode(call.data[param.offset:param.offset + 32], (uint256)),
                            param.bounds
                        )
                    ) break;
                    return false;
                } else if (param._type == TYPE.UINT8) {
                    console.log(i, "param is uint8");
                    if (
                        _validateEnum(
                            abi.decode(call.data[param.offset:param.offset + 32], (uint256)),
                            param.bounds
                        )
                    ) break;
                    return false;
                } else if (param._type == TYPE.INT) {
                    console.log(i, "param is int");
                    if (
                        _validateInt(
                            abi.decode(call.data[param.offset:param.offset + 32], (int256)),
                            param.bounds
                        )
                    ) break;
                    return false;
                } else if (param._type == TYPE.ADDRESS) {
                    console.log(i, "param is address");
                    if (
                        _validateAddress(
                            abi.decode(call.data[param.offset:param.offset + 32], (address)),
                            param.bounds
                        )
                    ) break;
                    return false;
                } else if (param._type == TYPE.BOOL) {
                    console.log(i, "param is bool");
                    if (
                        _validateBool(
                            abi.decode(call.data[param.offset:param.offset + 32], (bool)),
                            param.bounds
                        )
                    ) break;
                    return false;
                }
                // else if (param._type == TYPE.BYTES) {
                //     bytes memory bound = abi.decode(param.bounds, (bytes));
                //     bytes memory value = abi.decode(call.data[param.offset:], (bytes));

                //     if (bound != value) return false;
                // } else if (param._type == TYPE.STRING) {
                //     string memory bound = abi.decode(param.bounds, (string));
                //     string memory value = abi.decode(call.data[param.offset:], (string));

                //     if (bound != value) return false;
                // }
                else if (param._type == TYPE.TUPLE) {
                    console.log(i, "param is tuple");
                    if (_validateTuple(call.data, param.bounds, param.offset, param.length)) break;
                    return false;
                }
            }
        }

        return true;
    }

    function getSlipHash(ERC4337 wallet, Slip calldata slip) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(wallet, slip)));
    }

    function _validateUint(uint256 value, bytes memory bounds) internal pure returns (bool found) {
        (uint256 min, uint256 max) = abi.decode(bounds, (uint256, uint256));
        return value >= min && value <= max;
    }

    function _validateEnum(uint256 value, bytes memory bounds) internal pure returns (bool found) {
        (uint256[] memory bound) = abi.decode(bounds, (uint256[]));
        LibSort.sort(bound);
        (found,) = LibSort.searchSorted(bound, value);
        return found;
    }

    function _validateInt(int256 value, bytes memory bounds) internal pure returns (bool found) {
        (int256 min, int256 max) = abi.decode(bounds, (int256, int256));
        return value >= min && value <= max;
    }

    function _validateAddress(address value, bytes memory bounds)
        internal
        view
        returns (bool found)
    {
        (address[] memory bound) = abi.decode(bounds, (address[]));
        LibSort.sort(bound);
        (found,) = LibSort.searchSorted(bound, value);
        return found;
    }

    function _validateBool(bool value, bytes memory bounds) internal pure returns (bool) {
        return value == abi.decode(bounds, (bool));
    }

    function _validateTuple(bytes memory data, bytes memory bounds, uint8 offset, uint256 length)
        internal
        pure
        returns (bool)
    {}
}
