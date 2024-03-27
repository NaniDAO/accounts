# Accounts
[Git Source](https://github.com/NaniDAO/accounts/blob/485961b82d85978443ccbce7f93af4f2cad12381/src/Accounts.sol)

**Inherits:**
ERC4337Factory

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Accounts.sol)

Simple extendable smart account factory implementation.


## State Variables
### _OWNER
*Holds an immutable owner.*


```solidity
address internal immutable _OWNER;
```


## Functions
### constructor

*Constructs this factory to deploy the implementation.
Additionally, sets owner account for peripheral concerns.*


```solidity
constructor(address erc4337) payable ERC4337Factory(erc4337);
```

### get

*Tracks mappings of selectors to executors the owner has delegated to.*


```solidity
function get(bytes4 selector) public view virtual returns (address executor);
```

### set

*Delegates peripheral call concerns. Can only be called by owner.*


```solidity
function set(bytes4 selector, address executor) public payable virtual;
```

### fallback

*Falls back to delegated calls.*


```solidity
fallback() external payable;
```

