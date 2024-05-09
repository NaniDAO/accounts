# NEETH
[Git Source](https://github.com/NaniDAO/accounts/blob/2b176650c1c7dc3fb29490114f14dad2292d0d08/src/paymasters/NEETH.sol)

**Inherits:**
ERC20

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/NEETH.sol)

Simple wrapped ERC4337 implementation with paymaster and yield functions.


## State Variables
### DAO
========================= CONSTANTS ========================= ///

*The governing DAO address.*


```solidity
address internal constant DAO = 0xDa000000000000d2885F108500803dfBAaB2f2aA;
```


### POOL
*The Uniswap V3 pool on Arbitrum for swapping between WETH & stETH.*


```solidity
address internal constant POOL = 0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537;
```


### WETH
*The WETH contract for wrapping and unwrapping ETH on Arbitrum.*


```solidity
address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
```


### YIELD
*The yield token contract address (in V1, bridged wrapped stETH).*


```solidity
address internal constant YIELD = 0x5979D7b546E38E414F7E9822514be443A4800529;
```


### EP06
*A canonical ERC4337 EntryPoint contract for NEETH alpha (0.6).*


```solidity
address internal constant EP06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
```


### EP07
*A canonical ERC4337 EntryPoint contract for NEETH alpha (0.7).*


```solidity
address internal constant EP07 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
```


### MIN_SQRT_RATIO_PLUS_ONE
*The minimum value that can be returned from `getSqrtRatioAtTick` (plus one).*


```solidity
uint160 internal constant MIN_SQRT_RATIO_PLUS_ONE = 4295128740;
```


### MAX_SQRT_RATIO_MINUS_ONE
*The maximum value that can be returned from `getSqrtRatioAtTick` (minus one).*


```solidity
uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE =
    1461446703485210103287273052203988822378723970341;
```


### daoFee
========================== STORAGE ========================== ///

*The DAO fee.*


```solidity
uint128 public daoFee;
```


### _postOpCost
*The postOp cost estimate.*


```solidity
uint128 internal _postOpCost;
```


## Functions
### onlyDAO

========================= MODIFIERS ========================= ///

*Requires that the caller is the DAO.*


```solidity
modifier onlyDAO() virtual;
```

### onlyEntryPoint06

*Requires that the caller is the EntryPoint (0.6).*


```solidity
modifier onlyEntryPoint06() virtual;
```

### onlyEntryPoint07

*Requires that the caller is the EntryPoint (0.7).*


```solidity
modifier onlyEntryPoint07() virtual;
```

### name

======================= ERC20 METADATA ======================= ///

*Returns the name of the token. Here we try and explicate.*


```solidity
function name() public view virtual override returns (string memory);
```

### symbol

*Returns the symbol of the token. NEET shall inherit the earth.*


```solidity
function symbol() public view virtual override returns (string memory);
```

### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs NEETH.*


```solidity
constructor() payable;
```

### deposit

===================== DEPOSIT OPERATIONS ===================== ///

*Deposits `msg.value` ETH into NEETH.*


```solidity
function deposit() public payable virtual returns (uint256 neeth);
```

### depositTo

*Deposits `msg.value` ETH into NEETH for `to`.
The output NEETH shares represent swapped stETH.
DAO receives a grant in order to fund concerns.
This DAO fee will pay for itself quick enough.*


```solidity
function depositTo(address to) public payable virtual returns (uint256 neeth);
```

### withdraw

==================== WITHDRAW OPERATIONS ==================== ///

*Burns `amount` NEETH (stETH) of caller and returns ETH.*


```solidity
function withdraw(uint256 amount) public virtual;
```

### withdrawFrom

*Burns `amount` NEETH (stETH) of `from` and sends output ETH for `to`.*


```solidity
function withdrawFrom(address from, address to, uint256 amount) public virtual;
```

### _swap

====================== SWAP OPERATIONS ====================== ///

*Executes a swap across the Uniswap V3 pool on Arbitrum for WETH & stETH.*


```solidity
function _swap(bool zeroForOne, int256 amount) internal virtual returns (uint256);
```

### fallback

*Fallback `uniswapV3SwapCallback`.*


```solidity
fallback() external payable virtual;
```

### _transferYieldToken

*Funds an `amount` of YIELD token (stETH) to pool caller for swap.*


```solidity
function _transferYieldToken(uint256 amount) internal virtual;
```

### _wrapETH

*Wraps an `amount` of ETH to WETH and funds pool caller for swap.*


```solidity
function _wrapETH(uint256 amount) internal virtual;
```

### _unwrapETH

*Unwraps an `amount` of ETH from WETH for return.*


```solidity
function _unwrapETH(uint256 amount) internal virtual;
```

### _safeTransferETH

*Sends an `amount` of ETH for `to`.*


```solidity
function _safeTransferETH(address to, uint256 amount) internal virtual;
```

### receive

*ETH receiver fallback.
Only canonical WETH can call.*


```solidity
receive() external payable virtual;
```

### validatePaymasterUserOp

=================== VALIDATION OPERATIONS =================== ///

*Payment validation 0.6: Check NEETH will cover based on balance.*


```solidity
function validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    public
    payable
    virtual
    onlyEntryPoint06
    returns (bytes memory, uint256);
```

### validatePaymasterUserOp

*Payment validation 0.7: Check NEETH will cover based on balance.*


```solidity
function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32, uint256 maxCost)
    public
    payable
    virtual
    onlyEntryPoint07
    returns (bytes memory, uint256);
```

### postOp

*postOp validation 0.6: Check NEETH conditions are otherwise met.*


```solidity
function postOp(PostOpMode, bytes calldata context, uint256 actualGasCost)
    public
    payable
    virtual
    onlyEntryPoint06;
```

### postOp

*postOp validation 0.7: Check NEETH conditions are otherwise met.*


```solidity
function postOp(
    PostOpMode,
    bytes calldata context,
    uint256 actualGasCost,
    uint256 actualUserOpFeePerGas
) public payable virtual onlyEntryPoint07;
```

### addStake

===================== STAKING OPERATIONS ===================== ///

*Adds stake to EntryPoint (if `old`, version 0.6 is used).*


```solidity
function addStake(bool old, uint32 unstakeDelaySec) public payable virtual onlyDAO;
```

### unlockStake

*Unlocks stake from EntryPoint (if `old`, version 0.6 is used).*


```solidity
function unlockStake(bool old) public virtual onlyDAO;
```

### withdrawStake

*Withdraws stake from EntryPoint (if `old`, version 0.6 is used).*


```solidity
function withdrawStake(bool old, address payable withdrawAddress) public virtual onlyDAO;
```

### withdrawTo

*Withdraws EntryPoint deposits under DAO governance (if `old`, version 0.6 is used).*


```solidity
function withdrawTo(bool old, address payable withdrawAddress, uint256 withdrawAmount)
    public
    virtual
    onlyDAO;
```

### setFee

=================== GOVERNANCE OPERATIONS =================== ///

*Sets fee under DAO governance from NEETH minting.*


```solidity
function setFee(uint128 _daoFee) public virtual onlyDAO;
```

### setPostOpCost

*Sets cost estimate under DAO governance from NEETH postOp.*


```solidity
function setPostOpCost(uint128 postOpCost) public virtual onlyDAO;
```

## Structs
### UserOperation
========================== STRUCTS ========================== ///

*The ERC4337 user operation (userOp) struct (0.6).*


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

## Enums
### PostOpMode
=========================== ENUMS =========================== ///

*The ERC4337 post-operation (postOp) enum.*


```solidity
enum PostOpMode {
    opSucceeded,
    opReverted,
    postOpReverted
}
```

