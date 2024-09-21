# Guard
[Git Source](https://github.com/NaniDAO/accounts/blob/7de36a3d39c803832cd611fb5f109f5ac92c99ae/src/authority/Guard.sol)

Simple smart account guard for installing asset transfer limits.


## State Variables
### ETH
========================= CONSTANTS ========================= ///

*The conventional ERC7528 ETH address.*


```solidity
address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


### accountLimit
========================== STORAGE ========================== ///

*The account settings for a given `asset` and `limit` installed in guard.*


```solidity
mapping(address account => mapping(address asset => uint256)) public accountLimit;
```


### accountList
*The permitted recipients of transfers generally.*


```solidity
mapping(address account => address[]) public accountList;
```


### owners
*The owners of the account permitted to sign.*


```solidity
mapping(address account => address owner) public owners;
```


## Functions
### onlyOwner

========================= MODIFIERS ========================= ///

*Requires that the caller is the `account` owner.*


```solidity
modifier onlyOwner(address account) virtual;
```

### guardedExecute

====================== GUARDED EXECUTE ====================== ///

*Executes guarded transaction for the given `account` directly by the owner.*


```solidity
function guardedExecute(address account, address target, uint256 value, bytes calldata data)
    public
    payable
    virtual
    onlyOwner(account)
    returns (bytes memory);
```

### install

======================== INSTALLATION ======================== ///

*Installs the account asset transfer guard settings for the caller account.
note: Finalizes with transfer request in two-step pattern.
See, e.g., Ownable.sol:
https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol*


```solidity
function install(address owner, address asset, uint256 limit, address[] calldata list)
    public
    virtual;
```

### setOwner

*Sets the owner for a given account. Settings are restricted in this manner.*


```solidity
function setOwner(address account, address owner) public virtual onlyOwner(account);
```

### setLimit

*Sets an account asset limit. Amounts may never exceed in single transaction.*


```solidity
function setLimit(address account, address asset, uint256 limit)
    public
    virtual
    onlyOwner(account);
```

### setList

*Sets the valid recipient list for all account asset transfers.*


```solidity
function setList(address account, address[] calldata list) public virtual onlyOwner(account);
```

## Events
### LimitSet
=========================== EVENTS =========================== ///

*Logs the installation of an asset transfer limit for an account.*


```solidity
event LimitSet(address indexed account, address asset, uint256 limit);
```

### ListSet
*Logs the installation of a new recipient list for an account.*


```solidity
event ListSet(address indexed account, address[] list);
```

### OwnerSet
*Logs the installation of a new owner for an account.*


```solidity
event OwnerSet(address indexed account, address owner);
```

## Errors
### Unauthorized
======================= CUSTOM ERRORS ======================= ///

*Invalid caller.*


```solidity
error Unauthorized();
```

### InvalidSelector
*Invalid selector for the given asset call.*


```solidity
error InvalidSelector();
```

### InvalidTo
*The transfer recipient is not on account list.*


```solidity
error InvalidTo();
```

### OverTheLimit
*Transfer exceeds the account limit guard settings.*


```solidity
error OverTheLimit();
```

