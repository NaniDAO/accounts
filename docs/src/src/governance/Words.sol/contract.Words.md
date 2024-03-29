# Words
[Git Source](https://github.com/NaniDAO/accounts/blob/a92c3cc254412087f583cadf96cf750857c126d2/src/governance/Words.sol)

**Inherits:**
ERC721

*A simple NFT contract for worded IDs.*


## Functions
### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs
this implementation.*


```solidity
constructor() payable;
```

### mint

======================== MINT & BURN ======================== ///

*Open mint function to claim public chain `word` for `to`.*


```solidity
function mint(address to, string calldata word) public payable virtual;
```

### burn

*Open burn function to unclaim public chain `word`.*


```solidity
function burn(string calldata word) public payable virtual;
```

### name

====================== ERC721 METADATA ====================== ///

*Returns the token collection name.*


```solidity
function name() public view virtual override returns (string memory);
```

### symbol

*Returns the token collection symbol.*


```solidity
function symbol() public view virtual override returns (string memory);
```

### tokenURI

*Returns the Uniform Resource Identifier (URI) for token `id`.*


```solidity
function tokenURI(uint256 id) public view virtual override returns (string memory);
```

