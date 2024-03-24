// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice Simple payment plan validator for smart accounts.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/PaymentValidator.sol)
/// @custom:version 1.1.1
contract PaymentValidator {
    /// ======================= CUSTOM ERRORS ======================= ///

    /// @dev Spend exceeds the planned allowance for asset.
    error InvalidAllowance();

    /// @dev Spend is outside planned time range for asset.
    error InvalidTimestamp();

    /// @dev Invalid selector for the given asset spend.
    error InvalidSelector();

    /// @dev Invalid target for the given asset spend.
    error InvalidTarget();

    /// =========================== EVENTS =========================== ///

    /// @dev Logs the new authorizers for an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// @dev Logs the new asset spending plans for an account.
    event PlanSet(address indexed account, address asset, Plan plan);

    /// ========================== STRUCTS ========================== ///

    /// @dev Asset spending plan struct.
    struct Plan {
        uint192 allowance;
        uint32 validAfter;
        uint32 validUntil;
        address[] validTo;
    }

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

    /// @dev The packed ERC4337 userOp struct.
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

    /// ========================= CONSTANTS ========================= ///

    /// @dev The conventional ERC7528 ETH address.
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// ========================== STORAGE ========================== ///

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// @dev Stores mappings of asset payment plans to accounts.
    mapping(address => mapping(address => Plan)) internal _plans;

    /// ======================== CONSTRUCTOR ======================== ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// =================== VALIDATION OPERATIONS =================== ///

    /// @dev Validates ERC4337 userOp with payment plan and auth validation.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOpHash, userOp.callData, userOp.signature);
    }

    /// @dev Validates packed ERC4337 userOp with payment plan and auth validation.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOpHash, userOp.callData, userOp.signature);
    }

    /// @dev Validates userOp with payment plan and auth validation.
    function _validateUserOp(bytes32 userOpHash, bytes calldata callData, bytes calldata signature)
        internal
        virtual
        returns (uint256 validationData)
    {
        // Extract the `execute()` `target` and ether `value` from userOp `callData`.
        (address target, uint256 value) = abi.decode(callData[4:68], (address, uint256));
        // Determine if userOp involves ETH handling in preparation for plan review.
        bool isETH = value != 0;
        // Extract the plan settings for spending.
        Plan memory plan = _plans[msg.sender][isETH ? ETH : target];
        // Ensure that the plan for the asset is active.
        if (plan.allowance == 0) revert InvalidAllowance();
        // Ensure that the plan time range for the asset is active.
        if (block.timestamp < plan.validAfter) revert InvalidTimestamp();
        if (block.timestamp > plan.validUntil) revert InvalidTimestamp();
        // If ether `value` included, ensure that plan is respected.
        if (isETH) {
            plan.allowance -= uint192(value);
        } else {
            // The userOp `execute()` must be a call to ERC20 `transfer()` method.
            if (bytes4(callData[132:136]) != IERC20.transfer.selector) {
                revert InvalidSelector();
            }
            // The userOp must transfer a `value` within the account plan.
            (target, value) = abi.decode(callData[136:], (address, uint256));
            plan.allowance -= uint192(value);
        }
        // The planned spend must be to a valid address.
        // If no `validTo` array, recipients are open.
        bool validTarget;
        if (plan.validTo.length != 0) {
            for (uint256 i; i != plan.validTo.length; ++i) {
                if (plan.validTo[i] == target) {
                    validTarget = true;
                    break;
                }
            }
            if (!validTarget) revert InvalidTarget();
        }
        // The planned spend must be validated by an authorizer.
        address[] memory authorizers = _authorizers[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i != authorizers.length; ++i) {
            if (SignatureCheckerLib.isValidSignatureNowCalldata(authorizers[i], hash, signature)) {
                validationData = 0x01; // Reverse flag.
                break;
            }
        }
        assembly ("memory-safe") {
            validationData := iszero(validationData)
        }
    }

    /// =================== AUTHORIZER OPERATIONS =================== ///

    /// @dev Returns the authorizers for an account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _authorizers[account];
    }

    /// @dev Returns the asset payment plan for an account.
    function getPlan(address account, address asset) public view virtual returns (Plan memory) {
        return _plans[account][asset];
    }

    /// @dev Sets the new authorizers for the caller account.
    function setAuthorizers(address[] calldata authorizers) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Sets an asset payment plan for the caller account.
    function setPlan(address asset, Plan calldata plan) public payable virtual {
        emit PlanSet(msg.sender, asset, (_plans[msg.sender][asset] = plan));
    }

    /// ================== INSTALLATION OPERATIONS ================== ///

    /// @dev Installs the new authorizers and spending plans for the caller account.
    function install(
        address[] calldata authorizers,
        address[] calldata assets,
        Plan[] calldata plans
    ) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
        for (uint256 i; i != assets.length; ++i) {
            emit PlanSet(msg.sender, assets[i], (_plans[msg.sender][assets[i]] = plans[i]));
        }
    }

    /// @dev Uninstalls the authorizers for the caller account.
    function uninstall() public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}

/// @notice ERC20 interface.
interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}
