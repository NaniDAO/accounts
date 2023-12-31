# RecoveryValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/8328e5c25cabbe5c5a4de81be1529d0f8371cfb5/src/validators/RecoveryValidator.sol)

Simple social recovery validator for smart accounts.

*Operationally this validator works as a one-time recovery
multisig singleton by allowing accounts to program authorizers
and thresholds for such authorizers to validate user operations.*


## State Variables
### _settings
========================== STORAGE ========================== ///

*Stores mappings of settings to accounts.*


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

*Validates ERC4337 userOp with additional auth logic flow among authorizers.
This must be used to execute `transferOwnership` to backup decided by threshold.*


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
    returns (bytes[] memory signatures);
```

### getSettings

=================== AUTHORIZER OPERATIONS =================== ///

*Returns the account settings.*


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

*Sets new authorizers' threshold for the caller account.*


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

### cancelOwnershipHandover

*Cancels authorizer handovers for the caller account.*


```solidity
function cancelOwnershipHandover() public payable virtual;
```

### install

================== INSTALLATION OPERATIONS ================== ///

*Installs the validator settings for the caller account.*


```solidity
function install(uint32 delay, uint192 threshold, address[] calldata authorizers)
    public
    payable
    virtual;
```

### uninstall

*Uninstalls the validator settings for the caller account.*


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
*Logs the new authorizers' threshold for an account.*


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

### InvalidExecute
*Calldata method is invalid for an execution.*


```solidity
error InvalidExecute();
```

### Unauthorized
*The caller is not authorized to call the function.*


```solidity
error Unauthorized();
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

### Authorizer
*The authorizer signing struct.*


```solidity
struct Authorizer {
    address signer;
    bool matched;
}
```

