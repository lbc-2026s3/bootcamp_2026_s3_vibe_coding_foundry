// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Uniswap Permit2 SignatureTransfer interface used by TokenBankPermit2
/// @dev Canonical Permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3 (CREATE2, all major chains)
interface ISignatureTransfer {
    /// @notice The token and amount details for a transfer signed in the permit transfer signature
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice The signed permit message for a single token transfer
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Specifies the recipient address and amount for the transfer
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /// @notice EIP-712 domain separator for Permit2
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Transfers a token using a signed permit message
    /// @dev Reverts if requestedAmount > permitted.amount; spender in signature is msg.sender
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}
