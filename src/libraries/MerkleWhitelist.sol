// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice 给白名单地址列表算出 Merkle 根和证明，名单多长都行。
/// @dev 每个地址先 abi.encode，再 keccak 两次，得到叶子。
/// @dev 相邻两个节点哈希前会按大小排序（和 OpenZeppelin MerkleProof 一致）。
/// @dev 人数不是 2 的幂时，右边用空叶子补齐，例如 12 人补到 16。
/// @dev 【只给脚本和测试用】；链上市场合约只存 merkleRoot，用 proof 验证调用者在名单里。
library MerkleWhitelist {
    error EmptyWhitelist();
    error IndexOutOfBounds(uint256 index, uint256 length);

    /// @notice 把一个地址打成叶子哈希。
    /// @dev 哈希两次，避免 64 字节叶子被误当成「两个内部节点拼在一起」。
    function leaf(address account) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    /// @notice 把两个节点合成上一层。小的放左边再 keccak，所以 H(a,b) == H(b,a)。
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /// @notice 用整份名单算出 Merkle 根，写入市场合约的 merkleRoot。
    function root(address[] memory accounts) internal pure returns (bytes32) {
        bytes32[] memory nodes = _paddedLeaves(accounts);
        uint256 n = nodes.length;
        // 每轮把相邻叶子两两哈希，结果写回数组前半段，直到只剩根
        while (n > 1) {
            n /= 2;
            for (uint256 i = 0; i < n; ++i) {
                nodes[i] = hashPair(nodes[2 * i], nodes[2 * i + 1]);
            }
        }
        return nodes[0];
    }

    /// @notice 给名单里第 `index` 个地址生成 Merkle proof，供 `claimNFT` 调用 `MerkleProof.verify`。
    /// @param accounts 完整白名单。必须和计算 `root(accounts)` 时同一份、同一顺序，否则 proof 对不上根。
    /// @param index 要证明的地址在 `accounts` 中的下标（从 0 起）。必须 `< accounts.length`；
    ///        补齐用的空叶子没有对应地址，不能拿来领 NFT。
    /// @return out 从叶子走到根时，每一层的兄弟哈希。长度 = 补齐后树的深度（8 人是 3，12 人补到 16 是 4）。
    function proof(address[] memory accounts, uint256 index) internal pure returns (bytes32[] memory out) {
        uint256 len = accounts.length;
        if (index >= len) revert IndexOutOfBounds(index, len);

        bytes32[] memory nodes = _paddedLeaves(accounts);
        uint256 layerLen = nodes.length;

        // 补齐后一定是 2 的幂：8→深度 3，12 补到 16→深度 4
        uint256 depth;
        for (uint256 m = layerLen; m > 1; m >>= 1) {
            ++depth;
        }

        out = new bytes32[](depth);
        uint256 idx = index;
        uint256 p;
        while (layerLen > 1) {
            // idx ^ 1：同一层的兄弟节点（偶数找右边，奇数找左边）
            out[p++] = nodes[idx ^ 1];
            uint256 nextLen = layerLen / 2;
            for (uint256 i = 0; i < nextLen; ++i) {
                nodes[i] = hashPair(nodes[2 * i], nodes[2 * i + 1]);
            }
            idx >>= 1;
            layerLen = nextLen;
        }
    }

    /// @dev 先把每个地址变成叶子；人数不够 2 的幂时，右边保持 bytes32(0) 当空叶子。
    function _paddedLeaves(address[] memory accounts) private pure returns (bytes32[] memory nodes) {
        uint256 len = accounts.length;
        if (len == 0) revert EmptyWhitelist();

        uint256 n = 1;
        while (n < len) n <<= 1; // 1,2,4,8,16... 直到能装下全部地址
        nodes = new bytes32[](n);
        for (uint256 i = 0; i < len; ++i) {
            nodes[i] = leaf(accounts[i]);
        }
    }
}
