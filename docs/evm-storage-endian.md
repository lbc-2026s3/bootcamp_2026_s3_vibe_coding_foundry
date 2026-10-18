# EVM 存储槽：大端、同一槽里的多个变量、sol2uml 那张图

一个存储槽是 **256 位 / 32 字节** 的一个整数。`eth_getStorageAt`、`cast storage`、`vm.load` 打出来都是 `0x` 后面 **64 个十六进制字符**。把这 32 个字节按地址从低到高摆开，顺序和这串字符从左到右相同：最左边的字节在最低地址，它是这个整数的最高有效字节。这就是大端。

Solidity 把多个小于 32 字节的变量塞进同一个槽时，**先声明的放在最低有效端**。最低有效端在十六进制的右端，也在内存的高地址。取变量就是按它的字节偏移右移，再截到它自己的宽度。

下面用两个能跑的例子把三件事对齐：十六进制字符串、地址从低到高的内存、`script/storage.sh` 画出来的格子。

官方规则：[Solidity：状态变量的存储布局](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)。字写入内存的字节序见 [MSTORE `0x52`](https://www.evm.codes/#52)。

---

## 先跑出一个槽里的三个变量

`src/storage/PackedSlot.sol` 在槽 0 放了三个变量，加起来正好 32 字节：

```solidity
uint64 public x;    // 8 字节，编译器 offset 0
uint64 public y;    // 8 字节，offset 8
uint128 public z;   // 16 字节，offset 16
```

构造参数 `x = 0x1111`、`y = 0x2222`、`z = 0x3333`。测试会把原始槽打出来：

```bash
forge test --match-path test/storage/PackedSlot.t.sol -vv
```

槽 0 是：

```text
0x0000000000000000000000000000333300000000000022220000000000001111
```

64 个十六进制字符，两个字符一个字节，从左到右就是地址从低到高：

```text
地址   0            15 16           23 24           31
       低地址 ──────────────────────────────────► 高地址
       ┌──────── z uint128 ────────┐┌── y uint64 ──┐┌── x uint64 ──┐
字节   00 00 00 00 00 00 00 00 00 00 00 00 00 00 33 33 00 00 00 00 00 00 22 22 00 00 00 00 00 00 11 11
位     255                      128 127           64 63             0
       最高有效字节                                      最低有效字节
```

非零字节落在每个变量自己的低位，所以都贴着该变量那段的右端：

| 地址 | 字节 | 属于 |
| --- | --- | --- |
| 14–15 | `33 33` | `z = 0x3333` 的低 2 字节 |
| 22–23 | `22 22` | `y = 0x2222` 的低 2 字节 |
| 30–31 | `11 11` | `x = 0x1111` 的低 2 字节 |

地址 31 是 `x` 的最低字节。先声明的 `x` 在整条轴的最右边。

---

## 大端：这个字放到内存里时长什么样

EVM 的 storage 本身是 `slot → 256 位整数`，槽内部没有字节地址。字节地址出现在这个字被写进内存、或者被编码成 32 字节序列的时候。

`MSTORE` 把一个字按大端写入连续 32 字节：`memory[p]` 是位 255–248，`memory[p + 31]` 是位 7–0。测试里的 `_asMemoryBytes` 做的就是这件事，然后检查：

- `laidOut[14]`、`laidOut[15]` 是 `0x33`（`z`）
- `laidOut[22]`、`laidOut[23]` 是 `0x22`（`y`）
- `laidOut[30]`、`laidOut[31]` 是 `0x11`（`x`）

所以平时看到的

```text
0x0000000000000000000000000000333300000000000022220000000000001111
```

已经是底层布局：去掉 `0x`，从左往右读，就是地址 0 到地址 31。左边高位，右边低位。

---

## 用移位把三个变量取出来

编译器 storage layout 里的 `offset` 从**最低有效字节**往上数，单位是字节。右移位数是 `offset × 8`。移完后只留该类型的宽度，高位丢掉。

| 变量 | 类型 | 字节数 | offset | 右移 | 留下的位 |
| --- | --- | --- | --- | --- | --- |
| `x` | `uint64` | 8 | 0 | 0 | `[63:0]` |
| `y` | `uint64` | 8 | 8 | 64 | `[127:64]` |
| `z` | `uint128` | 16 | 16 | 128 | `[255:128]` |

`PackedSlot.unpack`：

```solidity
uint256 word;
assembly {
    word := sload(0)
}
x_ = uint64(word);
y_ = uint64(word >> 64);
z_ = uint128(word >> 128);
```

转成窄类型会截断。和先掩码再取值是同一件事：

```text
x =  word         & ((1 << 64)  - 1)
y = (word >> 64)  & ((1 << 64)  - 1)
z = (word >> 128) & ((1 << 128) - 1)
```

用上面那个真实的字验一下 `y`：

```text
word >> 64 = 0x000000000000000000000000000033330000000000002222
低 64 位   = 0x2222
```

`z` 再右移 64 位（合计 128）得到 `0x3333`。`x` 不移位，低 64 位就是 `0x1111`。

同一个公式适用于任意紧凑布局：`offset` 和字节数来自 `forge inspect <合约> storageLayout`，或者数声明顺序（装得下就紧挨着放，装不下就换下一个槽）。

汇编里对应 `SHR` 和 `AND`：

```solidity
assembly {
    let word := sload(0)
    x := and(word, 0xffffffffffffffff)
    y := and(shr(64, word), 0xffffffffffffffff)
    z := shr(128, word)
}
```

---

## `src/Test.sol` 的两个槽

`Test` 的结构体是两个变量占满槽 0，第三个变量独占槽 1 的低 20 字节：

```solidity
struct Optimized {
    uint128 a;   // 槽 0，offset 0，低 16 字节
    uint128 c;   // 槽 0，offset 16，高 16 字节
    address b;   // 槽 1，offset 0，低 20 字节
}
```

构造函数写入 `a = 42`、`c = 7`、`b = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8`。`test/storage/PackedSlot.t.sol` 里的 `OptimizedLayout` 与这段布局和初值相同，`-vv` 会打出这两个字：

```text
槽 0  0x000000000000000000000000000000070000000000000000000000000000002a
槽 1  0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8
```

槽 0，地址从低到高：

```text
地址  0                          15 16                         31
      ┌──────── c = 7 ──────────┐┌──────── a = 42 ───────────┐
      00 .. 00 07                 00 .. 00 2a
      高 16 字节                   低 16 字节
```

`7` 在地址 15，`42`（`0x2a`）在地址 31。

```solidity
uint256 head = uint256(slot0);
uint128 a = uint128(head);          // 42
uint128 c = uint128(head >> 128);   // 7
```

槽 1，`address` 占 20 字节，从低位对齐。高 12 字节是 0：

```text
地址  0                11 12                                      31
      ┌──── 12 字节 0 ──┐┌──────────── b ，20 字节 ───────────────┐
      000000000000000000000000  70997970c51812dc3a010c7d01b50e0d17dc79c8
```

```solidity
address b = address(uint160(uint256(slot1)));
```

`uint160` 留下低 20 字节，右移位数是 0，因为 `b` 的 offset 是 0。

后面的 `mapping` 自己从槽 2 开始。结构体没用完的那 12 字节留在槽 1 里，mapping 不会回头去填。槽 2 这个基槽的值是 0；`balances[key]` 在 `keccak256(abi.encode(key, uint256(2)))`。图上只画基槽。

`DEMO_ACCOUNT`、`INITIAL_A`、`INITIAL_C` 是 `constant`，不占存储，图里没有它们。

`forge inspect src/Test.sol:Test storageLayout` 的顶层表把整个结构体看成从槽 0 起的 64 字节，`balances` 在槽 2。成员的 offset 在 JSON 的 `types` 里：

| 成员 | slot | offset | 字节 |
| --- | --- | --- | --- |
| `a` | 0 | 0 | 16 |
| `c` | 0 | 16 | 16 |
| `b` | 1 | 0 | 20 |

这里的 offset 就是上一节的右移公式里的那个字节偏移：从十六进制右端、从内存高地址那一端数。

---

## `script/storage.sh src/Test.sol -c Test` 画了什么

```bash
script/storage.sh src/Test.sol -c Test -o /tmp/Test-storage.svg
```

sol2uml 2.5.26 生成两块，中间一根箭头：从合约里的 `Optimized: a` 指向右边的结构体。槽号从上到下增大。**同一个槽里，格子从左到右是高位到低位**，和上一节的十六进制、和地址从低到高，是同一个方向。

合约节点把结构体收成一格，槽号写成 `0-1`（跨两个槽）：

```text
Test <<Contract>>
┌──────┬──────────────────────────────────────────────┐
│ slot │ type: <inherited contract>.variable (bytes)  │
│ 0-1  │ Optimized: a (64)                            │
│ 2    │ mapping(address=>uint256): balances (32)     │
└──────┴──────────────────────────────────────────────┘
```

结构体节点把每个槽拆开。槽 0 从左到右是 `c` 然后 `a`，槽 1 从左到右是空位然后 `b`：

```text
Optimized <<Struct>>          标题行：type: variable (bytes)

slot 0    uint128: c (16)     uint128: a (16)
slot 1    unallocated (12)    address: b (20)
```

和真实的字对上：

| 图上的格子（从左到右） | 十六进制（从左到右） | 地址 |
| --- | --- | --- |
| 槽 0：`uint128: c (16)` 然后 `uint128: a (16)` | `…0007` 然后 `…002a` | 0–15 是 `c`，16–31 是 `a` |
| 槽 1：`unallocated (12)` 然后 `address: b (20)` | 24 个 `0` 然后 40 个地址字符 | 0–11 空着，12–31 是 `b` |

`unallocated (12)` 是 sol2uml 补上的空位：这一槽被变量占用了 20 字节，剩下 12 字节画成一格。它在左边，因为空着的是高 12 字节。

紧凑方式在结构体节点里。合约节点那一格只有 `Optimized: a (64)`，要看 `c` 在高位，去右边的槽 0。

合约格子标题里的 `<inherited contract>.` 是 sol2uml 写在每个合约节点上的固定前缀。`Test` 没有父合约。结构体节点的标题是 `type: variable (bytes)`。

括号里的数字是字节数。格子的像素宽度跟着标签文字走。同一张图里，槽 1 的 `unallocated (12)` 约 150pt，`address: b (20)` 约 142pt。左右顺序和括号里的字节数才是布局。

sol2uml 先按声明顺序收集变量（offset 从小到大），画每一个槽之前把这一槽反转，Graphviz 再从左画到右。反转之后，offset 0 在最右边，高位在最左边，于是图和 `0x` 字符串同向。

三个变量的 `PackedSlot` 用同一条规则。生成：

```bash
script/storage.sh src/storage/PackedSlot.sol -c PackedSlot -o /tmp/PackedSlot-storage.svg
```

图只有槽 0，从左到右是：

```text
PackedSlot <<Contract>>
标题行：type: <inherited contract>.variable (bytes)

slot 0    uint128: z (16)    uint64: y (8)    uint64: x (8)
```

对应

```text
0x 00000000000000000000000000003333 0000000000002222 0000000000001111
   └──────────── z ─────────────┘ └────── y ──────┘ └────── x ──────┘
```

`z` 16 字节的格子约 142pt，`y` 和 `x` 各 8 字节的格子各约 125pt。宽度比是文字长度，不是 16:8。

---

## 对照时用的三条轴

读任何一个槽，把这三行叠在一起。左边永远是高位。

```text
十六进制   0x  [高位字节 ………………………… 低位字节]
内存地址   低 …………………………………………………… 高
sol2uml    后声明 / 高 offset ……………… offset 0（先声明）
```

移位：`右移位数 = offset × 8`，然后留下 `字节数 × 8` 位。offset 从右端数。
