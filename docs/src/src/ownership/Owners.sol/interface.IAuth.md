# IAuth
[Git Source](https://github.com/NaniDAO/accounts/blob/42fc8acdca84a327e1f103322fde5ce32d0ac500/src/ownership/Owners.sol)

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

