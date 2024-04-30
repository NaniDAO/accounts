# Token
[Git Source](https://github.com/NaniDAO/accounts/blob/63982073a58fb6da94e594d61906f20468a541f4/src/governance/Token.sol)

**Author:**
nani.eth (Nani DAO)

Simple ERC20 token.


## State Variables
### name

```solidity
string public constant name = "NANI";
```


### symbol

```solidity
string public constant symbol = unicode"⌘";
```


### decimals

```solidity
uint256 public constant decimals = 18;
```


### totalSupply

```solidity
uint256 public constant totalSupply = 1e27;
```


### balanceOf

```solidity
mapping(address => uint256) public balanceOf;
```


### allowance

```solidity
mapping(address => mapping(address => uint256)) public allowance;
```


## Functions
### constructor


```solidity
constructor() payable;
```

### approve


```solidity
function approve(address to, uint256 amount) public payable returns (bool);
```

### transfer


```solidity
function transfer(address to, uint256 amount) public payable returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) public payable returns (bool);
```

## Events
### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

### Approval

```solidity
event Approval(address indexed from, address indexed to, uint256 amount);
```

