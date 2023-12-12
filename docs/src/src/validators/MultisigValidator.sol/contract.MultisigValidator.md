# MultisigValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/8328e5c25cabbe5c5a4de81be1529d0f8371cfb5/src/validators/MultisigValidator.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/MultisigValidator.sol)

Simple thresholded-ownership validator for smart accounts.


## State Variables
### _thresholds
========================== STORAGE ========================== ///

*Stores mappings of thresholds to accounts.*


```solidity
mapping(address => uint256) internal _thresholds;
```


### _authorizers
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

*Validates ERC4337 userOp with additional auth logic flow among signers.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### _splitSignature

*Returns bytes array from split signature.*


```solidity
function _splitSignature(bytes calldata signature)
    internal
    view
    virtual
    returns (bytes[] memory sigs);
```

### setThreshold

=================== AUTHORIZER OPERATIONS =================== ///

*Sets the new authorizers' threshold for an account.*


```solidity
function setThreshold(uint256 threshold) public payable virtual;
```

### setAuthorizers

*Sets the new authorizers for an account.*


```solidity
function setAuthorizers(address[] memory authorizers) public payable virtual;
```

### install

================== INSTALLATION OPERATIONS ================== ///

*Installs the validation threshold and authorizers for an account.*


```solidity
function install(uint256 threshold, address[] calldata authorizers) public payable virtual;
```

### uninstall

*Uninstalls the validation threshold and authorizers for an account.*


```solidity
function uninstall() public payable virtual;
```

## Events
### ThresholdSet
=========================== EVENTS =========================== ///

*Logs the new authorizers' threshold for an account.*


```solidity
event ThresholdSet(address indexed account, uint256 threshold);
```

### AuthorizersSet
*Logs the new authorizers for an account.*


```solidity
event AuthorizersSet(address indexed account, address[] authorizers);
```

## Errors
### Unauthorized
======================= CUSTOM ERRORS ======================= ///

*The caller is not authorized to call the function.*


```solidity
error Unauthorized();
```

### InvalidSetting
*Authorizers or threshold are invalid for a setting.*


```solidity
error InvalidSetting();
```

## Structs
### Signature
========================== STRUCTS ========================== ///

*A basic multisignature struct.*


```solidity
struct Signature {
    address authorizer;
    bytes signature;
}
```

### UserOperation
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

