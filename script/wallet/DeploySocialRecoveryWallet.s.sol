// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// SocialRecoveryWallet — 社交恢复钱包
//
// 广播人是 owner，并往钱包打入 1 ETH。
// 守护者是 anvil 默认账户 1、2、3。门槛 2，安全期 3 天。
//
// forge script script/wallet/DeploySocialRecoveryWallet.s.sol:DeploySocialRecoveryWallet \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {SocialRecoveryWallet} from "../../src/wallet/SocialRecoveryWallet.sol";

contract DeploySocialRecoveryWallet is BaseScript {
    /// @dev anvil 默认账户 1、2、3。账户 0 是广播人，也是 owner。
    address internal constant GUARDIAN_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant GUARDIAN_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant GUARDIAN_3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 internal constant THRESHOLD = 2;
    uint256 internal constant SECURITY_PERIOD = 3 days;

    SocialRecoveryWallet public wallet;

    function run() public broadcaster {
        address[] memory guardians = new address[](3);
        guardians[0] = GUARDIAN_1;
        guardians[1] = GUARDIAN_2;
        guardians[2] = GUARDIAN_3;

        wallet = new SocialRecoveryWallet{value: 1 ether}(msg.sender, guardians, THRESHOLD, SECURITY_PERIOD);

        saveContract("SocialRecoveryWallet", address(wallet));

        console.log("SocialRecoveryWallet:", address(wallet));
        console.log("owner:               ", wallet.owner());
        console.log("threshold:           ", wallet.threshold());
        console.log("security period:     ", wallet.securityPeriod());
        console.log("balance:             ", address(wallet).balance);
    }
}
