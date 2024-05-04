# TimeValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/633a53011abcd7918cc74b4d98c9ea83062f3c59/src/validators/TimeValidator.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/TimeValidator.sol)

Simple time window validator for smart accounts.


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

*Validates ERC4337 userOp with time window unpacking and owner validation.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### validateUserOp

*Validates packed ERC4337 userOp with time window unpacking and owner validation.*


```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### _validateUserOp

*Returns validity of userOp based on an account owner signature.*


```solidity
function _validateUserOp(bytes32 userOpHash, bytes calldata signature)
    internal
    virtual
    returns (uint256 validationData);
```

### _packValidationData

*Returns the packed validation data for userOp based on validation.*


```solidity
function _packValidationData(bool valid, uint48 validUntil, uint48 validAfter)
    internal
    pure
    virtual
    returns (uint256 validationData);
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

### PackedUserOperation
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

