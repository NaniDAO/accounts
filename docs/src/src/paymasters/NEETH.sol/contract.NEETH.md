# NEETH
[Git Source](https://github.com/NaniDAO/accounts/blob/fb62ae7d2c128e746e2f23d9357928dc2e00e7cf/src/paymasters/NEETH.sol)

**Inherits:**
ERC20

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/NETH.sol)

Simple wrapped ERC4337 implementation with paymaster and yield functions.

*The strategy for ether (ETH) deposits defaults to Lido for this alpha version.*


## State Variables
### _POOL
========================= CONSTANTS ========================= ///

*The Uniswap V2 pool for swapping stETH for WETH.*


```solidity
IUniswapV2 internal constant _POOL = IUniswapV2(0x4028DAAC072e492d34a3Afdbef0ba7e35D8b55C4);
```


### _WETH
*The WETH contract for unwrapping ETH.*


```solidity
IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
```


### _ENTRY_POINT
*The canonical ERC4337 EntryPoint contract for NEETH alpha.*


```solidity
address payable internal constant _ENTRY_POINT = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
```


### _STRATEGY
*The designated ETH strategy contract (Lido) for NEETH alpha.*


```solidity
address payable internal constant _STRATEGY = payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
```


### _COST_OF_POST
*Holds a constant postOp cost estimate.*


```solidity
uint256 internal constant _COST_OF_POST = 15000;
```


### _OWNER
========================= IMMUTABLES ========================= ///

*Holds an immutable owner.*


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

### name

======================= ERC20 METADATA ======================= ///

*Returns the name of the token.*


```solidity
function name() public view virtual override returns (string memory);
```

### symbol

*Returns the symbol of the token.*


```solidity
function symbol() public view virtual override returns (string memory);
```

### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs this owned implementation.*


```solidity
constructor(address payable owner) payable;
```

### deposit

===================== DEPOSIT OPERATIONS ===================== ///

*Deposits `msg.value` ETH of the caller for NEETH..*


```solidity
function deposit() public payable virtual;
```

### depositTo

*Deposits `msg.value` ETH of the caller and mints NEETH shares for `to`.*


```solidity
function depositTo(address to) public payable virtual;
```

### withdraw

==================== WITHDRAW OPERATIONS ==================== ///

*Burns `amount` NEETH of the caller and sends `amount` ETH to the caller.*


```solidity
function withdraw(uint256 amount) public virtual;
```

### withdrawFrom

*Burns `amount` NEETH of the `from` and sends `amount` ETH to the `to`.*


```solidity
function withdrawFrom(address from, address to, uint256 amount) public virtual;
```

### validatePaymasterUserOp

=================== VALIDATION OPERATIONS =================== ///

*Payment validation: check if paymaster agrees to pay.*


```solidity
function validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    public
    payable
    virtual
    onlyEntryPoint
    returns (bytes memory context, uint256 validationData);
```

### postOp

*Post-operation (postOp) handler.*


```solidity
function postOp(PostOpMode, bytes calldata context, uint256 actualGasCost)
    public
    payable
    virtual
    onlyEntryPoint;
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

### _getAmountOutInETH

====================== SWAP OPERATIONS ====================== ///

*Returns the amount of ETH that would be received for `share` NEETH.*


```solidity
function _getAmountOutInETH(uint256 share) internal view virtual returns (uint256 amountOut);
```

### _getAmountOutInShares

*Returns the amount of NEETH that would be received for `amount` ETH.*


```solidity
function _getAmountOutInShares(uint256 amount) internal view virtual returns (uint256 amountOut);
```

### _swap

*Swaps `share` NEETH for WETH and transfers ETH for `to`.*


```solidity
function _swap(uint256 share, address to) internal virtual;
```

### receive

==================== FALLBACK OPERATIONS ==================== ///

*Equivalent to `deposit()`.*


```solidity
receive() external payable virtual;
```

## Errors
### BalanceTooLowForUserOp
======================= CUSTOM ERRORS ======================= ///

*Balance is too low for the verification of user operation.*


```solidity
error BalanceTooLowForUserOp();
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

