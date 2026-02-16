// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC4337} from "@solady/src/accounts/ERC4337.sol";
import {EIP712, SignatureCheckerLib, ERC1271} from "@solady/src/accounts/ERC1271.sol";

/// @notice Simple extendable smart account implementation. Includes plugin tooling.
/// @author nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/Account.sol)
contract Account is ERC4337 {
    /// ========================= CONSTANTS ========================= ///

    /// @dev Prehash of `keccak256("")` for validation efficiency.
    bytes32 internal constant _NULL_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /// @dev EIP712 typehash as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    /// Derived from `userOp` without the signature and the time fields of `validUntil` and `validAfter`.
    bytes32 internal constant _VALIDATE_TYPEHASH =
        0xa9a214c6f6d90f71d094504e32920cfd4d8d53e5d7cf626f9a26c88af60081c7;

    /// ========================= AGENT TYPES ========================= ///

    /// @dev Scoped permissions for an agent address.
    struct AgentScope {
        uint128 spendLimit;
        uint128 spent;
        uint48 validAfter;
        uint48 validUntil;
        uint32 txLimit;
        uint32 txCount;
        uint64 nonce;
        bool active;
    }

    /// ======================== AGENT STORAGE ======================== ///

    /// @dev Agent address => scoped permissions.
    mapping(address => AgentScope) internal _agents;

    /// @dev Agent => nonce => target => allowed.
    mapping(address => mapping(uint256 => mapping(address => bool))) internal _agentTargets;

    /// @dev Agent => nonce => selector => allowed.
    mapping(address => mapping(uint256 => mapping(bytes4 => bool))) internal _agentSelectors;

    /// ========================= AGENT EVENTS ======================== ///

    /// @dev Emitted when agent permissions are granted (full scope snapshot).
    event AgentGranted(
        address indexed agent,
        address[] targets,
        bytes4[] selectors,
        uint128 spendLimit,
        uint48 validAfter,
        uint48 validUntil,
        uint32 txLimit
    );

    /// @dev Emitted when agent permissions are revoked.
    event AgentRevoked(address indexed agent);

    /// @dev Emitted when an agent executes a call.
    event AgentExecuted(
        address indexed agent,
        address indexed target,
        bytes4 selector,
        uint256 value
    );

    /// ========================= AGENT ERRORS ======================== ///

    error AgentInvalid();
    error AgentTargetDenied();
    error AgentSelectorDenied();
    error AgentLimitExceeded();

    /// ========================= CONSTRUCTOR ========================= ///

    /// @dev Constructs
    /// this implementation.
    constructor() payable {}

    /// @dev Returns domain name
    /// & version of implementation.
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override(EIP712)
        returns (string memory, string memory)
    {
        return ("NANI", "1.3.0");
    }

    /// ========================= USEROP ========================= ///

    /// @dev Validates userOp
    /// with nonce handling.
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
        uint256 missingAccountFunds
    )
        external
        payable
        virtual
        override(ERC4337)
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256)
    {
        return
            userOp.nonce < type(uint64).max ? _validateUserOpSignature(userOp) : _validateUserOp();
    }

    /// @dev Validates `userOp.signature` for the EIP712-encoded `userOp`.
    function _validateUserOpSignature(PackedUserOperation calldata userOp)
        internal
        virtual
        returns (uint256)
    {
        (uint48 validUntil, uint48 validAfter) =
            (uint48(bytes6(userOp.signature[:6])), uint48(bytes6(userOp.signature[6:12])));
        bool valid = SignatureCheckerLib.isValidSignatureNowCalldata(
            owner(), __hashTypedData(userOp, validUntil, validAfter), userOp.signature[12:]
        );
        return (valid ? 0 : 1) | (uint256(validUntil) << 160) | (uint256(validAfter) << 208);
    }

    /// @dev Encodes `userOp` and extracted time window within EIP712 syntax.
    function __hashTypedData(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) internal view virtual returns (bytes32 digest) {
        // We will use `digest` to store the `userOp.sender` to save a bit of gas.
        assembly ("memory-safe") {
            digest := calldataload(userOp)
        }
        return EIP712._hashTypedData(
            keccak256(
                abi.encode(
                    _VALIDATE_TYPEHASH,
                    digest, // Optimize.
                    userOp.nonce,
                    userOp.initCode.length == 0 ? _NULL_HASH : _calldataKeccak(userOp.initCode),
                    _calldataKeccak(userOp.callData),
                    userOp.accountGasLimits,
                    userOp.preVerificationGas,
                    userOp.gasFees,
                    userOp.paymasterAndData.length == 0
                        ? _NULL_HASH
                        : _calldataKeccak(userOp.paymasterAndData),
                    validUntil,
                    validAfter
                )
            )
        );
    }

    /// @dev Keccak function over calldata. This is more efficient than letting Solidity do it.
    function _calldataKeccak(bytes calldata data) internal pure virtual returns (bytes32 hash) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            let l := data.length
            calldatacopy(m, data.offset, l)
            hash := keccak256(m, l)
        }
    }

    /// @dev Extends ERC4337 userOp validation in stored ERC7582 validator plugin.
    function _validateUserOp() internal virtual returns (uint256 validationData) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            calldatacopy(0x00, 0x00, calldatasize())
            if or(
                lt(returndatasize(), 0x20),
                iszero(
                    call(
                        gas(),
                        /*validator*/
                        sload( /*key*/ shr(64, /*nonce*/ calldataload(0x84))),
                        0,
                        0x00,
                        calldatasize(),
                        0x00,
                        0x20
                    )
                )
            ) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore zero pointer.
            validationData := mload(0x00)
        }
    }

    /// ========================= ERC1271 ========================= ///

    /// @dev Validates ERC1271 signature. Plugin activated if stored.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        override(ERC1271)
        returns (bytes4)
    {
        address validator = address(bytes20(storageLoad(this.isValidSignature.selector)));
        if (validator == address(0)) return super.isValidSignature(hash, signature);
        else return Account(payable(validator)).isValidSignature(hash, signature);
    }

    /// ========================= AGENT ========================= ///

    /// @dev Grant scoped permissions to an agent. Full overwrite on re-grant.
    /// Nonce is bumped to invalidate previous target/selector mappings.
    function grantAgent(
        address agent,
        address[] calldata targets,
        bytes4[] calldata selectors,
        uint128 spendLimit,
        uint48 validAfter,
        uint48 validUntil,
        uint32 txLimit
    ) external virtual onlyOwner {
        uint64 nonce = _agents[agent].nonce + 1;
        _agents[agent] = AgentScope({
            spendLimit: spendLimit,
            spent: 0,
            validAfter: validAfter,
            validUntil: validUntil,
            txLimit: txLimit,
            txCount: 0,
            nonce: nonce,
            active: true
        });
        unchecked {
            for (uint256 i; i < targets.length; ++i) {
                _agentTargets[agent][nonce][targets[i]] = true;
            }
            for (uint256 i; i < selectors.length; ++i) {
                _agentSelectors[agent][nonce][selectors[i]] = true;
            }
        }
        emit AgentGranted(
            agent, targets, selectors, spendLimit, validAfter, validUntil, txLimit
        );
    }

    /// @dev Revoke all permissions for an agent.
    function revokeAgent(address agent) external virtual onlyOwner {
        _agents[agent].active = false;
        emit AgentRevoked(agent);
    }

    /// @dev Execute a call as an agent within scoped permissions.
    function executeAsAgent(address target, uint256 value, bytes calldata data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        _validateAgent(msg.sender, target, value, data);
        bool success;
        (success, result) = target.call{value: value}(data);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }
        emit AgentExecuted(
            msg.sender, target, data.length >= 4 ? bytes4(data[:4]) : bytes4(0), value
        );
    }

    /// @dev Batch execute calls as an agent within scoped permissions.
    function executeAsAgentBatch(Call[] calldata calls)
        external
        payable
        virtual
        returns (bytes[] memory results)
    {
        results = new bytes[](calls.length);
        for (uint256 i; i < calls.length;) {
            _validateAgent(msg.sender, calls[i].target, calls[i].value, calls[i].data);
            bool success;
            (success, results[i]) =
                calls[i].target.call{value: calls[i].value}(calls[i].data);
            if (!success) {
                bytes memory r = results[i];
                assembly ("memory-safe") {
                    revert(add(r, 0x20), mload(r))
                }
            }
            emit AgentExecuted(
                msg.sender,
                calls[i].target,
                calls[i].data.length >= 4 ? bytes4(calls[i].data[:4]) : bytes4(0),
                calls[i].value
            );
            unchecked { ++i; }
        }
    }

    /// @dev Returns the agent's current scope.
    function getAgent(address agent)
        external
        view
        virtual
        returns (AgentScope memory)
    {
        return _agents[agent];
    }

    /// @dev Returns whether an agent can call a target with a selector.
    function canAgentCall(address agent, address target, bytes4 selector)
        external
        view
        virtual
        returns (bool)
    {
        AgentScope storage scope = _agents[agent];
        if (!scope.active) return false;
        if (block.timestamp < scope.validAfter) return false;
        if (scope.validUntil != 0 && block.timestamp > scope.validUntil) return false;
        if (scope.txLimit != 0 && scope.txCount >= scope.txLimit) return false;
        uint64 nonce = scope.nonce;
        return _agentTargets[agent][nonce][target]
            && _agentSelectors[agent][nonce][selector];
    }

    /// ======================== INTERNAL ======================== ///

    /// @dev Validates agent permissions for a call.
    function _validateAgent(
        address agent,
        address target,
        uint256 value,
        bytes calldata data
    ) internal virtual {
        AgentScope storage scope = _agents[agent];
        if (!scope.active) revert AgentInvalid();
        if (block.timestamp < scope.validAfter) revert AgentInvalid();
        if (scope.validUntil != 0 && block.timestamp > scope.validUntil) revert AgentInvalid();
        if (scope.txLimit != 0) {
            if (scope.txCount >= scope.txLimit) revert AgentLimitExceeded();
        }
        ++scope.txCount;
        if (value > 0) {
            if (uint256(scope.spent) + value > uint256(scope.spendLimit))
                revert AgentLimitExceeded();
            scope.spent += uint128(value);
        }
        uint64 nonce = scope.nonce;
        if (!_agentTargets[agent][nonce][target]) revert AgentTargetDenied();
        if (data.length >= 4) {
            if (!_agentSelectors[agent][nonce][bytes4(data[:4])]) revert AgentSelectorDenied();
        }
    }
}
