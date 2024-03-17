# JointValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/fb62ae7d2c128e746e2f23d9357928dc2e00e7cf/src/validators/JointValidator.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/JointValidator.sol)

Simple joint ownership validator for smart accounts.


## State Variables
### _authorizers
========================== STORAGE ========================== ///

*Stores mapping of authorizers to accounts.*


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

=================== AUTHORIZER OPERATIONS =================== ///

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

