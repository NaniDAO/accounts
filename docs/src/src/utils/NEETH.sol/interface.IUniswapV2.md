# IUniswapV2
[Git Source](https://github.com/NaniDAO/accounts/blob/8328e5c25cabbe5c5a4de81be1529d0f8371cfb5/src/utils/NEETH.sol)

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

