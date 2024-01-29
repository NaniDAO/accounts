# IUniswapV2
[Git Source](https://github.com/NaniDAO/accounts/blob/ce662883d04645306a7e3363a72f54ee359035a3/src/paymasters/NEETH.sol)

Interface for Uniswap V2.


## Functions
### getReserves


```solidity
function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
```

### swap


```solidity
function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
```

