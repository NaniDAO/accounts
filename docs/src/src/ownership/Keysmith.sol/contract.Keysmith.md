# Keysmith
[Git Source](https://github.com/NaniDAO/accounts/blob/ce662883d04645306a7e3363a72f54ee359035a3/src/ownership/Keysmith.sol)

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

