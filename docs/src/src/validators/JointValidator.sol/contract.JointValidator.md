# JointValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/8328e5c25cabbe5c5a4de81be1529d0f8371cfb5/src/validators/JointValidator.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/JointValidator.sol)

Simple joint ownership validator for smart accounts.


## State Variables
### _authorizers
========================== STORAGE ========================== ///

*Stores mappings of authorizers to accounts.*


```solidity
mapping(address => address[]) internal _authorizers;
```


## Functions
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

### get

*Returns the authorizers for an account.*


```solidity
function get(address account) public view virtual returns (address[] memory);
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

*Logs new authorizers for an account.*


```solidity
event AuthorizersSet(address indexed account, address[] authorizers);
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

