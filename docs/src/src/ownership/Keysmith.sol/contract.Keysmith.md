# Keysmith
[Git Source](https://github.com/NaniDAO/accounts/blob/18e4de3b2fb3996b09e97d68ddd15b6c11bd0a87/src/ownership/Keysmith.sol)

Simple summoner for Nani (𒀭) token-bound accounts.


## State Variables
### KEYS

```solidity
address internal constant KEYS = 0x000000000000082ffb07deF3DdfB5D3AFA9b9668;
```


### FACTORY

```solidity
IAccounts internal constant FACTORY = IAccounts(0x000000000000dD366cc2E4432bB998e41DFD47C7);
```


## Functions
### constructor


```solidity
constructor() payable;
```

### summon


```solidity
function summon(address nft, uint256 id, bytes12 salt) public payable returns (IAccounts account);
```

