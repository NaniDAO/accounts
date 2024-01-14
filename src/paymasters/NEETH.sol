// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@solady/src/tokens/ERC20.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/FixedPointMathLib.sol";

/// @notice Simple wrapped ERC4337 implementation with paymaster and yield functions.
/// @dev The strategy for ether (ETH) deposits defaults to Lido for this alpha version.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/NETH.sol)
/// @custom:lex The user agrees that the following terms apply to use:
///             This smart contract ("NEETH") is being provided as is.
///             No guarantee, representation or warranty is being made
///             as to the safety or correctness of NEETH applications.
///             Users should proceed with care and at their own risks.
/// @custom:version 0.0.0
/* note:
    Users should be able to get credit for gas using NEETH.
    This means that they can earn NEETH or buy it as ERC20.
    NEETH should not be just ETH sitting in Entry Point.
    It should earn yield upon minting from ETH staking.
    Lido is used by default. stETH is minted for ETH.
    NEETH holds the stETH from ETH deposits for user.
    When users want to pay for Entry Point user ops,
    NEETH is burned to unlock the underlying stETH,
    and uniswap that for enough ETH to pay for tx.
*/
contract NEETH is ERC20 {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Balance is too low for the verification of user operation.
    error BalanceTooLowForUserOp();

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// ========================= CONSTANTS ========================= ///

    /// @dev The Uniswap V2 pool for swapping stETH for WETH.
    IUniswapV2 internal constant _POOL = IUniswapV2(0x4028DAAC072e492d34a3Afdbef0ba7e35D8b55C4);

    /// @dev The WETH contract for unwrapping ETH.
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /// @dev The canonical ERC4337 EntryPoint contract for NEETH alpha.
    address payable internal constant _ENTRY_POINT =
        payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// @dev The designated ETH strategy contract (Lido) for NEETH alpha.
    address payable internal constant _STRATEGY =
        payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    /// @dev Holds a constant postOp cost estimate.
    uint256 internal constant _COST_OF_POST = 15000;

    /// ========================= IMMUTABLES ========================= ///

    /// @dev Holds an immutable owner.
    address payable internal immutable _OWNER;

    /// ========================== STRUCTS ========================== ///

    /// @dev The ERC4337 user operation (userOp) struct.
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

    /// ========================= MODIFIERS ========================= ///

    /// @dev Requires that the caller is the EntryPoint.
    modifier onlyEntryPoint() virtual {
        if (msg.sender != _ENTRY_POINT) revert Unauthorized();
        _;
    }

    /// @dev Requires that the caller is the owner.
    modifier onlyOwner() virtual {
        if (msg.sender != _OWNER) revert Unauthorized();
        _;
    }

    /// ======================= ERC20 METADATA ======================= ///

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return "Nani EntryPoint Ether";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return "NEETH";
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs this owned implementation.
    constructor(address payable owner) payable {
        _OWNER = owner;
    }

    /// ===================== DEPOSIT OPERATIONS ===================== ///

    /// @dev Deposits `msg.value` ETH of the caller for NEETH..
    function deposit() public payable virtual {
        depositTo(msg.sender);
    }

    /// @dev Deposits `msg.value` ETH of the caller and mints NEETH shares for `to`.
    function depositTo(address to) public payable virtual {
        SafeTransferLib.safeTransferETH(_STRATEGY, msg.value); // Get back stETH.
        unchecked {
            _mint(to, msg.value); // Mint equal shares.
        }
    }

    /// ==================== WITHDRAW OPERATIONS ==================== ///

    /// @dev Burns `amount` NEETH of the caller and sends `amount` ETH to the caller.
    function withdraw(uint256 amount) public virtual {
        withdrawFrom(msg.sender, msg.sender, amount);
    }

    /// @dev Burns `amount` NEETH of the `from` and sends `amount` ETH to the `to`.
    function withdrawFrom(address from, address to, uint256 amount) public virtual {
        unchecked {
            if (msg.sender != from) _spendAllowance(from, msg.sender, amount);
            uint256 share = FixedPointMathLib.mulDiv(
                amount, ERC20(_STRATEGY).balanceOf(address(this)), totalSupply()
            );
            _burn(from, amount); // Burn NEETH.
            _swap(share, to); // Swap stETH for ETH.
        }
    }

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Payment validation: check if paymaster agrees to pay.
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 maxCost
    )
        public
        payable
        virtual
        onlyEntryPoint
        returns (bytes memory context, uint256 validationData)
    {
        if (_getAmountOutInETH(balanceOf(userOp.sender)) < maxCost) revert BalanceTooLowForUserOp();
        return (abi.encode(userOp.sender), 0);
    }

    /// @dev Post-operation (postOp) handler.
    function postOp(PostOpMode, bytes calldata context, uint256 actualGasCost)
        public
        payable
        virtual
        onlyEntryPoint
    {
        unchecked {
            uint256 sharesToBurn = _getAmountOutInShares(actualGasCost + _COST_OF_POST);
            address sender = abi.decode(context, (address));
            _swap(sharesToBurn, _ENTRY_POINT); // Fund the EntryPoint.
            _burn(sender, sharesToBurn); // Burn cost in sender shares.
        }
    }

    /// ===================== STAKING OPERATIONS ===================== ///

    /// @dev Add stake for this paymaster. Further sets a staking delay timestamp.
    function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner {
        NEETH(_ENTRY_POINT).addStake{value: msg.value}(unstakeDelaySec);
    }

    /// @dev Unlock the stake, in order to withdraw it.
    function unlockStake() public payable virtual onlyOwner {
        NEETH(_ENTRY_POINT).unlockStake();
    }

    /// @dev Withdraw the entire paymaster's stake. Can select a recipient of this withdrawal.
    function withdrawStake(address payable withdrawAddress) public payable virtual onlyOwner {
        NEETH(_ENTRY_POINT).withdrawStake(withdrawAddress);
    }

    /// ====================== SWAP OPERATIONS ====================== ///

    /// @dev Returns the amount of ETH that would be received for `share` NEETH.
    function _getAmountOutInETH(uint256 share) internal view virtual returns (uint256 amountOut) {
        unchecked {
            (uint256 reserve0, uint256 reserve1,) = _POOL.getReserves();
            return FixedPointMathLib.rawDiv(
                FixedPointMathLib.rawMul(FixedPointMathLib.rawMul(share, 997), reserve0),
                FixedPointMathLib.rawAdd(
                    FixedPointMathLib.rawMul(reserve1, 1000), FixedPointMathLib.rawMul(share, 997)
                )
            );
        }
    }

    /// @dev Returns the amount of NEETH that would be received for `amount` ETH.
    function _getAmountOutInShares(uint256 amount)
        internal
        view
        virtual
        returns (uint256 amountOut)
    {
        unchecked {
            (uint256 reserve0, uint256 reserve1,) = _POOL.getReserves();
            return FixedPointMathLib.rawDiv(
                FixedPointMathLib.rawMul(FixedPointMathLib.rawMul(amount, 997), reserve1),
                FixedPointMathLib.rawAdd(
                    FixedPointMathLib.rawMul(reserve0, 1000), FixedPointMathLib.rawMul(amount, 997)
                )
            );
        }
    }

    /// @dev Swaps `share` NEETH for WETH and transfers ETH for `to`.
    function _swap(uint256 share, address to) internal virtual {
        // Calculate the amount of ETH to be received.
        uint256 amountOut = _getAmountOutInETH(share);
        // Transfer stETH to the Uniswap pair contract for swapping.
        SafeTransferLib.safeTransfer(_STRATEGY, address(_POOL), share);
        // Perform the swap and receive WETH into this contract.
        _POOL.swap(amountOut, 0, address(this), "");
        // Unwrap the WETH to ETH.
        _WETH.withdraw(amountOut);
        // Transfer the `amountOut` of ETH for `to`.
        SafeTransferLib.safeTransferETH(to, amountOut);
    }

    /// ==================== FALLBACK OPERATIONS ==================== ///

    /// @dev Equivalent to `deposit()`.
    receive() external payable virtual {
        deposit();
    }
}

/// @notice Interface for Uniswap V2.
interface IUniswapV2 {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external;
}

/// @notice Interface for WETH V9.
interface IWETH {
    function withdraw(uint256) external;
}

/// @notice Modes for ERC4337 postOp.
enum PostOpMode {
    opSucceeded,
    opReverted,
    postOpReverted
}
