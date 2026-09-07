// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

abstract contract BaseScript is Script {
    /// @notice 由 broadcaster 写入的部署人地址,saveContract 读此字段而非直接用 msg.sender
    address internal deployer;

    function setUp() public virtual {}

    function saveContract(string memory name, address addr) internal {
        require(deployer != address(0), "deployer unset; use broadcaster");

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
            // success
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
    function _formatBeijingTime(uint256 unixSeconds) private view returns (string memory) {
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

    function _pad2(uint256 n) private view returns (string memory) {
        if (n >= 10) return vm.toString(n);
        return string.concat("0", vm.toString(n));
    }

    modifier broadcaster() {
        // 无参 startBroadcast 时广播签名人就是 msg.sender;以后若改 startBroadcast(pk) 应同时改这里为 vm.addr(pk)
        deployer = msg.sender;
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
