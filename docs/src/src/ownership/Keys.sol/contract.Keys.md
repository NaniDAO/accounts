# Keys
[Git Source](https://github.com/NaniDAO/accounts/blob/7ac59b02001a809e2cf6d349a24270ca5342f835/src/ownership/Keys.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/ownership/Keys.sol)

Simple token-bound ownership singleton for smart accounts.


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

### install

================== INSTALLATION OPERATIONS ================== ///

*Initializes ownership settings for the caller account.
note: Finalizes with transfer request in two-step pattern.
See, e.g., Ownable.sol:
https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol*


```solidity
function install(INFTOwner nft, uint256 id, IAuth auth) public payable virtual;
```

### getSettings

===================== OWNERSHIP SETTINGS ===================== ///

*Returns the account settings.*


```solidity
function getSettings(address account) public view virtual returns (INFTOwner, uint256, IAuth);
```

### setAuth

*Sets new authority contract for the caller account.*


```solidity
function setAuth(IAuth auth) public payable virtual;
```

### setToken

*Sets new NFT ownership details for the caller account.*


```solidity
function setToken(INFTOwner nft, uint256 id) public payable virtual;
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
event TokenSet(address indexed account, INFTOwner NFT, uint256 id);
```

## Structs
### Settings
========================== STRUCTS ========================== ///

*The NFT ownership settings struct.*


```solidity
struct Settings {
    INFTOwner nft;
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

