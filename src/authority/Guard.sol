// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {LibSort} from "@solady/src/utils/LibSort.sol";

/// @notice Simple smart account guard for installing asset transfer limits.
/// @custom:version 0.0.0
contract Guard {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Invalid caller.
    error Unauthorized();

    /// @dev Invalid selector for the given asset call.
    error InvalidSelector();

    /// @dev The transfer recipient is not on account list.
    error InvalidTo();

    /// @dev Transfer exceeds the account limit guard settings.
    error OverTheLimit();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the installation of an asset transfer limit for an account.
    event LimitSet(address indexed account, address asset, uint256 limit);

    /// @dev Logs the installation of a new recipient list for an account.
    event ListSet(address indexed account, address[] list);

    /// @dev Logs the installation of a new owner for an account.
    event OwnerSet(address indexed account, address owner);

    /// ========================= CONSTANTS ========================= ///

    /// @dev The conventional ERC7528 ETH address.
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// ========================== STORAGE ========================== ///

    /// @dev The account settings for a given `asset` and `limit` installed in guard.
    mapping(address account => mapping(address asset => uint256)) public accountLimit;

    /// @dev The permitted recipients of transfers generally.
    mapping(address account => address[]) public accountList;

    /// @dev The owners of the account permitted to sign.
    mapping(address account => address owner) public owners;

    /// ========================= MODIFIERS ========================= ///

    /// @dev Requires that the caller is the `account` owner.
    modifier onlyOwner(address account) virtual {
        if (msg.sender != owners[account]) revert Unauthorized();
        _;
    }

    /// ====================== GUARDED EXECUTE ====================== ///

    /// @dev Executes guarded transaction for the given `account` directly by the owner.
    function guardedExecute(address account, address target, uint256 value, bytes calldata data)
        public
        payable
        virtual
        onlyOwner(account)
        returns (bytes memory)
    {
        address asset = value != 0 ? ETH : target;
        uint256 limit = accountLimit[account][asset];
        if (asset == ETH) {
            if (value > limit) revert OverTheLimit();
            if (accountList[account].length != 0) {
                (bool isValidTo,) = LibSort.searchSorted(accountList[account], target);
                if (!isValidTo) revert InvalidTo();
            }
            return IAccount(account).execute{value: msg.value}(target, value, data);
        } else {
            if (bytes4(data) != IERC20.transfer.selector) revert InvalidSelector();
            (address to, uint256 amount) = abi.decode(data[4:], (address, uint256));
            if (amount > limit) revert OverTheLimit();
            if (accountList[account].length != 0) {
                (bool isValidTo,) = LibSort.searchSorted(accountList[account], to);
                if (!isValidTo) revert InvalidTo();
            }
            return IAccount(account).execute(target, value, data);
        }
    }

    /// ======================== INSTALLATION ======================== ///

    /// @dev Installs the account asset transfer guard settings for the caller account.
    /// note: Finalizes with transfer request in two-step pattern.
    /// See, e.g., Ownable.sol:
    /// https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol
    function install(address owner, address asset, uint256 limit, address[] calldata list)
        public
        virtual
    {
        emit LimitSet(msg.sender, asset, accountLimit[msg.sender][asset] = limit);
        emit ListSet(msg.sender, accountList[msg.sender] = list);
        emit OwnerSet(
            msg.sender,
            owner == address(0)
                ? owners[msg.sender] = IOwnable(msg.sender).owner()
                : owners[msg.sender] = owner
        );
        try IOwnable(msg.sender).requestOwnershipHandover() {} catch {} // Avoid revert.
    }

    /// @dev Sets the owner for a given account. Settings are restricted in this manner.
    function setOwner(address account, address owner) public virtual onlyOwner(account) {
        emit OwnerSet(account, owners[account] = owner);
    }

    /// @dev Sets an account asset limit. Amounts may never exceed in single transaction.
    function setLimit(address account, address asset, uint256 limit)
        public
        virtual
        onlyOwner(account)
    {
        emit LimitSet(account, asset, accountLimit[account][asset] = limit);
    }

    /// @dev Sets the valid recipient list for all account asset transfers.
    function setList(address account, address[] calldata list) public virtual onlyOwner(account) {
        emit ListSet(account, accountList[account] = list);
    }
}

/// @notice ERC20 token transfer interface.
interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}

/// @notice Simple smart account ownership interface.
interface IOwnable {
    function owner() external view returns (address);
    function requestOwnershipHandover() external payable;
}

/// @notice Smart account execution interface.
interface IAccount {
    function execute(address, uint256, bytes calldata) external payable returns (bytes memory);
}
