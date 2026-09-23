// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {LaunchPad} from "../../src/launchpad/LaunchPad.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "uniswapv2/UniswapV2Router02.sol";
import {WETH9} from "uniswapv2/WETH9.sol";

/// @notice 部署 LaunchPad；可复用已有 Router / LaunchPad，避免重复部署。
/// @dev 环境变量(全部可选):
///   LAUNCHPAD_ADDRESS — 已有 LaunchPad；设置则跳过部署，只打印地址
///   LAUNCHPAD_ROUTER  — 已有 UniswapV2Router02；留空则读 deployments 或新建 UniV2 栈
///   UNIV2_FEE_TO_SETTER / UNIV2_WETH — 新建 UniV2 时使用
/// @dev 示例:
///   forge script script/launchpad/DeployLaunchPad.s.sol:DeployLaunchPad \
///     --broadcast --rpc-url local && cat ./deployments/LATEST.txt
contract DeployLaunchPad is BaseScript {
    using stdJson for string;

    LaunchPad public launchPad;
    UniswapV2Router02 public router;

    function run() public broadcaster {
        address existingLaunchPad = vm.envOr("LAUNCHPAD_ADDRESS", address(0));
        if (existingLaunchPad == address(0)) {
            existingLaunchPad = _tryLoadLaunchPadFromDeployments();
        }

        if (existingLaunchPad != address(0)) {
            launchPad = LaunchPad(payable(existingLaunchPad));
            router = UniswapV2Router02(payable(address(launchPad.router())));
            saveContract("LaunchPad", existingLaunchPad);
            saveContract("UniswapV2Router02", address(router));
            saveContract("LaunchPadMemeTokenImplementation", launchPad.implementation());
            console.log("Reusing LaunchPad:", existingLaunchPad);
        } else {
            router = _resolveRouter();
            launchPad = new LaunchPad(address(router));
            saveContract("LaunchPad", address(launchPad));
            saveContract("LaunchPadMemeTokenImplementation", launchPad.implementation());
            console.log("Deployed LaunchPad:", address(launchPad));
        }

        console.log("Router:  ", address(router));
        console.log("WETH:    ", router.WETH());
        console.log("Meme impl:", launchPad.implementation());
    }

    function _resolveRouter() internal returns (UniswapV2Router02) {
        address existingRouter = vm.envOr("LAUNCHPAD_ROUTER", address(0));
        if (existingRouter != address(0)) {
            saveContract("UniswapV2Router02", existingRouter);
            return UniswapV2Router02(payable(existingRouter));
        }

        address fromFile = _tryLoadRouterFromDeployments();
        if (fromFile != address(0)) {
            saveContract("UniswapV2Router02", fromFile);
            console.log("Reusing Router from deployments:", fromFile);
            return UniswapV2Router02(payable(fromFile));
        }

        return _deployUniswapV2Stack();
    }

    function _deployUniswapV2Stack() internal returns (UniswapV2Router02 deployedRouter) {
        address feeToSetter = vm.envOr("UNIV2_FEE_TO_SETTER", deployer);

        WETH9 weth;
        address existingWeth = vm.envOr("UNIV2_WETH", address(0));
        if (existingWeth != address(0)) {
            weth = WETH9(payable(existingWeth));
            saveContract("WETH9", existingWeth);
        } else {
            weth = new WETH9();
            saveContract("WETH9", address(weth));
        }

        UniswapV2Factory factory = new UniswapV2Factory(feeToSetter);
        saveContract("UniswapV2Factory", address(factory));

        deployedRouter = new UniswapV2Router02(address(factory), address(weth));
        saveContract("UniswapV2Router02", address(deployedRouter));
    }

    function _tryLoadRouterFromDeployments() internal view returns (address) {
        return _tryLoadAddress("UniswapV2Router02");
    }

    function _tryLoadLaunchPadFromDeployments() internal view returns (address) {
        return _tryLoadAddress("LaunchPad");
    }

    function _tryLoadAddress(string memory name) internal view returns (address) {
        string memory path =
            string.concat("deployments/", name, "/", name, "_", vm.toString(block.chainid), ".json");
        try vm.readFile(path) returns (string memory json) {
            return json.readAddress(".address");
        } catch {
            return address(0);
        }
    }
}
