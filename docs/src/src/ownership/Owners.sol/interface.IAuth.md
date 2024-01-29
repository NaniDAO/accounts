# IAuth
[Git Source](https://github.com/NaniDAO/accounts/blob/18e4de3b2fb3996b09e97d68ddd15b6c11bd0a87/src/ownership/Owners.sol)

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

