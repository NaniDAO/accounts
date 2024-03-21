# PermitValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/33a542184db4330f73d0a20b57e8976a75cb8aba/src/validators/PermitValidator.sol)

**Inherits:**
EIP712

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/PermitValidator.sol)

Simple executor permit validator for smart accounts.

*Examples:
- Send 0.1 ETH to 0x123...789 on 2024-01-01.
- Swap between 1-2 WETH for DAI every 3 days.
- Vote yes on every proposal made by nani.eth.*


## State Variables
### _authorizers
========================== STORAGE ========================== ///

*Stores mappings of authorizers to accounts.*


```solidity
mapping(address => address[]) internal _authorizers;
```


### _permits
*Stores mappings of permit hashes to permit data.*


```solidity
mapping(bytes32 permitHash => Permit) internal _permits;
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
    override
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

*Validates ERC4337 userOp with additional auth logic flow among authorizers.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### getPermit

===================== PERMIT OPERATIONS ===================== ///

*Returns the permit for a permit hash.*


```solidity
function getPermit(bytes32 permitHash) public view virtual returns (Permit memory);
```

### getPermitHash

*Returns the permit hash for an account and permit.*


```solidity
function getPermitHash(address account, Permit calldata permit)
    public
    view
    virtual
    returns (bytes32);
```

### setPermitHash

*Sets the permit for a permit hash given by the caller.
note: Ensure `timesUsed` is zero unless a rewrite is preferred.*


```solidity
function setPermitHash(Permit calldata permit) public payable virtual;
```

### validatePermit

*Validates a permit for a given span and call data.*


```solidity
function validatePermit(Permit memory permit, Span memory span, bytes calldata callData)
    public
    view
    virtual
    returns (uint256 validationData);
```

### _validateArg

*Validates a permit argument for a given call data.*


```solidity
function _validateArg(Arg memory arg, bytes memory callData)
    internal
    view
    virtual
    returns (uint256 validationData);
```

### _validateUint

*Validates an uint256 `object` against given `bounds`.*


```solidity
function _validateUint(uint256 object, bytes memory bounds) internal view virtual returns (bool);
```

### _validateInt

*Validates an int256 `object` against given `bounds`.*


```solidity
function _validateInt(int256 object, bytes memory bounds) internal pure virtual returns (bool);
```

### _validateAddress

*Validates an address `object` against given `bounds`.*


```solidity
function _validateAddress(address object, bytes memory bounds)
    internal
    view
    virtual
    returns (bool found);
```

### _validateBool

*Validates a bool `object` against given `bounds`.*


```solidity
function _validateBool(bool object, bytes memory bounds) internal pure virtual returns (bool);
```

### _validateEnum

*Validates an enum `object` against given `bounds`.*


```solidity
function _validateEnum(uint256 object, bytes memory bounds)
    internal
    pure
    virtual
    returns (bool found);
```

### _validateData

*Validates a data `object` against given `bounds`.*


```solidity
function _validateData(bytes memory object, bytes memory bounds)
    internal
    pure
    virtual
    returns (bool);
```

### _validateTuple

*Validates a tuple `object` against given `bounds`.*


```solidity
function _validateTuple(bytes memory object, bytes memory bounds)
    internal
    view
    virtual
    returns (bool);
```

### getAuthorizers

================== INSTALLATION OPERATIONS ================== ///

*Returns the authorizers for an account.*


```solidity
function getAuthorizers(address account) public view virtual returns (address[] memory);
```

### install

*Installs new authorizers for the caller account.*


```solidity
function install(address[] calldata authorizers) public payable virtual;
```

### uninstall

*Uninstalls the authorizers for the caller account.*


```solidity
function uninstall() public payable virtual;
```

## Events
### AuthorizersSet
=========================== EVENTS =========================== ///

*Logs the new authorizers for an account.*


```solidity
event AuthorizersSet(address indexed account, address[] authorizers);
```

## Errors
### InvalidSelector
======================= CUSTOM ERRORS ======================= ///

*Calldata method is invalid for an execution.*


```solidity
error InvalidSelector();
```

### PermitLimited
*Permit usage limit reached by an authorizer.*


```solidity
error PermitLimited();
```

## Structs
### UserOperation
========================== STRUCTS ========================== ///

*The ERC4337 user operation (userOp) struct.*


```solidity
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
```

### Permit
*Permit data struct.*


```solidity
struct Permit {
    address[] targets;
    uint192 allowance;
    uint32 timesUsed;
    bytes4 selector;
    string intent;
    Span[] spans;
    Arg[] args;
}
```

### Span
*Permit timespan.*


```solidity
struct Span {
    uint128 validAfter;
    uint128 validUntil;
}
```

### Arg
*Calldata precision.*


```solidity
struct Arg {
    Type _type;
    uint248 offset;
    bytes bounds;
    uint256 length;
}
```

## Enums
### Type
*Calldata types.*


```solidity
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
```

