# AccountURL
[Git Source](https://github.com/NaniDAO/accounts/blob/e8688d40b41a4f91d7244ea40c12251a38f039f2/src/AccountURL.sol)

**Inherits:**
ERC4337

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/AccountURL.sol)

Simple unruggable smart account implementation. Includes plugin tooling.


## State Variables
### _NULL_HASH
*Prehash of `keccak256("")` for validation efficiency.*


```solidity
bytes32 internal constant _NULL_HASH =
    0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
```


### _VALIDATE_TYPEHASH
*EIP712 typehash as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
Derived from `userOp` without the signature and the time fields of `validUntil` and `validAfter`.*


```solidity
bytes32 internal constant _VALIDATE_TYPEHASH =
    0xa9a214c6f6d90f71d094504e32920cfd4d8d53e5d7cf626f9a26c88af60081c7;
```


### rugPercent
*Rug percentage.*


```solidity
uint256 public rugPercent;
```


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
    override(EIP712)
    returns (string memory, string memory);
```

### validateUserOp

*Validates userOp
with nonce handling.*


```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32, uint256 missingAccountFunds)
    external
    payable
    virtual
    override(ERC4337)
    onlyEntryPoint
    payPrefund(missingAccountFunds)
    returns (uint256);
```

### _validateUserOpSignature

*Validates `userOp.signature` for the EIP712-encoded `userOp`.*


```solidity
function _validateUserOpSignature(PackedUserOperation calldata userOp)
    internal
    virtual
    returns (uint256);
```

### __hashTypedData

*Encodes `userOp` and extracted time window within EIP712 syntax.*


```solidity
function __hashTypedData(PackedUserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
    internal
    view
    virtual
    returns (bytes32 digest);
```

### _calldataKeccak

*Keccak function over calldata. This is more efficient than letting Solidity do it.*


```solidity
function _calldataKeccak(bytes calldata data) internal pure virtual returns (bytes32 hash);
```

### _validateUserOp

*Extends ERC4337 userOp validation in stored ERC7582 validator plugin.*


```solidity
function _validateUserOp() internal virtual returns (uint256 validationData);
```

### isValidSignature

*Validates ERC1271 signature. Plugin activated if stored.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature)
    public
    view
    virtual
    override(ERC1271)
    returns (bytes4);
```

### execute

*Execute a guarded call from this account.*


```solidity
function execute(address target, uint256 value, bytes calldata data)
    public
    payable
    virtual
    override(ERC4337)
    onlyEntryPointOrOwner
    returns (bytes memory result);
```

### executeBatch

*Execute a sequence of guarded calls from this account.*


```solidity
function executeBatch(Call[] calldata calls)
    public
    payable
    virtual
    override(ERC4337)
    onlyEntryPointOrOwner
    returns (bytes[] memory results);
```

### delegateExecute

*Execute a guarded delegatecall with `delegate` on this account.*


```solidity
function delegateExecute(address delegate, bytes calldata data)
    public
    payable
    virtual
    override(ERC4337)
    onlyEntryPointOrOwner
    delegateExecuteGuard
    returns (bytes memory result);
```

### setRugPercent

*Locking function where user `owner()` or EntryPoint can set call `rugPercent`.*


```solidity
function setRugPercent(uint256 _rugPercent) public payable onlyEntryPointOrOwner;
```

