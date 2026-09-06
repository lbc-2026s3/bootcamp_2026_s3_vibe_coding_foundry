// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice ETHBank:存款、按存款金额排名的链表(前三)、管理员提款
contract ETHBank {
    /// @notice 管理员 = 部署合约的人
    address public immutable admin;

    /// @notice 每个地址的累计存款金额
    mapping(address => uint256) public balances;

    // 链表:所有存款人按存款金额降序排列,通过两个 mapping 实现,address(0) 为哨兵
    mapping(address => address) private prev;
    mapping(address => address) private next;
    address public head;
    address public tail;

    /// @notice 存款人数
    uint256 public depositorCount;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdraw(address indexed admin, uint256 amount);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    /// @notice MetaMask 直接转账 ETH 走这里
    receive() external payable {
        _deposit(msg.sender);
    }

    /// @notice 显式调用存款
    function deposit() external payable {
        _deposit(msg.sender);
    }

    /// @notice 查询存款前三:地址与金额按排名降序返回,不足三人用 address(0)/0 补齐
    function getTop3() external view returns (address[3] memory top3, uint256[3] memory amounts) {
        address cur = head;
        for (uint256 i = 0; i < 3; i++) {
            if (cur == address(0)) break;
            top3[i] = cur;
            amounts[i] = balances[cur];
            cur = next[cur];
        }
    }

    /// @notice 仅管理员可提取合约内全部 ETH
    function withdraw() external onlyAdmin {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw");
        (bool ok,) = payable(admin).call{value: amount}("");
        require(ok, "Transfer failed");
        emit Withdraw(admin, amount);
    }

    function _deposit(address depositor) internal {
        require(msg.value > 0, "Zero deposit");
        bool isNew = balances[depositor] == 0;
        if (!isNew) {
            // 老存款人:先摘除节点,累加后按新余额重新插入
            _remove(depositor);
        }
        balances[depositor] += msg.value;
        _insert(depositor);
        if (isNew) {
            depositorCount++;
        }
        emit Deposit(depositor, msg.value);
    }

    /// @notice 从链表中摘除节点(balances[user] == 0 即不在链表中,直接返回)
    function _remove(address user) internal {
        if (balances[user] == 0) return;
        address p = prev[user];
        address n = next[user];
        if (p == address(0)) head = n;
        else next[p] = n;
        if (n == address(0)) tail = p;
        else prev[n] = p;
        delete prev[user];
        delete next[user];
    }

    /// @notice 按存款金额降序插入节点:排在所有余额严格更大的节点之后(金额相同时新存款者靠前)
    function _insert(address user) internal {
        address p;
        address cur = head;
        while (cur != address(0) && balances[cur] > balances[user]) {
            p = cur;
            cur = next[cur];
        }
        prev[user] = p;
        next[user] = cur;
        if (p == address(0)) head = user;
        else next[p] = user;
        if (cur == address(0)) tail = user;
        else prev[cur] = user;
    }
}
