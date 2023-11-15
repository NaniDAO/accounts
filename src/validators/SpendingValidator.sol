// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";

/// @notice ERC20 token interface.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice Simple spending plan validator for smart accounts.
contract SpendingValidator {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Spend exceeds the planned allowance for asset.
    error InvalidAllowance();

    /// @dev Spend is outside planned time range for asset.
    error InvalidTimestamp();

    /// @dev Calldata is attached to an ether (ETH) spend.
    error InvalidETHCalldata();

    /// @dev Invalid calldata is attached to asset spend.
    error InvalidCalldata();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Logs the new authorizers of an account.
    event AuthorizersSet(address indexed account, address[] authorizers);

    /// @dev Logs the new asset spending plans of an account.
    event PlanSet(address indexed account, address asset, Plan plan);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Stores mappings of authorizers to accounts.
    mapping(address => address[]) internal _authorizers;

    /// @dev Stores mappings of asset spending plans to accounts.
    mapping(address => mapping(address => Plan)) internal _plans;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   VALIDATION OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Validates ERC4337 userOp with additional auth logic flow among authorizers.
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        payable
        virtual
        returns (uint256 validationData)
    {
        // Extract the `target` and ether `value` for calldata.
        address target = address(bytes20(userOp.callData[4:24]));
        uint256 value = uint256(bytes32(userOp.callData[24:56]));

        // Extract the plan settings for spending.
        Plan memory plan = _plans[msg.sender][target];
        // Ensure that the plan for the asset is active.
        if (plan.allowance == 0) revert InvalidAllowance();
        // Ensure that the plan time range for the asset is active.
        if (block.timestamp < plan.validAfter) revert InvalidTimestamp();
        if (block.timestamp > plan.validUntil) revert InvalidTimestamp();

        // If ether `value` included, ensure no calldata,
        // as well, that the limit of plan is respected.
        if (value != 0) {
            if (userOp.callData.length != 0) revert InvalidETHCalldata();
            plan.allowance -= uint192(value);
        } else {
            // The userOp `execute` must be a call to ERC20 `transfer` method.
            if (bytes4(userOp.callData[56:60]) != IERC20.transfer.selector) {
                revert InvalidCalldata();
            }
            // The userOp must transfer an `amount` within the account plan.
            (target, value) = abi.decode(userOp.callData[60:124], (address, uint256));
            plan.allowance -= uint192(value);
        }

        // The planned spend must be to a valid address.
        // If no `validTo` array, recipients are open.
        if (plan.validTo.length != 0) {
            for (uint256 i; i < plan.validTo.length;) {
                if (plan.validTo[i] == target) {
                    validationData = 0x01;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (validationData == 0) revert InvalidCalldata();
        }

        // The planned spend must be validated by authorizers.
        address[] memory authorizers = _authorizers[msg.sender];
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(userOpHash);
        for (uint256 i; i < authorizers.length;) {
            if (
                SignatureCheckerLib.isValidSignatureNowCalldata(
                    authorizers[i], hash, userOp.signature
                )
            ) {
                validationData = 0x01;
                break;
            }
            unchecked {
                ++i;
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            validationData := iszero(validationData)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    AUTHORIZER OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the authorizers of an account.
    function getAuthorizers(address account) public view virtual returns (address[] memory) {
        return _authorizers[account];
    }

    /// @dev Returns an asset spending plan of an account.
    function getPlan(address account, address asset) public view virtual returns (Plan memory) {
        return _plans[account][asset];
    }

    /// @dev Sets the new authorizers of the caller account.
    function setauthorizers(address[] calldata authorizers) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
    }

    /// @dev Sets an asset spending plan of the caller account.
    function setPlan(address asset, Plan calldata plan) public payable virtual {
        emit PlanSet(msg.sender, asset, (_plans[msg.sender][asset] = plan));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   AUTHORIZER INSTALLATION                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Installs the new authorizers of the caller account and asset spending plans.
    function install(
        address[] calldata authorizers,
        address[] calldata assets,
        Plan[] calldata plans
    ) public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = authorizers));
        for (uint256 i; i < assets.length;) {
            emit PlanSet(msg.sender, assets[i], (_plans[msg.sender][assets[i]] = plans[i]));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Uninstalls the authorizers of an account.
    function uninstall() public payable virtual {
        emit AuthorizersSet(msg.sender, (_authorizers[msg.sender] = new address[](0)));
    }
}
