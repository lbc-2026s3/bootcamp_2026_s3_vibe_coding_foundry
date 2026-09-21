// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenV1(100 万枚)+ TokenVesting(12 个月 Cliff + 24 个月线性释放),
///         并把全部 token 转入 Vesting 合约,部署完成即开始计算 Cliff。
/// @dev 环境变量:
///   VESTING_BENEFICIARY — 可选,受益人地址,默认部署者本人
/// @dev forge script script/TokenVesting.s.sol:TokenVestingScript --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract TokenVestingScript is BaseScript {
    MyTokenV1 public token;
    TokenVesting public vesting;

    function run() public broadcaster {
        address beneficiary = vm.envOr("VESTING_BENEFICIARY", msg.sender);

        token = new MyTokenV1();
        vesting = new TokenVesting(address(token), beneficiary);
        token.transfer(address(vesting), token.INITIAL_SUPPLY());

        saveContract("MyTokenV1", address(token));
        saveContract("TokenVesting", address(vesting));
    }
}
