# IAuth
[Git Source](https://github.com/NaniDAO/accounts/blob/ce662883d04645306a7e3363a72f54ee359035a3/src/ownership/Owners.sol)

Simple authority interface for contracts.


## Functions
### validateTransfer


```solidity
function validateTransfer(address, address, uint256, uint256) external payable returns (uint256);
```

### validateCall


```solidity
function validateCall(address, address, uint256, bytes calldata)
    external
    payable
    returns (uint256);
```

