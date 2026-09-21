// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CanonicalToken} from "../../src/crosschain_lock_mint/CanonicalToken.sol";
import {LockVault} from "../../src/crosschain_lock_mint/LockVault.sol";

/// @notice 源链（anvil1）部署 CanonicalToken + LockVault。包装币见 DeployLockMintRemote.s.sol。
/// @dev 环境变量：
///   LOCK_MINT_RELAYER — 可选，默认部署者自己当 relayer（本地演示）
///   LOCK_MINT_HOME    — 可选，默认 1
///   LOCK_MINT_REMOTE  — 可选，默认 2
/// @dev forge script script/crosschain_lock_mint/DeployLockMint.s.sol --broadcast \
///      --rpc-url anvil1 --private-key $OWNER1_PRIVATE_KEY
contract DeployLockMintScript is BaseScript {
    uint64 internal constant DEFAULT_HOME = 1;
    uint64 internal constant DEFAULT_REMOTE = 2;

    function run() public broadcaster {
        uint64 home = uint64(vm.envOr("LOCK_MINT_HOME", uint256(DEFAULT_HOME)));
        uint64 remote = uint64(vm.envOr("LOCK_MINT_REMOTE", uint256(DEFAULT_REMOTE)));
        address relayer = vm.envOr("LOCK_MINT_RELAYER", deployer);

        CanonicalToken token = new CanonicalToken();
        LockVault vault = new LockVault(IERC20(address(token)), home, remote, relayer, deployer);

        saveContract("CanonicalToken", address(token));
        saveContract("LockVault", address(vault));
    }
}
