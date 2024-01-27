# Invites
[Git Source](https://github.com/NaniDAO/accounts/blob/9816e093f3a0f1ad1a51334704e0815733ea9e74/src/governance/Invites.sol)

**Inherits:**
ERC721

Simple NFT contract for sending out custom invites.

*Recipients can mint new invites after the `delay` passes.*


## State Variables
### delay
========================= CONSTANTS ========================= ///

*Timed delay set for each mint.*


```solidity
uint256 public constant delay = 1 hours;
```


### messages
========================== STORAGE ========================== ///

*Message for each invite.*


```solidity
mapping(uint256 id => string message) public messages;
```


### lastSent
*Timestamp for each user's last invitation sent.*


```solidity
mapping(address user => uint256 timestamp) public lastSent;
```


## Functions
### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs
this implementation.
Initializes owner too.*


```solidity
constructor() payable;
```

### invite

====================== INVITATION MINT ====================== ///

*Sends out invite NFT for `to` with `message`.
If not owner (0) account, `msg.sender` must have NFT,
as well as pass the timed delay after their first mint.*


```solidity
function invite(address to, string calldata message) public payable virtual;
```

### name

====================== ERC721 METADATA ====================== ///

*Returns the token collection name.*


```solidity
function name() public view virtual override(ERC721) returns (string memory);
```

### symbol

*Returns the token collection symbol.*


```solidity
function symbol() public view virtual override(ERC721) returns (string memory);
```

### tokenURI

*Returns the Uniform Resource Identifier (URI) for token `id`.*


```solidity
function tokenURI(uint256 id) public view virtual override(ERC721) returns (string memory);
```

### _createURI

*Creates the URI for token `id`.*


```solidity
function _createURI(uint256 id) internal view virtual returns (string memory);
```

### _createImage

*Creates the image for token `id`.*


```solidity
function _createImage(uint256 id) internal view virtual returns (string memory);
```

## Errors
### Unauthorized
======================= CUSTOM ERRORS ======================= ///

*The caller is not authorized to call the function.*


```solidity
error Unauthorized();
```

### DelayPending
*The time delay is still pending from the last mint.*


```solidity
error DelayPending();
```

### MessageTooLong
*The `message` exceeds the 20 character limit.*


```solidity
error MessageTooLong();
```

