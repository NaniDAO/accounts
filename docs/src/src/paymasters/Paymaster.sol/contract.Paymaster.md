# Paymaster
[Git Source](https://github.com/NaniDAO/accounts/blob/4789484b1daa1e7826eeec6833ca9b47824ee8b6/src/paymasters/Paymaster.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/Paymaster.sol)

Simple ERC4337 Paymaster.


## State Variables
### ENTRY_POINT
========================= CONSTANTS ========================= ///

*The canonical ERC4337 EntryPoint contract (0.7).*


```solidity
address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
```


### OWNER
========================= IMMUTABLES ========================= ///

*Holds an immutable owner for this contract.*


```solidity
address internal immutable OWNER;
```


## Functions
### onlyOwner

========================= MODIFIERS ========================= ///

*Requires that the caller is the owner.*


```solidity
modifier onlyOwner() virtual;
```

### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs this owned implementation.*


```solidity
constructor(address owner) payable;
```

### validatePaymasterUserOp

=================== VALIDATION OPERATIONS =================== ///

*Paymaster validation: check that contract owner signed off.*


```solidity
function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32, uint256)
    public
    payable
    virtual
    returns (bytes memory, uint256);
```

### _hashSignedUserOp

*Returns the eth-signed message hash of the userOp within the context of the paymaster and user.*


```solidity
function _hashSignedUserOp(
    PackedUserOperation calldata userOp,
    uint48 validUntil,
    uint48 validAfter
) internal view virtual returns (bytes32);
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

## Structs
### PackedUserOperation
========================== STRUCTS ========================== ///

*The packed ERC4337 userOp struct (0.7).*


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

