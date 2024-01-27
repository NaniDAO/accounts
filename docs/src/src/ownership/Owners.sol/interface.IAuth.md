# IAuth
[Git Source](https://github.com/NaniDAO/accounts/blob/9816e093f3a0f1ad1a51334704e0815733ea9e74/src/ownership/Owners.sol)

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

