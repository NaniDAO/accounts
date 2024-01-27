# Keys
[Git Source](https://github.com/NaniDAO/accounts/blob/9816e093f3a0f1ad1a51334704e0815733ea9e74/src/ownership/Keys.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/ownership/Keys.sol)

Simple token-bound ownership singleton for smart accounts.

*The Keys singleton approximates ERC6551 token-bound account ownership with NFTs.*


## State Variables
### _settings
========================== STORAGE ========================== ///

*Stores mapping of ownership settings to accounts.*


```solidity
mapping(address account => Settings) internal _settings;
```


## Functions
### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs
this implementation.*


```solidity
constructor() payable;
```

### isValidSignature

=================== VALIDATION OPERATIONS =================== ///

*Validates ERC1271 signature with additional check for NFT ID ownership.
note: This implementation is designed to be the ERC-173-owner-of-4337-accounts.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature)
    public
    view
    virtual
    returns (bytes4);
```

### validateUserOp

*Validates ERC4337 userOp with additional auth logic flow among owners.
note: This is expected to be called in a validator plugin-like userOp flow.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    public
    payable
    virtual
    returns (uint256 validationData);
```

### _ownerOf

*Returns the `owner` of the given `nft` `id`.*


```solidity
function _ownerOf(address nft, uint256 id) internal view virtual returns (address owner);
```

### _validateReturn

*Returns validated signature result within the conventional ERC1271 syntax.*


```solidity
function _validateReturn(bool success) internal pure virtual returns (bytes4 result);
```

### install

================== INSTALLATION OPERATIONS ================== ///

*Initializes ownership settings for the caller account.
note: Finalizes with transfer request in two-step pattern.
See, e.g., Ownable.sol:
https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol*


```solidity
function install(address nft, uint256 id, IAuth auth) public payable virtual;
```

### getSettings

===================== OWNERSHIP SETTINGS ===================== ///

*Returns the account settings.*


```solidity
function getSettings(address account) public view virtual returns (address, uint256, IAuth);
```

### setAuth

*Sets new authority contract for the caller account.*


```solidity
function setAuth(IAuth auth) public payable virtual;
```

### setToken

*Sets new NFT ownership details for the caller account.*


```solidity
function setToken(address nft, uint256 id) public payable virtual;
```

## Events
### AuthSet
=========================== EVENTS =========================== ///

*Logs new authority contract for an account.*


```solidity
event AuthSet(address indexed account, IAuth auth);
```

### TokenSet
*Logs new NFT ownership settings for an account.*


```solidity
event TokenSet(address indexed account, address NFT, uint256 id);
```

## Structs
### Settings
========================== STRUCTS ========================== ///

*The NFT ownership settings struct.*


```solidity
struct Settings {
    address nft;
    uint256 id;
    IAuth auth;
}
```

### UserOperation
*The ERC4337 user operation (userOp) struct.*


```solidity
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}
```

