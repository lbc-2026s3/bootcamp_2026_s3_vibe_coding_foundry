// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {MemeToken} from "./MemeToken.sol";

/// @notice Meme 发行工厂:用 EIP-1167 最小代理克隆同一份 ERC-20 实现,按 perMint 分批铸造。
contract MemeFactory {
    error EmptySymbol();
    error InvalidSupply();
    error UnknownInscription();

    address public immutable implementation;

    mapping(address token => bool) public isInscription;

    event InscriptionDeployed(
        address indexed token, address indexed creator, string symbol, uint256 totalSupply, uint256 perMint
    );
    event InscriptionMinted(address indexed token, address indexed minter, uint256 amount);

    constructor() {
        implementation = address(new MemeToken(address(this)));
    }

    /// @notice 克隆一份 Meme ERC-20。`totalSupply` 是铸造上限,`perMint` 是每次 mintInscription 的数量。
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint)
        external
        returns (address token)
    {
        if (bytes(symbol).length == 0) revert EmptySymbol();
        if (totalSupply == 0 || perMint == 0 || perMint > totalSupply) revert InvalidSupply();

        token = Clones.clone(implementation);
        isInscription[token] = true;
        MemeToken(token).initialize(msg.sender, symbol, totalSupply, perMint);

        emit InscriptionDeployed(token, msg.sender, symbol, totalSupply, perMint);
    }

    /// @notice 向调用者铸造该 inscription 的 `perMint` 枚 token,不超过其 `totalSupply` 上限。
    function mintInscription(address tokenAddr) external {
        if (!isInscription[tokenAddr]) revert UnknownInscription();

        MemeToken token = MemeToken(tokenAddr);
        token.mint(msg.sender);
        emit InscriptionMinted(tokenAddr, msg.sender, token.perMint());
    }
}
