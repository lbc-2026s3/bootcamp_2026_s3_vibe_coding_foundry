// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";

abstract contract BaseScript is Script {
    /// @notice 由 broadcaster 写入的部署人地址,saveContract 读此字段而非直接用 msg.sender
    address internal deployer;

    struct PendingSave {
        string name;
        address addr;
    }

    /// @dev saveContract 先入队；broadcaster 在 stopBroadcast 之后统一落盘并打印
    PendingSave[] private _pendingSaves;

    function setUp() public virtual {}

    /// @notice 记录待保存的部署结果（真正写文件 / 打日志在 stopBroadcast 之后）
    function saveContract(string memory name, address addr) internal {
        require(deployer != address(0), "deployer unset; use broadcaster");
        _pendingSaves.push(PendingSave({name: name, addr: addr}));
    }

    function _flushPendingSaves() private {
        // dry-run（无 --broadcast/--resume）不得覆盖真实部署产物
        if (
            !vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)
                && !vm.isContext(VmSafe.ForgeContext.ScriptResume)
        ) {
            console.log("Skipping deployments write (forge script without --broadcast/--resume)");
            delete _pendingSaves;
            return;
        }

        uint256 n = _pendingSaves.length;

        // forge 会先打印脚本 == Logs ==，再打印 onchain 收据摘要，脚本内无法把日志挪到摘要之后。
        // 因此地址以 deployments/LATEST.txt 为准；部署命令末尾加 `&& cat deployments/LATEST.txt`。
        string memory writtenAt = _formatBeijingTime(vm.unixTime() / 1000);
        vm.createDir("deployments", true);

        if (n == 0) {
            // 本次广播未调用 saveContract：清掉旧地址，避免误用上一次部署结果
            vm.writeFile(
                "deployments/LATEST.txt",
                string.concat(
                    "writtenAt: ",
                    writtenAt,
                    "\nchainId: ",
                    vm.toString(block.chainid),
                    "\n----------------------------------------\n",
                    "No contracts saved: this script did not call saveContract().\n",
                    "[Warning] Old addresses cleared - do not reuse previous LATEST.txt entries.\n"
                )
            );
            console.log("No saveContract() in this run - deployments/LATEST.txt cleared");
            return;
        }

        string memory latest = string.concat(
            "writtenAt: ",
            writtenAt,
            "\nchainId: ",
            vm.toString(block.chainid),
            "\n----------------------------------------\n",
            "Correct deployed addresses (ignore forge receipt Contract Address for CALLs):\n"
        );
        for (uint256 i = 0; i < n; i++) {
            PendingSave memory item = _pendingSaves[i];
            _writeDeployment(item.name, item.addr);
            latest = string.concat(latest, item.name, " => ", vm.toString(item.addr), "\n");
        }
        vm.writeFile("deployments/LATEST.txt", latest);

        console.log("Addresses written to deployments/LATEST.txt - after forge finishes, run: cat deployments/LATEST.txt");

        delete _pendingSaves;
    }

    function _writeDeployment(string memory name, address addr) private {
        string memory chainId = vm.toString(block.chainid);
        string memory dirPath = string.concat("deployments/", name);

        // Foundry cheatcode: 创建目录，等价 mkdir -p，已存在不会报错
        vm.createDir(dirPath, true);

        // 使用本机当前时间(毫秒)转北京时间，比 block.timestamp 更接近实际部署时刻
        string memory deployedAt = _formatBeijingTime(vm.unixTime() / 1000);

        string memory obj = "deployment";
        vm.serializeAddress(obj, "address", addr);
        vm.serializeAddress(obj, "deployer", deployer);
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeUint(obj, "blockNumber", block.number);
        string memory finalJson = vm.serializeString(obj, "deployedAt", deployedAt);

        string memory fullFilePath = string.concat(dirPath, "/", name, "_", chainId, ".json");

        try vm.writeJson(finalJson, fullFilePath) {
            // 不在此处 console.log 详细地址：会被 forge 印在收据摘要之前，容易和错误摘要混在一起
        } catch {
            revert(
                string.concat(
                    "saveContract failed writing ",
                    fullFilePath,
                    " - check foundry.toml fs_permissions for ./deployments"
                )
            );
        }
    }

    /// @notice 将 Unix 秒时间戳格式化为北京时间字符串，如 "2026-09-07 11:16:00 CST"
    function _formatBeijingTime(uint256 unixSeconds) private pure returns (string memory) {
        uint256 ts = unixSeconds + 8 hours;

        uint256 secs = ts % 60;
        uint256 mins = (ts / 60) % 60;
        uint256 hours_ = (ts / 3600) % 24;
        uint256 daysSinceEpoch = ts / 86400;

        (uint256 year, uint256 month, uint256 day) = _daysToDate(daysSinceEpoch);

        return string.concat(
            vm.toString(year),
            "-",
            _pad2(month),
            "-",
            _pad2(day),
            " ",
            _pad2(hours_),
            ":",
            _pad2(mins),
            ":",
            _pad2(secs),
            " CST"
        );
    }

    /// @dev 自 1970-01-01 起的天数 -> 公历年月日（Howard Hinnant 算法）
    function _daysToDate(uint256 day)
        private
        pure
        returns (uint256 year, uint256 month, uint256 dayOfMonth)
    {
        unchecked {
            int256 z = int256(day) + 719468;
            int256 era = (z >= 0 ? z : z - 146096) / 146097;
            uint256 doe = uint256(z - era * 146097);
            uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
            int256 y = int256(yoe) + era * 400;
            uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
            uint256 mp = (5 * doy + 2) / 153;
            dayOfMonth = doy - (153 * mp + 2) / 5 + 1;
            month = mp < 10 ? mp + 3 : mp - 9;
            year = uint256(y + (month <= 2 ? int256(1) : int256(0)));
        }
    }

    function _pad2(uint256 n) private pure returns (string memory) {
        if (n >= 10) return vm.toString(n);
        return string.concat("0", vm.toString(n));
    }

    modifier broadcaster() {
        // 无参 startBroadcast 时广播签名人就是 msg.sender;以后若改 startBroadcast(pk) 应同时改这里为 vm.addr(pk)
        deployer = msg.sender;
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
        // 广播结束后再写 deployments / 打日志，避免和 forge tx 摘要交错
        _flushPendingSaves();
    }
}
