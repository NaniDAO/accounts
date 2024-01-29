# Paymaster
[Git Source](https://github.com/NaniDAO/accounts/blob/ce662883d04645306a7e3363a72f54ee359035a3/src/paymasters/Paymaster.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/Paymaster.sol)

Simple ERC4337 Paymaster.


## State Variables
### _ENTRY_POINT
========================= CONSTANTS ========================= ///

*The canonical ERC4337 EntryPoint contract.*


```solidity
address payable internal constant _ENTRY_POINT = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
```


### _OWNER
========================= IMMUTABLES ========================= ///

*Holds an immutable owner for this contract.*


```solidity
address payable internal immutable _OWNER;
```


## Functions
### onlyEntryPoint

========================= MODIFIERS ========================= ///

*Requires that the caller is the EntryPoint.*


```solidity
modifier onlyEntryPoint() virtual;
```

### onlyOwner

*Requires that the caller is the owner.*


```solidity
modifier onlyOwner() virtual;
```

### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs this owned implementation.*


```solidity
constructor(address payable owner) payable;
```

### validatePaymasterUserOp

=================== VALIDATION OPERATIONS =================== ///

*Paymaster validation: check that contract owner signed off.*


```solidity
function validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256)
    public
    payable
    virtual
    onlyEntryPoint
    returns (bytes memory, uint256);
```

### _hashSignedUserOp

*Returns the eth-signed message hash of the userOp within context of paymaster and user.*


```solidity
function _hashSignedUserOp(UserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
    internal
    view
    virtual
    returns (bytes32);
```

### _packValidationData

*Returns the packed validation data for `validatePaymasterUserOp`.*


```solidity
function _packValidationData(bool valid, uint48 validUntil, uint48 validAfter)
    internal
    pure
    virtual
    returns (uint256);
```

### addStake

===================== STAKING OPERATIONS ===================== ///

*Add stake for this paymaster. Further sets a staking delay timestamp.*


```solidity
function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner;
```

### unlockStake

*Unlock the stake, in order to withdraw it.*


```solidity
function unlockStake() public payable virtual onlyOwner;
```

### withdrawStake

*Withdraw the entire paymaster's stake. Can select a recipient of this withdrawal.*


```solidity
function withdrawStake(address payable withdrawAddress) public payable virtual onlyOwner;
```

## Errors
### Unauthorized
======================= CUSTOM ERRORS ======================= ///

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

