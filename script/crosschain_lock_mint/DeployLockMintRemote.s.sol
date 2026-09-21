// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseScript} from "../BaseScript.s.sol";
import {WrappedToken} from "../../src/crosschain_lock_mint/WrappedToken.sol";

/// @notice 目标链（anvil2）部署 WrappedToken。源链见 DeployLockMint.s.sol。
/// @dev 环境变量与源链脚本相同；relayer 必须是两边都能签名的同一地址（本地用 Anvil Account #0）。
/// @dev forge script script/crosschain_lock_mint/DeployLockMintRemote.s.sol --broadcast \
///      --rpc-url anvil2 --private-key $OWNER1_PRIVATE_KEY
contract DeployLockMintRemoteScript is BaseScript {
    uint64 internal constant DEFAULT_HOME = 1;
    uint64 internal constant DEFAULT_REMOTE = 2;

    function run() public broadcaster {
        uint64 home = uint64(vm.envOr("LOCK_MINT_HOME", uint256(DEFAULT_HOME)));
        uint64 remote = uint64(vm.envOr("LOCK_MINT_REMOTE", uint256(DEFAULT_REMOTE)));
        address relayer = vm.envOr("LOCK_MINT_RELAYER", deployer);

        WrappedToken wrapped = new WrappedToken(remote, home, relayer, deployer);
        saveContract("WrappedToken", address(wrapped));
    }
}
