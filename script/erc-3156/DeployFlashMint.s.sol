// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// FlashMintToken — ERC-3156 闪电增发
// 借 1000 FMT。回调期间总供应临时增加 1000，结束后本金烧掉。
// 0.10% 手续费（1 FMT）事先 mint 给借款人，还款时转给 deployer。
//
// forge script script/erc-3156/DeployFlashMint.s.sol:DeployFlashMint \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {FlashMintToken} from "../../src/erc-3156/FlashMintToken.sol";
import {SimpleFlashBorrower} from "../../src/erc-3156/SimpleFlashBorrower.sol";

contract DeployFlashMint is BaseScript {
    uint256 public constant BORROW_AMOUNT = 1_000 ether;

    function run() public broadcaster {
        // deployer 收手续费。借款人只能向这一份 token 借。
        FlashMintToken token = new FlashMintToken(deployer);
        SimpleFlashBorrower borrower = new SimpleFlashBorrower(IERC3156FlashLender(address(token)));
        saveContract("FlashMintToken", address(token));
        saveContract("SimpleFlashBorrower", address(borrower));

        // flashLoan 只铸本金。0.10% 手续费要事先放在借款人里，回调才能 approve 本金加手续费。
        // fee 表示借 BORROW_AMOUNT 需要支付的手续费，先给借款合约铸造手续费
        uint256 fee = token.flashFee(address(token), BORROW_AMOUNT);
        token.mint(address(borrower), fee);

        console.log("FlashMintToken:      ", address(token));
        console.log("SimpleFlashBorrower: ", address(borrower));
        console.log("feeReceiver:         ", token.feeReceiver());
        console.log("borrow amount:       ", BORROW_AMOUNT);
        console.log("fee:                 ", fee);
        console.log("supply before:       ", token.totalSupply());

        // 回调里总供应 = 事先的手续费 + 临时本金；返回后本金烧掉，手续费转到 deployer。
        borrower.flashBorrow(BORROW_AMOUNT);

        console.log("supply during loan:  ", borrower.supplyDuringLoan());
        console.log("balance during loan: ", borrower.balanceDuringLoan());
        console.log("supply after:        ", token.totalSupply());
        console.log("borrower after:      ", token.balanceOf(address(borrower)));
        console.log("treasury after:      ", token.balanceOf(deployer));
    }
}
