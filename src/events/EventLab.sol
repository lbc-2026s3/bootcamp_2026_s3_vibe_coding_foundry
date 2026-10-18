// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice 演示 Solidity 事件索引。
/// 值类型（uint、address、bool、bytes32）做 indexed 时，topic 里是补齐后的原值。
/// string、bytes、数组、结构体做 indexed 时，topic 里是它们的 Keccak-256，明文只存在非 indexed 的 data 里。
/// 每个事件最多 3 个 indexed 参数。
contract EventLab {
    struct Item {
        uint256 id;
        string name;
    }

    /// @dev bytes32 是值类型：indexed 后 topic 等于 tag 本身，不会再哈希一次。
    event ValueIndexed(uint256 indexed amount, address indexed account, bytes32 indexed tag, bool flag);

    /// @dev hashedNote / hashedBlob 的 topic = keccak256(原始字节)，不含长度前缀和补齐。
    /// note / blob 放在 data 里，链下才能读到明文。
    event DynamicIndexed(string indexed hashedNote, bytes indexed hashedBlob, string note, bytes blob);

    /// @dev 数组和结构体同样只把哈希放进 topic。
    /// 数组哈希的原文是各元素的 ABI 编码直接拼接，没有长度前缀。
    /// 结构体哈希的原文是各成员编码拼接，每个成员都补齐到 32 字节的倍数。
    event ReferenceIndexed(uint256[] indexed hashedIds, Item indexed hashedItem, uint256[] ids, Item item);

    uint256 public constant SAMPLE_AMOUNT = 42;
    bytes32 public constant SAMPLE_TAG = bytes32("event-lab");
    string public constant SAMPLE_NOTE = "hello indexed";
    bytes public constant SAMPLE_BLOB = hex"cafebabe";
    uint256 public constant SAMPLE_ITEM_ID = 7;
    string public constant SAMPLE_ITEM_NAME = "widget";

    function emitValueIndexed(uint256 amount, address account, bytes32 tag, bool flag) external {
        emit ValueIndexed(amount, account, tag, flag);
    }

    function emitDynamicIndexed(string calldata note, bytes calldata blob) external {
        emit DynamicIndexed(note, blob, note, blob);
    }

    function emitReferenceIndexed(uint256[] calldata ids, uint256 itemId, string calldata itemName) external {
        Item memory item = Item({id: itemId, name: itemName});
        emit ReferenceIndexed(ids, item, ids, item);
    }

    /// @notice 一次发出三类事件。account 用 msg.sender，方便按调用者过滤。
    function emitSample() external {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        Item memory item = Item({id: SAMPLE_ITEM_ID, name: SAMPLE_ITEM_NAME});

        emit ValueIndexed(SAMPLE_AMOUNT, msg.sender, SAMPLE_TAG, true);
        emit DynamicIndexed(SAMPLE_NOTE, SAMPLE_BLOB, SAMPLE_NOTE, SAMPLE_BLOB);
        emit ReferenceIndexed(ids, item, ids, item);
    }
}
