# Points
[Git Source](https://github.com/NaniDAO/accounts/blob/7de36a3d39c803832cd611fb5f109f5ac92c99ae/src/governance/Points.sol)

Simple onchain points allocation protocol.


## State Variables
### owner

```solidity
address public immutable owner;
```


### rate

```solidity
uint256 public immutable rate;
```


### claimed

```solidity
mapping(address => uint256) public claimed;
```


## Functions
### constructor

*Constructs owned contract with issuance rate.*


```solidity
constructor(address _owner, uint256 _rate) payable;
```

### check

*Check the user's points score from a signed starting time and bonus.*


```solidity
function check(address user, uint256 start, uint256 bonus, bytes calldata signature)
    public
    view
    returns (uint256 score);
```

### claim

*Claim unredeemed points for tokens from a signed starting time and bonus.*


```solidity
function claim(IERC20 token, uint256 start, uint256 bonus, bytes calldata signature)
    public
    payable;
```

### _toEthSignedMessageHash

*Returns an Ethereum Signed Message, created from a `hash`.*


```solidity
function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result);
```

