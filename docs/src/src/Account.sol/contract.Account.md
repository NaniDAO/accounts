# Account
[Git Source](https://github.com/NaniDAO/accounts/blob/63982073a58fb6da94e594d61906f20468a541f4/src/Account.sol)

**Inherits:**
ERC4337

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)

Simple extendable smart account implementation. Includes secp256r1 auth.


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
    returns (uint256 validationData);
```

### _validateUserOp

*Extends ERC4337 userOp validation with ERC7582 plugin validator flow.*


```solidity
function _validateUserOp() internal virtual returns (uint256 validationData);
```

### isValidSignature

*Extends ERC1271 signature verification with secp256r1.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature)
    public
    view
    virtual
    override
    returns (bytes4 result);
```

