# RecoveryValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/485961b82d85978443ccbce7f93af4f2cad12381/src/validators/RecoveryValidator.sol)

Simple social recovery validator for smart accounts.

*Operationally this validator works as a one-time recovery
multisig singleton by allowing accounts to program authorizers
and thresholds for such authorizers to validate user operations.*


## State Variables
### _settings
========================== STORAGE ========================== ///

*Stores mapping of settings to accounts.*


```solidity
mapping(address => Settings) internal _settings;
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

*Validates ERC4337 userOp with recovery auth logic flow among authorizers.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### validateUserOp

*Validates packed ERC4337 userOp with recovery auth logic flow among authorizers.*


```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
    external
    payable
    virtual
    returns (uint256 validationData);
```

### _validateUserOp

*Returns validity of recovery operation based on the signature and calldata of userOp.*


```solidity
function _validateUserOp(bytes32 userOpHash, bytes calldata callData, bytes calldata signature)
    internal
    virtual
    returns (uint256 validationData);
```

### getSettings

=================== AUTHORIZER OPERATIONS =================== ///

*Returns the account recovery settings.*


```solidity
function getSettings(address account) public view virtual returns (Settings memory);
```

### getAuthorizers

*Returns the authorizers for the account.*


```solidity
function getAuthorizers(address account) public view virtual returns (address[] memory);
```

### setDelay

*Sets new authorizer validation delay for the caller account.*


```solidity
function setDelay(uint32 delay) public payable virtual;
```

### setThreshold

*Sets new authorizer threshold for the caller account.*


```solidity
function setThreshold(uint192 threshold) public payable virtual;
```

### setAuthorizers

*Sets new authorizers for the caller account.*


```solidity
function setAuthorizers(address[] calldata authorizers) public payable virtual;
```

### requestOwnershipHandover

*Initiates an authorizer handover for the account.
This function can only be called by an authorizer and
sets a new deadline for the account to cancel request.*


```solidity
function requestOwnershipHandover(address account) public payable virtual;
```

### completeOwnershipHandoverRequest

*Complete ownership handover request based on authorized deadline completion.*


```solidity
function completeOwnershipHandoverRequest(address account) public payable virtual;
```

### cancelOwnershipHandover

*Cancels authorizer handovers for the caller account.*


```solidity
function cancelOwnershipHandover() public payable virtual;
```

### install

================== INSTALLATION OPERATIONS ================== ///

*Installs the recovery validator settings for the caller account.*


```solidity
function install(uint32 delay, uint192 threshold, address[] calldata authorizers)
    public
    payable
    virtual;
```

### uninstall

*Uninstalls the recovery validator settings for the caller account.*


```solidity
function uninstall() public payable virtual;
```

## Events
### DelaySet
=========================== EVENTS =========================== ///

*Logs the new delay for an account to renew custody.*


```solidity
event DelaySet(address indexed account, uint32 delay);
```

### DeadlineSet
*Logs the new deadline for an account to renew custody.*


```solidity
event DeadlineSet(address indexed account, uint32 deadline);
```

### ThresholdSet
*Logs the new authorizer threshold for an account.*


```solidity
event ThresholdSet(address indexed account, uint192 threshold);
```

### AuthorizersSet
*Logs the new authorizers for an account (i.e., 'multisig').*


```solidity
event AuthorizersSet(address indexed account, address[] authorizers);
```

## Errors
### InvalidSetting
======================= CUSTOM ERRORS ======================= ///

*Inputs are invalid for a setting.*


```solidity
error InvalidSetting();
```

### InvalidCalldata
*Calldata method is not `transferOwnership()`.*


```solidity
error InvalidCalldata();
```

### Unauthorized
*The caller is not authorized to call the function.*


```solidity
error Unauthorized();
```

### DeadlinePending
*The recovery deadline is still pending for resolution.*


```solidity
error DeadlinePending();
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

### Signature
*The authorizer signature struct.*


```solidity
struct Signature {
    address signer;
    bytes sign;
}
```

### Settings
*The validator settings struct.*


```solidity
struct Settings {
    uint32 delay;
    uint32 deadline;
    uint192 threshold;
    address[] authorizers;
}
```

