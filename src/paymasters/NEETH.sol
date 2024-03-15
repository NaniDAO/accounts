// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import "@solady/src/tokens/ERC20.sol";

/// @notice Simple wrapped ERC4337 implementation with paymaster and yield functions.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/paymasters/NEETH.sol)
/// @custom:version 1.0.0
contract NEETH is ERC20 {
    /// ========================= CONSTANTS ========================= ///

    /// @dev The governing DAO address.
    address internal constant DAO = 0xDa000000000000d2885F108500803dfBAaB2f2aA;

    /// @dev The mint fee portion granted over for DAO governance.
    uint256 internal constant FEE = 0.0000333 ether;

    /// @dev The Uniswap V3 pool on Arbitrum for swapping between WETH & stETH.
    address internal constant POOL = 0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537;

    /// @dev The WETH contract for wrapping and unwrapping ETH on Arbitrum.
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    /// @dev The yield token contract address (in V1, bridged wrapped stETH).
    address internal constant YIELD = 0x5979D7b546E38E414F7E9822514be443A4800529;

    /// @dev A canonical ERC4337 EntryPoint contract for NEETH alpha (0.6).
    address internal constant EP06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @dev A canonical ERC4337 EntryPoint contract for NEETH alpha (0.7).
    address internal constant EP07 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /// @dev The minimum value that can be returned from `getSqrtRatioAtTick` (plus one).
    uint160 internal constant MIN_SQRT_RATIO_PLUS_ONE = 4295128740;

    /// @dev The maximum value that can be returned from `getSqrtRatioAtTick` (minus one).
    uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE =
        1461446703485210103287273052203988822378723970341;

    /// ========================== STRUCTS ========================== ///

    /// @dev The ERC4337 user operation (userOp) struct (0.6).
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

    /// @dev The packed ERC4337 userOp struct (0.7).
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData;
        bytes signature;
    }

    /// =========================== ENUMS =========================== ///

    /// @dev The ERC4337 post-operation (postOp) enum.
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    /// ========================= MODIFIERS ========================= ///

    /// @dev Requires that the caller is the EntryPoint.
    modifier onlyEntryPoint() virtual {
        assembly ("memory-safe") {
            if iszero(or(eq(caller(), EP07), eq(caller(), EP06))) { revert(codesize(), 0x00) }
        }
        _;
    }

    /// ======================= ERC20 METADATA ======================= ///

    /// @dev Returns the name of the token. Here we try and explicate.
    function name() public view virtual override returns (string memory) {
        return "Nani EntryPoint Ether";
    }

    /// @dev Returns the symbol of the token. NEET shall inherit the earth.
    function symbol() public view virtual override returns (string memory) {
        return "NEETH";
    }

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs NEETH.
    constructor() payable {}

    /// ===================== DEPOSIT OPERATIONS ===================== ///

    /// @dev Deposits `msg.value` ETH into NEETH.
    function deposit() public payable virtual returns (uint256 neeth) {
        return depositTo(msg.sender);
    }

    /// @dev Deposits `msg.value` ETH into NEETH for `to`.
    /// The output NEETH shares represent swapped stETH.
    /// DAO receives a grant in order to fund concerns.
    /// This DAO fee will pay for itself quick enough.
    function depositTo(address to) public payable virtual returns (uint256 neeth) {
        _mint(to, neeth = (_swap(false, int256(msg.value)) /*output stETH*/ - FEE));
        _mint(DAO, FEE);
    }

    /// ==================== WITHDRAW OPERATIONS ==================== ///

    /// @dev Burns `amount` NEETH (stETH) of caller and returns ETH.
    function withdraw(uint256 amount) public payable virtual {
        withdrawFrom(msg.sender, msg.sender, amount);
    }

    /// @dev Burns `amount` NEETH (stETH) of `from` and sends output ETH for `to`.
    function withdrawFrom(address from, address to, uint256 amount) public payable virtual {
        if (msg.sender != from) _spendAllowance(from, msg.sender, amount);
        _burn(from, amount); // Burn NEETH.
        _safeTransferETH(to, _swap(true, int256(amount)));
    }

    /// ====================== SWAP OPERATIONS ====================== ///

    /// @dev Executes a swap across the Uniswap V3 pool on Arbitrum for WETH & stETH.
    function _swap(bool zeroForOne, int256 amount) internal virtual returns (uint256) {
        (int256 amount0, int256 amount1) = ISwapRouter(POOL).swap(
            address(this),
            zeroForOne,
            amount,
            zeroForOne ? MIN_SQRT_RATIO_PLUS_ONE : MAX_SQRT_RATIO_MINUS_ONE,
            abi.encodePacked(zeroForOne)
        );
        if (amount < 0) return uint256(amount0);
        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @dev Fallback `uniswapV3SwapCallback`.
    fallback() external payable virtual {
        uint256 amount0Delta;
        int256 amount1Delta;
        bool zeroForOne;
        assembly ("memory-safe") {
            if iszero(eq(caller(), POOL)) { revert(codesize(), 0x00) }
            amount0Delta := calldataload(0x4)
            amount1Delta := calldataload(0x24)
            zeroForOne := byte(0, calldataload(0x84))
        }
        if (!zeroForOne) {
            _wrapETH(uint256(amount1Delta));
        } else {
            _transferYieldToken(amount0Delta);
            _unwrapETH(uint256(-amount1Delta));
        }
    }

    /// @dev Funds an `amount` of YIELD token (stETH) to pool caller for swap.
    function _transferYieldToken(uint256 amount) internal virtual {
        assembly ("memory-safe") {
            mstore(0x14, caller()) // Store the `pool` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            pop(call(gas(), YIELD, 0, 0x10, 0x44, codesize(), 0x00))
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Wraps an `amount` of ETH to WETH and funds pool caller for swap.
    function _wrapETH(uint256 amount) internal virtual {
        assembly ("memory-safe") {
            pop(call(gas(), WETH, amount, codesize(), 0x00, codesize(), 0x00))
            mstore(0x14, caller()) // Store the `pool` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            pop(call(gas(), WETH, 0, 0x10, 0x44, codesize(), 0x00))
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Unwraps an `amount` of ETH from WETH for return.
    function _unwrapETH(uint256 amount) internal virtual {
        assembly ("memory-safe") {
            mstore(0x00, 0x2e1a7d4d) // `withdraw(uint256)`.
            mstore(0x20, amount) // Store the `amount` argument.
            pop(call(gas(), WETH, 0, 0x1c, 0x24, codesize(), 0x00))
        }
    }

    /// @dev Sends an `amount` of ETH for `to`.
    function _safeTransferETH(address to, uint256 amount) internal virtual {
        assembly ("memory-safe") {
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev ETH receiver fallback.
    /// Only canonical WETH can call.
    receive() external payable virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), WETH)) { revert(codesize(), 0x00) }
        }
    }

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Payment validation: Check NEETH will cover based on balance.
    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32, /*userOpHash*/ uint256 maxCost)
        public
        payable
        virtual
        onlyEntryPoint
        returns (bytes memory, uint256)
    {
        if (balanceOf(userOp.sender) >= maxCost) return (abi.encode(userOp.sender), 0x00);
        return (abi.encode(userOp.sender), 0x01); // TODO: Check this. 
    }

    /// @dev Payment validation (packed): Check NEETH will cover based on balance.
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 maxCost
    ) public payable virtual onlyEntryPoint returns (bytes memory, uint256) {
        if (balanceOf(userOp.sender) >= maxCost) return (abi.encode(userOp.sender), 0x00);
        return (abi.encode(userOp.sender), 0x01);
    }

    /// @dev postOp validation 0.6: Check NEETH conditions are otherwise met.
    function postOp(PostOpMode, bytes calldata context, uint256 actualGasCost)
        public
        payable
        onlyEntryPoint
    {
        uint256 cost = actualGasCost + 30000;
        (address user) = abi.decode(context, (address));
        _burn(user, _swap(true, -int256(cost)));
        assembly ("memory-safe") {
            pop(call(gas(), caller(), cost, codesize(), 0x00, codesize(), 0x00))
        }
    }

    /// @dev postOp validation 0.7: Check NEETH conditions are otherwise met.
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) public payable onlyEntryPoint {
        uint256 cost = actualGasCost + actualUserOpFeePerGas * 30000;
        (address user) = abi.decode(context, (address));
        _burn(user, _swap(true, -int256(cost)));
        assembly ("memory-safe") {
            pop(call(gas(), caller(), cost, codesize(), 0x00, codesize(), 0x00))
        }
    }

    /// ===================== STAKING OPERATIONS ===================== ///

    /// @dev Only the DAO may call.
    modifier onlyDAO() {
        if (msg.sender != DAO) revert();
    }

    /// @dev Adds stake to EntryPoint (if `old`, version 0.6 is used).
    function addStake(bool old, uint32 unstakeDelaySec) public payable onlyDAO {
        NEETH(payable(old ? EP06 : EP07)).addStake{value: msg.value}(unstakeDelaySec);
    }

    /// @dev Unlocks stake from EntryPoint (if `old`, version 0.6 is used).
    function unlockStake(bool old) public payable onlyDAO {
        NEETH(payable(old ? EP06 : EP07)).unlockStake();
    }

    /// @dev Withdraws stake from EntryPoint (if `old`, version 0.6 is used).
    function withdrawStake(address payable withdrawAddress) public payable onlyDAO {
        NEETH(payable(old ? EP06 : EP07)).withdrawStake(withdrawAddress);
    }
}

/// @dev Simple Uniswap V3 swapping interface.
interface ISwapRouter {
    function swap(address, bool, int256, uint160, bytes calldata)
        external
        returns (int256, int256);
}
