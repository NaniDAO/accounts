# Account
[Git Source](https://github.com/NaniDAO/accounts/blob/fd90579c871d0f59555da77a20211a8d3c53e980/src/Account.sol)

**Inherits:**
ERC4337

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)

Simple extendable smart account implementation.


## Functions
### constructor

*Constructs
this implementation.*


```solidity
constructor() payable;
```

### _domainNameAndVersion

*Returns domain name
& version of implementation.*


```solidity
function _domainNameAndVersion()
    internal
    pure
    virtual
    override
    returns (string memory, string memory);
```

### validateUserOp

*Validates userOp
with nonce handling.*


```solidity
function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
)
    external
    payable
    virtual
    override
    onlyEntryPoint
    payPrefund(missingAccountFunds)
    returns (uint256);
```

### _validateUserOp

*Extends validation by forwarding calldata to validator.*


```solidity
function _validateUserOp() internal virtual returns (uint256);
```

