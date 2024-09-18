# RemoteValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/e8688d40b41a4f91d7244ea40c12251a38f039f2/src/validators/RemoteValidator.sol)

**Inherits:**
EIP712

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/RemoteValidator.sol)

Simple remote non-sequential validator for smart accounts.


## State Variables
### _NULL_HASH
========================= CONSTANTS ========================= ///

*Prehash of `keccak256("")` for validation efficiency.*


```solidity
bytes32 internal constant _NULL_HASH =
    0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
```


### _VALIDATE_TYPEHASH
*EIP712 typehash as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
Derived from `userOp` without the signature and the time fields of `validUntil` and `validAfter`.*


```solidity
bytes32 internal constant _VALIDATE_TYPEHASH =
    0xa9a214c6f6d90f71d094504e32920cfd4d8d53e5d7cf626f9a26c88af60081c7;
```


## Functions
### _domainNameAndVersion

*Returns domain name
& version of implementation.*


```solidity
function _domainNameAndVersion()
    internal
    pure
    virtual
    override(EIP712)
    returns (string memory, string memory);
```

### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs
this implementation.*


```solidity
constructor() payable;
```

### validateUserOp

=================== VALIDATION OPERATIONS =================== ///

*Validates packed ERC4337 userOp in EIP-712-signed non-sequential flow.*


```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### __hashTypedData

*Encodes `userOp` and extracted time window within EIP712 syntax.*


```solidity
function __hashTypedData(PackedUserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
    internal
    view
    virtual
    returns (bytes32 digest);
```

### _calldataKeccak

*Keccak function over calldata. This is more efficient than letting solidity do it.*


```solidity
function _calldataKeccak(bytes calldata data) internal pure virtual returns (bytes32 hash);
```

## Structs
### PackedUserOperation
========================== STRUCTS ========================== ///

*The packed ERC4337 userOp struct.*


```solidity
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}
```

