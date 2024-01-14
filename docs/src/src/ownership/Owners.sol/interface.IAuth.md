# IAuth
[Git Source](https://github.com/NaniDAO/accounts/blob/7ac59b02001a809e2cf6d349a24270ca5342f835/src/ownership/Owners.sol)

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

