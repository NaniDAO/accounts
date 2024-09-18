# Passkeys
[Git Source](https://github.com/NaniDAO/accounts/blob/e8688d40b41a4f91d7244ea40c12251a38f039f2/src/ownership/Passkeys.sol)

*Simple singleton to store passkey ownership and backups for accounts.*


## State Variables
### backups
========================== STORAGE ========================== ///

*Stores mapping of onchain backup address activity statuses to accounts.*


```solidity
mapping(address account => mapping(address backup => bool active)) public backups;
```


### passkeys
*Stores mapping of passkey `x` `y` pairings to accounts. Null revokes.*


```solidity
mapping(address account => mapping(bytes32 x => bytes32 y)) public passkeys;
```


## Functions
### isValidSignature

=================== VALIDATION OPERATIONS =================== ///

*Validates ERC1271 signature packed as `r`, `s`, `x`, `y`.
note: Includes fallback to check if first 20 bytes is backup.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature)
    public
    view
    virtual
    returns (bytes4 result);
```

### install

======================== INSTALLATION ======================== ///

*Adds onchain backup addresses and passkey `x` `y` pairings for the caller account.*


```solidity
function install(address[] calldata _backups, Passkey[] calldata _passkeys) public virtual;
```

### setBackup

*Sets onchain backup address activity status for the caller account.*


```solidity
function setBackup(address backup, bool active) public virtual;
```

### setPasskey

*Sets passkey `x` `y` pairing for the caller account.*


```solidity
function setPasskey(bytes32 x, bytes32 y) public virtual;
```

## Events
### BackupSet
=========================== EVENTS =========================== ///

*Logs new onchain backup activity status for an account.*


```solidity
event BackupSet(address indexed account, address backup, bool active);
```

### PasskeySet
*Logs new passkey `x` `y` pairing for an account.
note: Revocation is done by setting `y` to nothing.*


```solidity
event PasskeySet(address indexed account, bytes32 x, bytes32 y);
```

## Structs
### Passkey
========================== STRUCTS ========================== ///

*Passkey pair.*


```solidity
struct Passkey {
    bytes32 x;
    bytes32 y;
}
```

