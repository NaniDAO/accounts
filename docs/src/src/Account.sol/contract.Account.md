# Account
[Git Source](https://github.com/NaniDAO/accounts/blob/5fb58fdce3270268f936c106a598fde6c6147d24/src/Account.sol)

**Inherits:**
ERC4337

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)

Simple extendable smart account implementation. Includes plugin tooling.


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
    override(ERC4337)
    onlyEntryPoint
    payPrefund(missingAccountFunds)
    returns (uint256);
```

### _validateUserOp

*Extends ERC4337 userOp validation with stored ERC7582 validator plugins.*


```solidity
function _validateUserOp() internal virtual returns (uint256 validationData);
```

### isValidSignature

*Extends ERC1271 signature verification with stored validator plugin.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature)
    public
    view
    virtual
    override
    returns (bytes4);
```

