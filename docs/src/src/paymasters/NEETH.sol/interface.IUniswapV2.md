# IUniswapV2
[Git Source](https://github.com/NaniDAO/accounts/blob/18e4de3b2fb3996b09e97d68ddd15b6c11bd0a87/src/paymasters/NEETH.sol)

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

