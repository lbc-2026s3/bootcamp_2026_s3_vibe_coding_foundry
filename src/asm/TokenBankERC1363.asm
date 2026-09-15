    /* "src/TokenBankERC1363.sol":1136:2822  contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {... */
  mstore(0x40, 0xa0)
    /* "src/TokenBankERC1363.sol":1259:1308  constructor(IERC20 token_) TokenBankV2(token_) {} */
  callvalue
  dup1
  iszero
  tag_1
  jumpi
  revert(0x00, 0x00)
tag_1:
  pop
  mload(0x40)
  sub(codesize, bytecodeSize)
  dup1
  bytecodeSize
  dup4
  codecopy
  dup2
  dup2
  add
  0x40
  mstore
  dup2
  add
  swap1
  tag_2
  swap2
  swap1
  tag_3
  jump	// in
tag_2:
    /* "src/TokenBankERC1363.sol":1298:1304  token_ */
  dup1
    /* "src/TokenBankV2.sol":857:863  token_ */
  dup1
    /* "src/TokenBankV2.sol":849:863  token = token_ */
  0xffffffffffffffffffffffffffffffffffffffff
  and
  0x80
  dup2
  0xffffffffffffffffffffffffffffffffffffffff
  and
  dup2
  mstore
  pop
  pop
    /* "src/TokenBankV2.sol":812:870  constructor(IERC20 token_) {... */
  pop
    /* "src/TokenBankERC1363.sol":1259:1308  constructor(IERC20 token_) TokenBankV2(token_) {} */
  pop
    /* "src/TokenBankERC1363.sol":1136:2822  contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {... */
  jump(tag_8)
    /* "#utility.yul":88:205   */
tag_10:
    /* "#utility.yul":197:198   */
  0x00
    /* "#utility.yul":194:195   */
  0x00
    /* "#utility.yul":187:199   */
  revert
    /* "#utility.yul":334:460   */
tag_12:
    /* "#utility.yul":371:378   */
  0x00
    /* "#utility.yul":411:453   */
  0xffffffffffffffffffffffffffffffffffffffff
    /* "#utility.yul":404:409   */
  dup3
    /* "#utility.yul":400:454   */
  and
    /* "#utility.yul":389:454   */
  swap1
  pop
    /* "#utility.yul":334:460   */
  swap2
  swap1
  pop
  jump	// out
    /* "#utility.yul":466:562   */
tag_13:
    /* "#utility.yul":503:510   */
  0x00
    /* "#utility.yul":532:556   */
  tag_23
    /* "#utility.yul":550:555   */
  dup3
    /* "#utility.yul":532:556   */
  tag_12
  jump	// in
tag_23:
    /* "#utility.yul":521:556   */
  swap1
  pop
    /* "#utility.yul":466:562   */
  swap2
  swap1
  pop
  jump	// out
    /* "#utility.yul":568:678   */
tag_14:
    /* "#utility.yul":619:626   */
  0x00
    /* "#utility.yul":648:672   */
  tag_25
    /* "#utility.yul":666:671   */
  dup3
    /* "#utility.yul":648:672   */
  tag_13
  jump	// in
tag_25:
    /* "#utility.yul":637:672   */
  swap1
  pop
    /* "#utility.yul":568:678   */
  swap2
  swap1
  pop
  jump	// out
    /* "#utility.yul":684:834   */
tag_15:
    /* "#utility.yul":771:809   */
  tag_27
    /* "#utility.yul":803:808   */
  dup2
    /* "#utility.yul":771:809   */
  tag_14
  jump	// in
tag_27:
    /* "#utility.yul":764:769   */
  dup2
    /* "#utility.yul":761:810   */
  eq
    /* "#utility.yul":751:828   */
  tag_28
  jumpi
    /* "#utility.yul":824:825   */
  0x00
    /* "#utility.yul":821:822   */
  0x00
    /* "#utility.yul":814:826   */
  revert
    /* "#utility.yul":751:828   */
tag_28:
    /* "#utility.yul":684:834   */
  pop
  jump	// out
    /* "#utility.yul":840:1011   */
tag_16:
    /* "#utility.yul":911:916   */
  0x00
    /* "#utility.yul":942:948   */
  dup2
    /* "#utility.yul":936:949   */
  mload
    /* "#utility.yul":927:949   */
  swap1
  pop
    /* "#utility.yul":958:1005   */
  tag_30
    /* "#utility.yul":999:1004   */
  dup2
    /* "#utility.yul":958:1005   */
  tag_15
  jump	// in
tag_30:
    /* "#utility.yul":840:1011   */
  swap3
  swap2
  pop
  pop
  jump	// out
    /* "#utility.yul":1017:1396   */
tag_3:
    /* "#utility.yul":1101:1107   */
  0x00
    /* "#utility.yul":1150:1152   */
  0x20
    /* "#utility.yul":1138:1147   */
  dup3
    /* "#utility.yul":1129:1136   */
  dup5
    /* "#utility.yul":1125:1148   */
  sub
    /* "#utility.yul":1121:1153   */
  slt
    /* "#utility.yul":1118:1237   */
  iszero
  tag_32
  jumpi
    /* "#utility.yul":1156:1235   */
  tag_33
  tag_10
  jump	// in
tag_33:
    /* "#utility.yul":1118:1237   */
tag_32:
    /* "#utility.yul":1276:1277   */
  0x00
    /* "#utility.yul":1301:1379   */
  tag_34
    /* "#utility.yul":1371:1378   */
  dup5
    /* "#utility.yul":1362:1368   */
  dup3
    /* "#utility.yul":1351:1360   */
  dup6
    /* "#utility.yul":1347:1369   */
  add
    /* "#utility.yul":1301:1379   */
  tag_16
  jump	// in
tag_34:
    /* "#utility.yul":1291:1379   */
  swap2
  pop
    /* "#utility.yul":1247:1389   */
  pop
    /* "#utility.yul":1017:1396   */
  swap3
  swap2
  pop
  pop
  jump	// out
    /* "src/TokenBankERC1363.sol":1136:2822  contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {... */
tag_8:
  mload(0x80)
  codecopy(0x00, dataOffset(sub_0), dataSize(sub_0))
  0x00
  assignImmutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
  return(0x00, dataSize(sub_0))
stop

sub_0: assembly {
        /* "src/TokenBankERC1363.sol":1136:2822  contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {... */
      mstore(0x40, 0x80)
      callvalue
      dup1
      iszero
      tag_1
      jumpi
      revert(0x00, 0x00)
    tag_1:
      pop
      jumpi(tag_2, lt(calldatasize, 0x04))
      shr(0xe0, calldataload(0x00))
      dup1
      0x7b04a2d0
      gt
      tag_10
      jumpi
      dup1
      0x7b04a2d0
      eq
      tag_6
      jumpi
      dup1
      0x88a7ca5c
      eq
      tag_7
      jumpi
      dup1
      0xb6b55f25
      eq
      tag_8
      jumpi
      dup1
      0xfc0c546a
      eq
      tag_9
      jumpi
      jump(tag_2)
    tag_10:
      dup1
      0x01ffc9a7
      eq
      tag_3
      jumpi
      dup1
      0x27e235e3
      eq
      tag_4
      jumpi
      dup1
      0x2e1a7d4d
      eq
      tag_5
      jumpi
    tag_2:
      revert(0x00, 0x00)
        /* "src/TokenBankERC1363.sol":1342:1610  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {... */
    tag_3:
      tag_11
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_12
      swap2
      swap1
      tag_13
      jump	// in
    tag_12:
      tag_14
      jump	// in
    tag_11:
      mload(0x40)
      tag_15
      swap2
      swap1
      tag_16
      jump	// in
    tag_15:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      return
        /* "src/TokenBankV2.sol":646:689  mapping(address => uint256) public balances */
    tag_4:
      tag_17
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_18
      swap2
      swap1
      tag_19
      jump	// in
    tag_18:
      tag_20
      jump	// in
    tag_17:
      mload(0x40)
      tag_21
      swap2
      swap1
      tag_22
      jump	// in
    tag_21:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      return
        /* "src/TokenBankV2.sol":1255:1598  function withdraw(uint256 amount) external {... */
    tag_5:
      tag_23
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_24
      swap2
      swap1
      tag_25
      jump	// in
    tag_24:
      tag_26
      jump	// in
    tag_23:
      stop
        /* "src/TokenBankERC1363.sol":2200:2820  function onApprovalReceived(... */
    tag_6:
      tag_27
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_28
      swap2
      swap1
      tag_29
      jump	// in
    tag_28:
      tag_30
      jump	// in
    tag_27:
      mload(0x40)
      tag_31
      swap2
      swap1
      tag_32
      jump	// in
    tag_31:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      return
        /* "src/TokenBankERC1363.sol":1653:2158  function onTransferReceived(... */
    tag_7:
      tag_33
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_34
      swap2
      swap1
      tag_35
      jump	// in
    tag_34:
      tag_36
      jump	// in
    tag_33:
      mload(0x40)
      tag_37
      swap2
      swap1
      tag_32
      jump	// in
    tag_37:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      return
        /* "src/TokenBankV2.sol":939:1182  function deposit(uint256 amount) external {... */
    tag_8:
      tag_38
      0x04
      dup1
      calldatasize
      sub
      dup2
      add
      swap1
      tag_39
      swap2
      swap1
      tag_25
      jump	// in
    tag_39:
      tag_40
      jump	// in
    tag_38:
      stop
        /* "src/TokenBankV2.sol":553:582  IERC20 public immutable token */
    tag_9:
      tag_41
      tag_42
      jump	// in
    tag_41:
      mload(0x40)
      tag_43
      swap2
      swap1
      tag_44
      jump	// in
    tag_43:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      return
        /* "src/TokenBankERC1363.sol":1342:1610  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {... */
    tag_14:
        /* "src/TokenBankERC1363.sol":1427:1431  bool */
      0x00
        /* "src/TokenBankERC1363.sol":1465:1499  type(IERC1363Receiver).interfaceId */
      0x88a7ca5c00000000000000000000000000000000000000000000000000000000
        /* "src/TokenBankERC1363.sol":1450:1499  interfaceId == type(IERC1363Receiver).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
        /* "src/TokenBankERC1363.sol":1450:1461  interfaceId */
      dup3
        /* "src/TokenBankERC1363.sol":1450:1499  interfaceId == type(IERC1363Receiver).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
      eq
        /* "src/TokenBankERC1363.sol":1450:1551  interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId */
      dup1
      tag_46
      jumpi
      pop
        /* "src/TokenBankERC1363.sol":1518:1551  type(IERC1363Spender).interfaceId */
      0x7b04a2d000000000000000000000000000000000000000000000000000000000
        /* "src/TokenBankERC1363.sol":1503:1551  interfaceId == type(IERC1363Spender).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
        /* "src/TokenBankERC1363.sol":1503:1514  interfaceId */
      dup3
        /* "src/TokenBankERC1363.sol":1503:1551  interfaceId == type(IERC1363Spender).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
      eq
        /* "src/TokenBankERC1363.sol":1450:1551  interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId */
    tag_46:
        /* "src/TokenBankERC1363.sol":1450:1603  interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId... */
      dup1
      tag_47
      jumpi
      pop
        /* "src/TokenBankERC1363.sol":1567:1603  super.supportsInterface(interfaceId) */
      tag_48
        /* "src/TokenBankERC1363.sol":1591:1602  interfaceId */
      dup3
        /* "src/TokenBankERC1363.sol":1567:1590  super.supportsInterface */
      tag_49
        /* "src/TokenBankERC1363.sol":1567:1603  super.supportsInterface(interfaceId) */
      jump	// in
    tag_48:
        /* "src/TokenBankERC1363.sol":1450:1603  interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId... */
    tag_47:
        /* "src/TokenBankERC1363.sol":1443:1603  return interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId... */
      swap1
      pop
        /* "src/TokenBankERC1363.sol":1342:1610  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {... */
      swap2
      swap1
      pop
      jump	// out
        /* "src/TokenBankV2.sol":646:689  mapping(address => uint256) public balances */
    tag_20:
      mstore(0x20, 0x00)
      dup1
      0x00
      mstore
      keccak256(0x00, 0x40)
      0x00
      swap2
      pop
      swap1
      pop
      sload
      dup2
      jump	// out
        /* "src/TokenBankV2.sol":1255:1598  function withdraw(uint256 amount) external {... */
    tag_26:
        /* "src/TokenBankV2.sol":1325:1326  0 */
      0x00
        /* "src/TokenBankV2.sol":1316:1322  amount */
      dup2
        /* "src/TokenBankV2.sol":1316:1326  amount > 0 */
      gt
        /* "src/TokenBankV2.sol":1308:1344  require(amount > 0, "Zero withdraw") */
      tag_51
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_52
      swap1
      tag_53
      jump	// in
    tag_52:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_51:
        /* "src/TokenBankV2.sol":1386:1392  amount */
      dup1
        /* "src/TokenBankV2.sol":1362:1370  balances */
      0x00
        /* "src/TokenBankV2.sol":1362:1382  balances[msg.sender] */
      0x00
        /* "src/TokenBankV2.sol":1371:1381  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1362:1382  balances[msg.sender] */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xffffffffffffffffffffffffffffffffffffffff
      and
      dup2
      mstore
      0x20
      add
      swap1
      dup2
      mstore
      0x20
      add
      0x00
      keccak256
      sload
        /* "src/TokenBankV2.sol":1362:1392  balances[msg.sender] >= amount */
      lt
      iszero
        /* "src/TokenBankV2.sol":1354:1417  require(balances[msg.sender] >= amount, "Insufficient balance") */
      tag_54
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_55
      swap1
      tag_56
      jump	// in
    tag_55:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_54:
        /* "src/TokenBankV2.sol":1494:1500  amount */
      dup1
        /* "src/TokenBankV2.sol":1470:1478  balances */
      0x00
        /* "src/TokenBankV2.sol":1470:1490  balances[msg.sender] */
      0x00
        /* "src/TokenBankV2.sol":1479:1489  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1470:1490  balances[msg.sender] */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xffffffffffffffffffffffffffffffffffffffff
      and
      dup2
      mstore
      0x20
      add
      swap1
      dup2
      mstore
      0x20
      add
      0x00
      keccak256
      0x00
        /* "src/TokenBankV2.sol":1470:1500  balances[msg.sender] -= amount */
      dup3
      dup3
      sload
      tag_57
      swap2
      swap1
      tag_58
      jump	// in
    tag_57:
      swap3
      pop
      pop
      dup2
      swap1
      sstore
      pop
        /* "src/TokenBankV2.sol":1510:1548  token.safeTransfer(msg.sender, amount) */
      tag_59
        /* "src/TokenBankV2.sol":1529:1539  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1541:1547  amount */
      dup3
        /* "src/TokenBankV2.sol":1510:1515  token */
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
        /* "src/TokenBankV2.sol":1510:1528  token.safeTransfer */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      tag_60
      swap1
        /* "src/TokenBankV2.sol":1510:1548  token.safeTransfer(msg.sender, amount) */
      swap3
      swap2
      swap1
      0xffffffff
      and
      jump	// in
    tag_59:
        /* "src/TokenBankV2.sol":1572:1582  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1563:1591  Withdraw(msg.sender, amount) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0x884edad9ce6fa2440d8a54cc123490eb96d2768479d49ff9c7366125a9424364
        /* "src/TokenBankV2.sol":1584:1590  amount */
      dup3
        /* "src/TokenBankV2.sol":1563:1591  Withdraw(msg.sender, amount) */
      mload(0x40)
      tag_61
      swap2
      swap1
      tag_22
      jump	// in
    tag_61:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      log2
        /* "src/TokenBankV2.sol":1255:1598  function withdraw(uint256 amount) external {... */
      pop
      jump	// out
        /* "src/TokenBankERC1363.sol":2200:2820  function onApprovalReceived(... */
    tag_30:
        /* "src/TokenBankERC1363.sol":2366:2372  bytes4 */
      0x00
        /* "src/TokenBankERC1363.sol":2418:2423  token */
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
        /* "src/TokenBankERC1363.sol":2396:2424  msg.sender == address(token) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
        /* "src/TokenBankERC1363.sol":2396:2406  msg.sender */
      caller
        /* "src/TokenBankERC1363.sol":2396:2424  msg.sender == address(token) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      eq
        /* "src/TokenBankERC1363.sol":2388:2442  require(msg.sender == address(token), "Invalid token") */
      tag_63
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_64
      swap1
      tag_65
      jump	// in
    tag_64:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_63:
        /* "src/TokenBankERC1363.sol":2468:2469  0 */
      0x00
        /* "src/TokenBankERC1363.sol":2460:2465  value */
      dup5
        /* "src/TokenBankERC1363.sol":2460:2469  value > 0 */
      gt
        /* "src/TokenBankERC1363.sol":2452:2486  require(value > 0, "Zero deposit") */
      tag_66
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_67
      swap1
      tag_68
      jump	// in
    tag_67:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_66:
        /* "src/TokenBankERC1363.sol":2521:2522  0 */
      0x00
        /* "src/TokenBankERC1363.sol":2504:2523  owner != address(0) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
        /* "src/TokenBankERC1363.sol":2504:2509  owner */
      dup6
        /* "src/TokenBankERC1363.sol":2504:2523  owner != address(0) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      sub
        /* "src/TokenBankERC1363.sol":2496:2538  require(owner != address(0), "Zero owner") */
      tag_69
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_70
      swap1
      tag_71
      jump	// in
    tag_70:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_69:
        /* "src/TokenBankERC1363.sol":2631:2682  token.safeTransferFrom(owner, address(this), value) */
      tag_72
        /* "src/TokenBankERC1363.sol":2654:2659  owner */
      dup6
        /* "src/TokenBankERC1363.sol":2669:2673  this */
      address
        /* "src/TokenBankERC1363.sol":2676:2681  value */
      dup7
        /* "src/TokenBankERC1363.sol":2631:2636  token */
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
        /* "src/TokenBankERC1363.sol":2631:2653  token.safeTransferFrom */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      tag_73
      swap1
        /* "src/TokenBankERC1363.sol":2631:2682  token.safeTransferFrom(owner, address(this), value) */
      swap4
      swap3
      swap2
      swap1
      0xffffffff
      and
      jump	// in
    tag_72:
        /* "src/TokenBankERC1363.sol":2711:2716  value */
      dup4
        /* "src/TokenBankERC1363.sol":2692:2700  balances */
      0x00
        /* "src/TokenBankERC1363.sol":2692:2707  balances[owner] */
      0x00
        /* "src/TokenBankERC1363.sol":2701:2706  owner */
      dup8
        /* "src/TokenBankERC1363.sol":2692:2707  balances[owner] */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xffffffffffffffffffffffffffffffffffffffff
      and
      dup2
      mstore
      0x20
      add
      swap1
      dup2
      mstore
      0x20
      add
      0x00
      keccak256
      0x00
        /* "src/TokenBankERC1363.sol":2692:2716  balances[owner] += value */
      dup3
      dup3
      sload
      tag_74
      swap2
      swap1
      tag_75
      jump	// in
    tag_74:
      swap3
      pop
      pop
      dup2
      swap1
      sstore
      pop
        /* "src/TokenBankERC1363.sol":2739:2744  owner */
      dup5
        /* "src/TokenBankERC1363.sol":2731:2752  Deposit(owner, value) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
        /* "src/TokenBankERC1363.sol":2746:2751  value */
      dup6
        /* "src/TokenBankERC1363.sol":2731:2752  Deposit(owner, value) */
      mload(0x40)
      tag_76
      swap2
      swap1
      tag_22
      jump	// in
    tag_76:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      log2
        /* "src/TokenBankERC1363.sol":2770:2813  IERC1363Spender.onApprovalReceived.selector */
      shl(0xe0, 0x7b04a2d0)
        /* "src/TokenBankERC1363.sol":2763:2813  return IERC1363Spender.onApprovalReceived.selector */
      swap1
      pop
        /* "src/TokenBankERC1363.sol":2200:2820  function onApprovalReceived(... */
      swap5
      swap4
      pop
      pop
      pop
      pop
      jump	// out
        /* "src/TokenBankERC1363.sol":1653:2158  function onTransferReceived(... */
    tag_36:
        /* "src/TokenBankERC1363.sol":1850:1856  bytes4 */
      0x00
        /* "src/TokenBankERC1363.sol":1902:1907  token */
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
        /* "src/TokenBankERC1363.sol":1880:1908  msg.sender == address(token) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
        /* "src/TokenBankERC1363.sol":1880:1890  msg.sender */
      caller
        /* "src/TokenBankERC1363.sol":1880:1908  msg.sender == address(token) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      eq
        /* "src/TokenBankERC1363.sol":1872:1926  require(msg.sender == address(token), "Invalid token") */
      tag_78
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_79
      swap1
      tag_65
      jump	// in
    tag_79:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_78:
        /* "src/TokenBankERC1363.sol":1952:1953  0 */
      0x00
        /* "src/TokenBankERC1363.sol":1944:1949  value */
      dup5
        /* "src/TokenBankERC1363.sol":1944:1953  value > 0 */
      gt
        /* "src/TokenBankERC1363.sol":1936:1970  require(value > 0, "Zero deposit") */
      tag_80
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_81
      swap1
      tag_68
      jump	// in
    tag_81:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_80:
        /* "src/TokenBankERC1363.sol":2004:2005  0 */
      0x00
        /* "src/TokenBankERC1363.sol":1988:2006  from != address(0) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
        /* "src/TokenBankERC1363.sol":1988:1992  from */
      dup6
        /* "src/TokenBankERC1363.sol":1988:2006  from != address(0) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      sub
        /* "src/TokenBankERC1363.sol":1980:2020  require(from != address(0), "Zero from") */
      tag_82
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_83
      swap1
      tag_84
      jump	// in
    tag_83:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_82:
        /* "src/TokenBankERC1363.sol":2049:2054  value */
      dup4
        /* "src/TokenBankERC1363.sol":2031:2039  balances */
      0x00
        /* "src/TokenBankERC1363.sol":2031:2045  balances[from] */
      0x00
        /* "src/TokenBankERC1363.sol":2040:2044  from */
      dup8
        /* "src/TokenBankERC1363.sol":2031:2045  balances[from] */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xffffffffffffffffffffffffffffffffffffffff
      and
      dup2
      mstore
      0x20
      add
      swap1
      dup2
      mstore
      0x20
      add
      0x00
      keccak256
      0x00
        /* "src/TokenBankERC1363.sol":2031:2054  balances[from] += value */
      dup3
      dup3
      sload
      tag_85
      swap2
      swap1
      tag_75
      jump	// in
    tag_85:
      swap3
      pop
      pop
      dup2
      swap1
      sstore
      pop
        /* "src/TokenBankERC1363.sol":2077:2081  from */
      dup5
        /* "src/TokenBankERC1363.sol":2069:2089  Deposit(from, value) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
        /* "src/TokenBankERC1363.sol":2083:2088  value */
      dup6
        /* "src/TokenBankERC1363.sol":2069:2089  Deposit(from, value) */
      mload(0x40)
      tag_86
      swap2
      swap1
      tag_22
      jump	// in
    tag_86:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      log2
        /* "src/TokenBankERC1363.sol":2107:2151  IERC1363Receiver.onTransferReceived.selector */
      shl(0xe0, 0x88a7ca5c)
        /* "src/TokenBankERC1363.sol":2100:2151  return IERC1363Receiver.onTransferReceived.selector */
      swap1
      pop
        /* "src/TokenBankERC1363.sol":1653:2158  function onTransferReceived(... */
      swap6
      swap5
      pop
      pop
      pop
      pop
      pop
      jump	// out
        /* "src/TokenBankV2.sol":939:1182  function deposit(uint256 amount) external {... */
    tag_40:
        /* "src/TokenBankV2.sol":1008:1009  0 */
      0x00
        /* "src/TokenBankV2.sol":999:1005  amount */
      dup2
        /* "src/TokenBankV2.sol":999:1009  amount > 0 */
      gt
        /* "src/TokenBankV2.sol":991:1026  require(amount > 0, "Zero deposit") */
      tag_88
      jumpi
      mload(0x40)
      0x08c379a000000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_89
      swap1
      tag_68
      jump	// in
    tag_89:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
    tag_88:
        /* "src/TokenBankV2.sol":1036:1093  token.safeTransferFrom(msg.sender, address(this), amount) */
      tag_90
        /* "src/TokenBankV2.sol":1059:1069  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1079:1083  this */
      address
        /* "src/TokenBankV2.sol":1086:1092  amount */
      dup4
        /* "src/TokenBankV2.sol":1036:1041  token */
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
        /* "src/TokenBankV2.sol":1036:1058  token.safeTransferFrom */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      tag_73
      swap1
        /* "src/TokenBankV2.sol":1036:1093  token.safeTransferFrom(msg.sender, address(this), amount) */
      swap4
      swap3
      swap2
      swap1
      0xffffffff
      and
      jump	// in
    tag_90:
        /* "src/TokenBankV2.sol":1127:1133  amount */
      dup1
        /* "src/TokenBankV2.sol":1103:1111  balances */
      0x00
        /* "src/TokenBankV2.sol":1103:1123  balances[msg.sender] */
      0x00
        /* "src/TokenBankV2.sol":1112:1122  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1103:1123  balances[msg.sender] */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xffffffffffffffffffffffffffffffffffffffff
      and
      dup2
      mstore
      0x20
      add
      swap1
      dup2
      mstore
      0x20
      add
      0x00
      keccak256
      0x00
        /* "src/TokenBankV2.sol":1103:1133  balances[msg.sender] += amount */
      dup3
      dup3
      sload
      tag_91
      swap2
      swap1
      tag_75
      jump	// in
    tag_91:
      swap3
      pop
      pop
      dup2
      swap1
      sstore
      pop
        /* "src/TokenBankV2.sol":1156:1166  msg.sender */
      caller
        /* "src/TokenBankV2.sol":1148:1175  Deposit(msg.sender, amount) */
      0xffffffffffffffffffffffffffffffffffffffff
      and
      0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
        /* "src/TokenBankV2.sol":1168:1174  amount */
      dup3
        /* "src/TokenBankV2.sol":1148:1175  Deposit(msg.sender, amount) */
      mload(0x40)
      tag_92
      swap2
      swap1
      tag_22
      jump	// in
    tag_92:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      log2
        /* "src/TokenBankV2.sol":939:1182  function deposit(uint256 amount) external {... */
      pop
      jump	// out
        /* "src/TokenBankV2.sol":553:582  IERC20 public immutable token */
    tag_42:
      immutable("0xad6001c41f5480e3ca6168a06649b3a3f0b7288943b7fbc0eb5698ed5504137a")
      dup2
      jump	// out
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":730:876  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {... */
    tag_49:
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":806:810  bool */
      0x00
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":844:869  type(IERC165).interfaceId */
      0x01ffc9a700000000000000000000000000000000000000000000000000000000
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":829:869  interfaceId == type(IERC165).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":829:840  interfaceId */
      dup3
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":829:869  interfaceId == type(IERC165).interfaceId */
      not(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
      and
      eq
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":822:869  return interfaceId == type(IERC165).interfaceId */
      swap1
      pop
        /* "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol":730:876  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {... */
      swap2
      swap1
      pop
      jump	// out
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1290:1494  function safeTransfer(IERC20 token, address to, uint256 value) internal {... */
    tag_60:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1377:1414  _safeTransfer(token, to, value, true) */
      tag_95
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1391:1396  token */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1398:1400  to */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1402:1407  value */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1409:1413  true */
      0x01
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1377:1390  _safeTransfer */
      tag_96
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1377:1414  _safeTransfer(token, to, value, true) */
      jump	// in
    tag_95:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1372:1488  if (!_safeTransfer(token, to, value, true)) {... */
      tag_97
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1470:1475  token */
      dup3
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1437:1477  SafeERC20FailedOperation(address(token)) */
      mload(0x40)
      0x5274afe700000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_98
      swap2
      swap1
      tag_99
      jump	// in
    tag_98:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1372:1488  if (!_safeTransfer(token, to, value, true)) {... */
    tag_97:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1290:1494  function safeTransfer(IERC20 token, address to, uint256 value) internal {... */
      pop
      pop
      pop
      jump	// out
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1733:1965  function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {... */
    tag_73:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1838:1885  _safeTransferFrom(token, from, to, value, true) */
      tag_101
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1856:1861  token */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1863:1867  from */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1869:1871  to */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1873:1878  value */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1880:1884  true */
      0x01
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1838:1855  _safeTransferFrom */
      tag_102
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1838:1885  _safeTransferFrom(token, from, to, value, true) */
      jump	// in
    tag_101:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1833:1959  if (!_safeTransferFrom(token, from, to, value, true)) {... */
      tag_103
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1941:1946  token */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1908:1948  SafeERC20FailedOperation(address(token)) */
      mload(0x40)
      0x5274afe700000000000000000000000000000000000000000000000000000000
      dup2
      mstore
      0x04
      add
      tag_104
      swap2
      swap1
      tag_99
      jump	// in
    tag_104:
      mload(0x40)
      dup1
      swap2
      sub
      swap1
      revert
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1833:1959  if (!_safeTransferFrom(token, from, to, value, true)) {... */
    tag_103:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":1733:1965  function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {... */
      pop
      pop
      pop
      pop
      jump	// out
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9022:10266  function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {... */
    tag_96:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9116:9128  bool success */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9140:9155  bytes4 selector */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9158:9182  IERC20.transfer.selector */
      shl(0xe0, 0xa9059cbb)
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9140:9182  bytes4 selector = IERC20.transfer.selector */
      swap1
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9249:9253  0x40 */
      0x40
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9243:9254  mload(0x40) */
      mload
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9280:9288  selector */
      dup2
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9274:9278  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9267:9289  mstore(0x00, selector) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9335:9336  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9331:9337  not(0) */
      not
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9327:9329  96 */
      0x60
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9323:9338  shr(96, not(0)) */
      shr
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9319:9321  to */
      dup7
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9315:9339  and(to, shr(96, not(0))) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9309:9313  0x04 */
      0x04
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9302:9340  mstore(0x04, and(to, shr(96, not(0)))) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9366:9371  value */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9360:9364  0x24 */
      0x24
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9353:9372  mstore(0x24, value) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9436:9440  0x20 */
      0x20
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9430:9434  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9424:9428  0x44 */
      0x44
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9418:9422  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9415:9416  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9408:9413  token */
      dup12
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9401:9406  gas() */
      gas
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9396:9441  call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20) */
      call
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9385:9441  success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20) */
      swap3
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9653:9654  1 */
      0x01
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9646:9650  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9640:9651  mload(0x00) */
      mload
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9637:9655  eq(mload(0x00), 1) */
      eq
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9628:9635  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9624:9656  and(success, eq(mload(0x00), 1)) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9614:10220  if iszero(and(success, eq(mload(0x00), 1))) {... */
      tag_106
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9785:9791  bubble */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9775:9782  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9768:9783  iszero(success) */
      iszero
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9764:9792  and(iszero(success), bubble) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9761:9926  if and(iszero(success), bubble) {... */
      iszero
      tag_107
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9841:9857  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9835:9839  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9830:9833  fmp */
      dup3
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9815:9858  returndatacopy(fmp, 0x00, returndatasize()) */
      returndatacopy
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9891:9907  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9886:9889  fmp */
      dup2
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9879:9908  revert(fmp, returndatasize()) */
      revert
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9761:9926  if and(iszero(success), bubble) {... */
    tag_107:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10202:10203  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10194:10199  token */
      dup8
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10182:10200  extcodesize(token) */
      extcodesize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10179:10204  gt(extcodesize(token), 0) */
      gt
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10160:10176  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10153:10177  iszero(returndatasize()) */
      iszero
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10149:10205  and(iszero(returndatasize()), gt(extcodesize(token), 0)) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10140:10147  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10136:10206  and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0))) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10125:10206  success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0))) */
      swap3
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9614:10220  if iszero(and(success, eq(mload(0x00), 1))) {... */
    tag_106:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10246:10249  fmp */
      dup1
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10240:10244  0x40 */
      0x40
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10233:10250  mstore(0x40, fmp) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9218:10260  {... */
      pop
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":9022:10266  function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {... */
      swap5
      swap4
      pop
      pop
      pop
      pop
      jump	// out
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10814:12207  function _safeTransferFrom(... */
    tag_102:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10972:10984  bool success */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10996:11011  bytes4 selector */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11014:11042  IERC20.transferFrom.selector */
      shl(0xe0, 0x23b872dd)
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10996:11042  bytes4 selector = IERC20.transferFrom.selector */
      swap1
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11109:11113  0x40 */
      0x40
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11103:11114  mload(0x40) */
      mload
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11140:11148  selector */
      dup2
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11134:11138  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11127:11149  mstore(0x00, selector) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11197:11198  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11193:11199  not(0) */
      not
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11189:11191  96 */
      0x60
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11185:11200  shr(96, not(0)) */
      shr
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11179:11183  from */
      dup8
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11175:11201  and(from, shr(96, not(0))) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11169:11173  0x04 */
      0x04
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11162:11202  mstore(0x04, and(from, shr(96, not(0)))) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11248:11249  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11244:11250  not(0) */
      not
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11240:11242  96 */
      0x60
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11236:11251  shr(96, not(0)) */
      shr
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11232:11234  to */
      dup7
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11228:11252  and(to, shr(96, not(0))) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11222:11226  0x24 */
      0x24
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11215:11253  mstore(0x24, and(to, shr(96, not(0)))) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11279:11284  value */
      dup5
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11273:11277  0x44 */
      0x44
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11266:11285  mstore(0x44, value) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11349:11353  0x20 */
      0x20
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11343:11347  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11337:11341  0x64 */
      0x64
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11331:11335  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11328:11329  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11321:11326  token */
      dup13
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11314:11319  gas() */
      gas
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11309:11354  call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20) */
      call
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11298:11354  success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20) */
      swap3
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11566:11567  1 */
      0x01
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11559:11563  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11553:11564  mload(0x00) */
      mload
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11550:11568  eq(mload(0x00), 1) */
      eq
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11541:11548  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11537:11569  and(success, eq(mload(0x00), 1)) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11527:12133  if iszero(and(success, eq(mload(0x00), 1))) {... */
      tag_109
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11698:11704  bubble */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11688:11695  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11681:11696  iszero(success) */
      iszero
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11677:11705  and(iszero(success), bubble) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11674:11839  if and(iszero(success), bubble) {... */
      iszero
      tag_110
      jumpi
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11754:11770  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11748:11752  0x00 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11743:11746  fmp */
      dup3
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11728:11771  returndatacopy(fmp, 0x00, returndatasize()) */
      returndatacopy
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11804:11820  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11799:11802  fmp */
      dup2
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11792:11821  revert(fmp, returndatasize()) */
      revert
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11674:11839  if and(iszero(success), bubble) {... */
    tag_110:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12115:12116  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12107:12112  token */
      dup9
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12095:12113  extcodesize(token) */
      extcodesize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12092:12117  gt(extcodesize(token), 0) */
      gt
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12073:12089  returndatasize() */
      returndatasize
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12066:12090  iszero(returndatasize()) */
      iszero
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12062:12118  and(iszero(returndatasize()), gt(extcodesize(token), 0)) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12053:12060  success */
      dup4
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12049:12119  and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0))) */
      and
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12038:12119  success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0))) */
      swap3
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11527:12133  if iszero(and(success, eq(mload(0x00), 1))) {... */
    tag_109:
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12159:12162  fmp */
      dup1
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12153:12157  0x40 */
      0x40
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12146:12163  mstore(0x40, fmp) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12189:12190  0 */
      0x00
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12183:12187  0x60 */
      0x60
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":12176:12191  mstore(0x60, 0) */
      mstore
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":11078:12201  {... */
      pop
      pop
        /* "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol":10814:12207  function _safeTransferFrom(... */
      swap6
      swap5
      pop
      pop
      pop
      pop
      pop
      jump	// out
        /* "#utility.yul":88:205   */
    tag_112:
        /* "#utility.yul":197:198   */
      0x00
        /* "#utility.yul":194:195   */
      0x00
        /* "#utility.yul":187:199   */
      revert
        /* "#utility.yul":211:328   */
    tag_113:
        /* "#utility.yul":320:321   */
      0x00
        /* "#utility.yul":317:318   */
      0x00
        /* "#utility.yul":310:322   */
      revert
        /* "#utility.yul":334:483   */
    tag_114:
        /* "#utility.yul":370:377   */
      0x00
        /* "#utility.yul":410:476   */
      0xffffffff00000000000000000000000000000000000000000000000000000000
        /* "#utility.yul":403:408   */
      dup3
        /* "#utility.yul":399:477   */
      and
        /* "#utility.yul":388:477   */
      swap1
      pop
        /* "#utility.yul":334:483   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":489:609   */
    tag_115:
        /* "#utility.yul":561:584   */
      tag_158
        /* "#utility.yul":578:583   */
      dup2
        /* "#utility.yul":561:584   */
      tag_114
      jump	// in
    tag_158:
        /* "#utility.yul":554:559   */
      dup2
        /* "#utility.yul":551:585   */
      eq
        /* "#utility.yul":541:603   */
      tag_159
      jumpi
        /* "#utility.yul":599:600   */
      0x00
        /* "#utility.yul":596:597   */
      0x00
        /* "#utility.yul":589:601   */
      revert
        /* "#utility.yul":541:603   */
    tag_159:
        /* "#utility.yul":489:609   */
      pop
      jump	// out
        /* "#utility.yul":615:752   */
    tag_116:
        /* "#utility.yul":660:665   */
      0x00
        /* "#utility.yul":698:704   */
      dup2
        /* "#utility.yul":685:705   */
      calldataload
        /* "#utility.yul":676:705   */
      swap1
      pop
        /* "#utility.yul":714:746   */
      tag_161
        /* "#utility.yul":740:745   */
      dup2
        /* "#utility.yul":714:746   */
      tag_115
      jump	// in
    tag_161:
        /* "#utility.yul":615:752   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":758:1085   */
    tag_13:
        /* "#utility.yul":816:822   */
      0x00
        /* "#utility.yul":865:867   */
      0x20
        /* "#utility.yul":853:862   */
      dup3
        /* "#utility.yul":844:851   */
      dup5
        /* "#utility.yul":840:863   */
      sub
        /* "#utility.yul":836:868   */
      slt
        /* "#utility.yul":833:952   */
      iszero
      tag_163
      jumpi
        /* "#utility.yul":871:950   */
      tag_164
      tag_112
      jump	// in
    tag_164:
        /* "#utility.yul":833:952   */
    tag_163:
        /* "#utility.yul":991:992   */
      0x00
        /* "#utility.yul":1016:1068   */
      tag_165
        /* "#utility.yul":1060:1067   */
      dup5
        /* "#utility.yul":1051:1057   */
      dup3
        /* "#utility.yul":1040:1049   */
      dup6
        /* "#utility.yul":1036:1058   */
      add
        /* "#utility.yul":1016:1068   */
      tag_116
      jump	// in
    tag_165:
        /* "#utility.yul":1006:1068   */
      swap2
      pop
        /* "#utility.yul":962:1078   */
      pop
        /* "#utility.yul":758:1085   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":1091:1181   */
    tag_117:
        /* "#utility.yul":1125:1132   */
      0x00
        /* "#utility.yul":1168:1173   */
      dup2
        /* "#utility.yul":1161:1174   */
      iszero
        /* "#utility.yul":1154:1175   */
      iszero
        /* "#utility.yul":1143:1175   */
      swap1
      pop
        /* "#utility.yul":1091:1181   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":1187:1296   */
    tag_118:
        /* "#utility.yul":1268:1289   */
      tag_168
        /* "#utility.yul":1283:1288   */
      dup2
        /* "#utility.yul":1268:1289   */
      tag_117
      jump	// in
    tag_168:
        /* "#utility.yul":1263:1266   */
      dup3
        /* "#utility.yul":1256:1290   */
      mstore
        /* "#utility.yul":1187:1296   */
      pop
      pop
      jump	// out
        /* "#utility.yul":1302:1512   */
    tag_16:
        /* "#utility.yul":1389:1393   */
      0x00
        /* "#utility.yul":1427:1429   */
      0x20
        /* "#utility.yul":1416:1425   */
      dup3
        /* "#utility.yul":1412:1430   */
      add
        /* "#utility.yul":1404:1430   */
      swap1
      pop
        /* "#utility.yul":1440:1505   */
      tag_170
        /* "#utility.yul":1502:1503   */
      0x00
        /* "#utility.yul":1491:1500   */
      dup4
        /* "#utility.yul":1487:1504   */
      add
        /* "#utility.yul":1478:1484   */
      dup5
        /* "#utility.yul":1440:1505   */
      tag_118
      jump	// in
    tag_170:
        /* "#utility.yul":1302:1512   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":1518:1644   */
    tag_119:
        /* "#utility.yul":1555:1562   */
      0x00
        /* "#utility.yul":1595:1637   */
      0xffffffffffffffffffffffffffffffffffffffff
        /* "#utility.yul":1588:1593   */
      dup3
        /* "#utility.yul":1584:1638   */
      and
        /* "#utility.yul":1573:1638   */
      swap1
      pop
        /* "#utility.yul":1518:1644   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":1650:1746   */
    tag_120:
        /* "#utility.yul":1687:1694   */
      0x00
        /* "#utility.yul":1716:1740   */
      tag_173
        /* "#utility.yul":1734:1739   */
      dup3
        /* "#utility.yul":1716:1740   */
      tag_119
      jump	// in
    tag_173:
        /* "#utility.yul":1705:1740   */
      swap1
      pop
        /* "#utility.yul":1650:1746   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":1752:1874   */
    tag_121:
        /* "#utility.yul":1825:1849   */
      tag_175
        /* "#utility.yul":1843:1848   */
      dup2
        /* "#utility.yul":1825:1849   */
      tag_120
      jump	// in
    tag_175:
        /* "#utility.yul":1818:1823   */
      dup2
        /* "#utility.yul":1815:1850   */
      eq
        /* "#utility.yul":1805:1868   */
      tag_176
      jumpi
        /* "#utility.yul":1864:1865   */
      0x00
        /* "#utility.yul":1861:1862   */
      0x00
        /* "#utility.yul":1854:1866   */
      revert
        /* "#utility.yul":1805:1868   */
    tag_176:
        /* "#utility.yul":1752:1874   */
      pop
      jump	// out
        /* "#utility.yul":1880:2019   */
    tag_122:
        /* "#utility.yul":1926:1931   */
      0x00
        /* "#utility.yul":1964:1970   */
      dup2
        /* "#utility.yul":1951:1971   */
      calldataload
        /* "#utility.yul":1942:1971   */
      swap1
      pop
        /* "#utility.yul":1980:2013   */
      tag_178
        /* "#utility.yul":2007:2012   */
      dup2
        /* "#utility.yul":1980:2013   */
      tag_121
      jump	// in
    tag_178:
        /* "#utility.yul":1880:2019   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":2025:2354   */
    tag_19:
        /* "#utility.yul":2084:2090   */
      0x00
        /* "#utility.yul":2133:2135   */
      0x20
        /* "#utility.yul":2121:2130   */
      dup3
        /* "#utility.yul":2112:2119   */
      dup5
        /* "#utility.yul":2108:2131   */
      sub
        /* "#utility.yul":2104:2136   */
      slt
        /* "#utility.yul":2101:2220   */
      iszero
      tag_180
      jumpi
        /* "#utility.yul":2139:2218   */
      tag_181
      tag_112
      jump	// in
    tag_181:
        /* "#utility.yul":2101:2220   */
    tag_180:
        /* "#utility.yul":2259:2260   */
      0x00
        /* "#utility.yul":2284:2337   */
      tag_182
        /* "#utility.yul":2329:2336   */
      dup5
        /* "#utility.yul":2320:2326   */
      dup3
        /* "#utility.yul":2309:2318   */
      dup6
        /* "#utility.yul":2305:2327   */
      add
        /* "#utility.yul":2284:2337   */
      tag_122
      jump	// in
    tag_182:
        /* "#utility.yul":2274:2337   */
      swap2
      pop
        /* "#utility.yul":2230:2347   */
      pop
        /* "#utility.yul":2025:2354   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":2360:2437   */
    tag_123:
        /* "#utility.yul":2397:2404   */
      0x00
        /* "#utility.yul":2426:2431   */
      dup2
        /* "#utility.yul":2415:2431   */
      swap1
      pop
        /* "#utility.yul":2360:2437   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":2443:2561   */
    tag_124:
        /* "#utility.yul":2530:2554   */
      tag_185
        /* "#utility.yul":2548:2553   */
      dup2
        /* "#utility.yul":2530:2554   */
      tag_123
      jump	// in
    tag_185:
        /* "#utility.yul":2525:2528   */
      dup3
        /* "#utility.yul":2518:2555   */
      mstore
        /* "#utility.yul":2443:2561   */
      pop
      pop
      jump	// out
        /* "#utility.yul":2567:2789   */
    tag_22:
        /* "#utility.yul":2660:2664   */
      0x00
        /* "#utility.yul":2698:2700   */
      0x20
        /* "#utility.yul":2687:2696   */
      dup3
        /* "#utility.yul":2683:2701   */
      add
        /* "#utility.yul":2675:2701   */
      swap1
      pop
        /* "#utility.yul":2711:2782   */
      tag_187
        /* "#utility.yul":2779:2780   */
      0x00
        /* "#utility.yul":2768:2777   */
      dup4
        /* "#utility.yul":2764:2781   */
      add
        /* "#utility.yul":2755:2761   */
      dup5
        /* "#utility.yul":2711:2782   */
      tag_124
      jump	// in
    tag_187:
        /* "#utility.yul":2567:2789   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":2795:2917   */
    tag_125:
        /* "#utility.yul":2868:2892   */
      tag_189
        /* "#utility.yul":2886:2891   */
      dup2
        /* "#utility.yul":2868:2892   */
      tag_123
      jump	// in
    tag_189:
        /* "#utility.yul":2861:2866   */
      dup2
        /* "#utility.yul":2858:2893   */
      eq
        /* "#utility.yul":2848:2911   */
      tag_190
      jumpi
        /* "#utility.yul":2907:2908   */
      0x00
        /* "#utility.yul":2904:2905   */
      0x00
        /* "#utility.yul":2897:2909   */
      revert
        /* "#utility.yul":2848:2911   */
    tag_190:
        /* "#utility.yul":2795:2917   */
      pop
      jump	// out
        /* "#utility.yul":2923:3062   */
    tag_126:
        /* "#utility.yul":2969:2974   */
      0x00
        /* "#utility.yul":3007:3013   */
      dup2
        /* "#utility.yul":2994:3014   */
      calldataload
        /* "#utility.yul":2985:3014   */
      swap1
      pop
        /* "#utility.yul":3023:3056   */
      tag_192
        /* "#utility.yul":3050:3055   */
      dup2
        /* "#utility.yul":3023:3056   */
      tag_125
      jump	// in
    tag_192:
        /* "#utility.yul":2923:3062   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":3068:3397   */
    tag_25:
        /* "#utility.yul":3127:3133   */
      0x00
        /* "#utility.yul":3176:3178   */
      0x20
        /* "#utility.yul":3164:3173   */
      dup3
        /* "#utility.yul":3155:3162   */
      dup5
        /* "#utility.yul":3151:3174   */
      sub
        /* "#utility.yul":3147:3179   */
      slt
        /* "#utility.yul":3144:3263   */
      iszero
      tag_194
      jumpi
        /* "#utility.yul":3182:3261   */
      tag_195
      tag_112
      jump	// in
    tag_195:
        /* "#utility.yul":3144:3263   */
    tag_194:
        /* "#utility.yul":3302:3303   */
      0x00
        /* "#utility.yul":3327:3380   */
      tag_196
        /* "#utility.yul":3372:3379   */
      dup5
        /* "#utility.yul":3363:3369   */
      dup3
        /* "#utility.yul":3352:3361   */
      dup6
        /* "#utility.yul":3348:3370   */
      add
        /* "#utility.yul":3327:3380   */
      tag_126
      jump	// in
    tag_196:
        /* "#utility.yul":3317:3380   */
      swap2
      pop
        /* "#utility.yul":3273:3390   */
      pop
        /* "#utility.yul":3068:3397   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":3403:3520   */
    tag_127:
        /* "#utility.yul":3512:3513   */
      0x00
        /* "#utility.yul":3509:3510   */
      0x00
        /* "#utility.yul":3502:3514   */
      revert
        /* "#utility.yul":3526:3643   */
    tag_128:
        /* "#utility.yul":3635:3636   */
      0x00
        /* "#utility.yul":3632:3633   */
      0x00
        /* "#utility.yul":3625:3637   */
      revert
        /* "#utility.yul":3649:3766   */
    tag_129:
        /* "#utility.yul":3758:3759   */
      0x00
        /* "#utility.yul":3755:3756   */
      0x00
        /* "#utility.yul":3748:3760   */
      revert
        /* "#utility.yul":3785:4337   */
    tag_130:
        /* "#utility.yul":3842:3850   */
      0x00
        /* "#utility.yul":3852:3858   */
      0x00
        /* "#utility.yul":3902:3905   */
      dup4
        /* "#utility.yul":3895:3899   */
      0x1f
        /* "#utility.yul":3887:3893   */
      dup5
        /* "#utility.yul":3883:3900   */
      add
        /* "#utility.yul":3879:3906   */
      slt
        /* "#utility.yul":3869:3991   */
      tag_201
      jumpi
        /* "#utility.yul":3910:3989   */
      tag_202
      tag_127
      jump	// in
    tag_202:
        /* "#utility.yul":3869:3991   */
    tag_201:
        /* "#utility.yul":4023:4029   */
      dup3
        /* "#utility.yul":4010:4030   */
      calldataload
        /* "#utility.yul":4000:4030   */
      swap1
      pop
        /* "#utility.yul":4053:4071   */
      0xffffffffffffffff
        /* "#utility.yul":4045:4051   */
      dup2
        /* "#utility.yul":4042:4072   */
      gt
        /* "#utility.yul":4039:4156   */
      iszero
      tag_203
      jumpi
        /* "#utility.yul":4075:4154   */
      tag_204
      tag_128
      jump	// in
    tag_204:
        /* "#utility.yul":4039:4156   */
    tag_203:
        /* "#utility.yul":4189:4193   */
      0x20
        /* "#utility.yul":4181:4187   */
      dup4
        /* "#utility.yul":4177:4194   */
      add
        /* "#utility.yul":4165:4194   */
      swap2
      pop
        /* "#utility.yul":4243:4246   */
      dup4
        /* "#utility.yul":4235:4239   */
      0x01
        /* "#utility.yul":4227:4233   */
      dup3
        /* "#utility.yul":4223:4240   */
      mul
        /* "#utility.yul":4213:4221   */
      dup4
        /* "#utility.yul":4209:4241   */
      add
        /* "#utility.yul":4206:4247   */
      gt
        /* "#utility.yul":4203:4331   */
      iszero
      tag_205
      jumpi
        /* "#utility.yul":4250:4329   */
      tag_206
      tag_129
      jump	// in
    tag_206:
        /* "#utility.yul":4203:4331   */
    tag_205:
        /* "#utility.yul":3785:4337   */
      swap3
      pop
      swap3
      swap1
      pop
      jump	// out
        /* "#utility.yul":4343:5160   */
    tag_29:
        /* "#utility.yul":4431:4437   */
      0x00
        /* "#utility.yul":4439:4445   */
      0x00
        /* "#utility.yul":4447:4453   */
      0x00
        /* "#utility.yul":4455:4461   */
      0x00
        /* "#utility.yul":4504:4506   */
      0x60
        /* "#utility.yul":4492:4501   */
      dup6
        /* "#utility.yul":4483:4490   */
      dup8
        /* "#utility.yul":4479:4502   */
      sub
        /* "#utility.yul":4475:4507   */
      slt
        /* "#utility.yul":4472:4591   */
      iszero
      tag_208
      jumpi
        /* "#utility.yul":4510:4589   */
      tag_209
      tag_112
      jump	// in
    tag_209:
        /* "#utility.yul":4472:4591   */
    tag_208:
        /* "#utility.yul":4630:4631   */
      0x00
        /* "#utility.yul":4655:4708   */
      tag_210
        /* "#utility.yul":4700:4707   */
      dup8
        /* "#utility.yul":4691:4697   */
      dup3
        /* "#utility.yul":4680:4689   */
      dup9
        /* "#utility.yul":4676:4698   */
      add
        /* "#utility.yul":4655:4708   */
      tag_122
      jump	// in
    tag_210:
        /* "#utility.yul":4645:4708   */
      swap5
      pop
        /* "#utility.yul":4601:4718   */
      pop
        /* "#utility.yul":4757:4759   */
      0x20
        /* "#utility.yul":4783:4836   */
      tag_211
        /* "#utility.yul":4828:4835   */
      dup8
        /* "#utility.yul":4819:4825   */
      dup3
        /* "#utility.yul":4808:4817   */
      dup9
        /* "#utility.yul":4804:4826   */
      add
        /* "#utility.yul":4783:4836   */
      tag_126
      jump	// in
    tag_211:
        /* "#utility.yul":4773:4836   */
      swap4
      pop
        /* "#utility.yul":4728:4846   */
      pop
        /* "#utility.yul":4913:4915   */
      0x40
        /* "#utility.yul":4902:4911   */
      dup6
        /* "#utility.yul":4898:4916   */
      add
        /* "#utility.yul":4885:4917   */
      calldataload
        /* "#utility.yul":4944:4962   */
      0xffffffffffffffff
        /* "#utility.yul":4936:4942   */
      dup2
        /* "#utility.yul":4933:4963   */
      gt
        /* "#utility.yul":4930:5047   */
      iszero
      tag_212
      jumpi
        /* "#utility.yul":4966:5045   */
      tag_213
      tag_113
      jump	// in
    tag_213:
        /* "#utility.yul":4930:5047   */
    tag_212:
        /* "#utility.yul":5079:5143   */
      tag_214
        /* "#utility.yul":5135:5142   */
      dup8
        /* "#utility.yul":5126:5132   */
      dup3
        /* "#utility.yul":5115:5124   */
      dup9
        /* "#utility.yul":5111:5133   */
      add
        /* "#utility.yul":5079:5143   */
      tag_130
      jump	// in
    tag_214:
        /* "#utility.yul":5061:5143   */
      swap3
      pop
      swap3
      pop
        /* "#utility.yul":4856:5153   */
      pop
        /* "#utility.yul":4343:5160   */
      swap3
      swap6
      swap2
      swap5
      pop
      swap3
      pop
      jump	// out
        /* "#utility.yul":5166:5281   */
    tag_131:
        /* "#utility.yul":5251:5274   */
      tag_216
        /* "#utility.yul":5268:5273   */
      dup2
        /* "#utility.yul":5251:5274   */
      tag_114
      jump	// in
    tag_216:
        /* "#utility.yul":5246:5249   */
      dup3
        /* "#utility.yul":5239:5275   */
      mstore
        /* "#utility.yul":5166:5281   */
      pop
      pop
      jump	// out
        /* "#utility.yul":5287:5505   */
    tag_32:
        /* "#utility.yul":5378:5382   */
      0x00
        /* "#utility.yul":5416:5418   */
      0x20
        /* "#utility.yul":5405:5414   */
      dup3
        /* "#utility.yul":5401:5419   */
      add
        /* "#utility.yul":5393:5419   */
      swap1
      pop
        /* "#utility.yul":5429:5498   */
      tag_218
        /* "#utility.yul":5495:5496   */
      0x00
        /* "#utility.yul":5484:5493   */
      dup4
        /* "#utility.yul":5480:5497   */
      add
        /* "#utility.yul":5471:5477   */
      dup5
        /* "#utility.yul":5429:5498   */
      tag_131
      jump	// in
    tag_218:
        /* "#utility.yul":5287:5505   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":5511:6474   */
    tag_35:
        /* "#utility.yul":5608:5614   */
      0x00
        /* "#utility.yul":5616:5622   */
      0x00
        /* "#utility.yul":5624:5630   */
      0x00
        /* "#utility.yul":5632:5638   */
      0x00
        /* "#utility.yul":5640:5646   */
      0x00
        /* "#utility.yul":5689:5692   */
      0x80
        /* "#utility.yul":5677:5686   */
      dup7
        /* "#utility.yul":5668:5675   */
      dup9
        /* "#utility.yul":5664:5687   */
      sub
        /* "#utility.yul":5660:5693   */
      slt
        /* "#utility.yul":5657:5777   */
      iszero
      tag_220
      jumpi
        /* "#utility.yul":5696:5775   */
      tag_221
      tag_112
      jump	// in
    tag_221:
        /* "#utility.yul":5657:5777   */
    tag_220:
        /* "#utility.yul":5816:5817   */
      0x00
        /* "#utility.yul":5841:5894   */
      tag_222
        /* "#utility.yul":5886:5893   */
      dup9
        /* "#utility.yul":5877:5883   */
      dup3
        /* "#utility.yul":5866:5875   */
      dup10
        /* "#utility.yul":5862:5884   */
      add
        /* "#utility.yul":5841:5894   */
      tag_122
      jump	// in
    tag_222:
        /* "#utility.yul":5831:5894   */
      swap6
      pop
        /* "#utility.yul":5787:5904   */
      pop
        /* "#utility.yul":5943:5945   */
      0x20
        /* "#utility.yul":5969:6022   */
      tag_223
        /* "#utility.yul":6014:6021   */
      dup9
        /* "#utility.yul":6005:6011   */
      dup3
        /* "#utility.yul":5994:6003   */
      dup10
        /* "#utility.yul":5990:6012   */
      add
        /* "#utility.yul":5969:6022   */
      tag_122
      jump	// in
    tag_223:
        /* "#utility.yul":5959:6022   */
      swap5
      pop
        /* "#utility.yul":5914:6032   */
      pop
        /* "#utility.yul":6071:6073   */
      0x40
        /* "#utility.yul":6097:6150   */
      tag_224
        /* "#utility.yul":6142:6149   */
      dup9
        /* "#utility.yul":6133:6139   */
      dup3
        /* "#utility.yul":6122:6131   */
      dup10
        /* "#utility.yul":6118:6140   */
      add
        /* "#utility.yul":6097:6150   */
      tag_126
      jump	// in
    tag_224:
        /* "#utility.yul":6087:6150   */
      swap4
      pop
        /* "#utility.yul":6042:6160   */
      pop
        /* "#utility.yul":6227:6229   */
      0x60
        /* "#utility.yul":6216:6225   */
      dup7
        /* "#utility.yul":6212:6230   */
      add
        /* "#utility.yul":6199:6231   */
      calldataload
        /* "#utility.yul":6258:6276   */
      0xffffffffffffffff
        /* "#utility.yul":6250:6256   */
      dup2
        /* "#utility.yul":6247:6277   */
      gt
        /* "#utility.yul":6244:6361   */
      iszero
      tag_225
      jumpi
        /* "#utility.yul":6280:6359   */
      tag_226
      tag_113
      jump	// in
    tag_226:
        /* "#utility.yul":6244:6361   */
    tag_225:
        /* "#utility.yul":6393:6457   */
      tag_227
        /* "#utility.yul":6449:6456   */
      dup9
        /* "#utility.yul":6440:6446   */
      dup3
        /* "#utility.yul":6429:6438   */
      dup10
        /* "#utility.yul":6425:6447   */
      add
        /* "#utility.yul":6393:6457   */
      tag_130
      jump	// in
    tag_227:
        /* "#utility.yul":6375:6457   */
      swap3
      pop
      swap3
      pop
        /* "#utility.yul":6170:6467   */
      pop
        /* "#utility.yul":5511:6474   */
      swap3
      swap6
      pop
      swap3
      swap6
      swap1
      swap4
      pop
      jump	// out
        /* "#utility.yul":6480:6540   */
    tag_132:
        /* "#utility.yul":6508:6511   */
      0x00
        /* "#utility.yul":6529:6534   */
      dup2
        /* "#utility.yul":6522:6534   */
      swap1
      pop
        /* "#utility.yul":6480:6540   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":6546:6688   */
    tag_133:
        /* "#utility.yul":6596:6605   */
      0x00
        /* "#utility.yul":6629:6682   */
      tag_230
        /* "#utility.yul":6647:6681   */
      tag_231
        /* "#utility.yul":6656:6680   */
      tag_232
        /* "#utility.yul":6674:6679   */
      dup5
        /* "#utility.yul":6656:6680   */
      tag_119
      jump	// in
    tag_232:
        /* "#utility.yul":6647:6681   */
      tag_132
      jump	// in
    tag_231:
        /* "#utility.yul":6629:6682   */
      tag_119
      jump	// in
    tag_230:
        /* "#utility.yul":6616:6682   */
      swap1
      pop
        /* "#utility.yul":6546:6688   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":6694:6820   */
    tag_134:
        /* "#utility.yul":6744:6753   */
      0x00
        /* "#utility.yul":6777:6814   */
      tag_234
        /* "#utility.yul":6808:6813   */
      dup3
        /* "#utility.yul":6777:6814   */
      tag_133
      jump	// in
    tag_234:
        /* "#utility.yul":6764:6814   */
      swap1
      pop
        /* "#utility.yul":6694:6820   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":6826:6966   */
    tag_135:
        /* "#utility.yul":6890:6899   */
      0x00
        /* "#utility.yul":6923:6960   */
      tag_236
        /* "#utility.yul":6954:6959   */
      dup3
        /* "#utility.yul":6923:6960   */
      tag_134
      jump	// in
    tag_236:
        /* "#utility.yul":6910:6960   */
      swap1
      pop
        /* "#utility.yul":6826:6966   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":6972:7131   */
    tag_136:
        /* "#utility.yul":7073:7124   */
      tag_238
        /* "#utility.yul":7118:7123   */
      dup2
        /* "#utility.yul":7073:7124   */
      tag_135
      jump	// in
    tag_238:
        /* "#utility.yul":7068:7071   */
      dup3
        /* "#utility.yul":7061:7125   */
      mstore
        /* "#utility.yul":6972:7131   */
      pop
      pop
      jump	// out
        /* "#utility.yul":7137:7387   */
    tag_44:
        /* "#utility.yul":7244:7248   */
      0x00
        /* "#utility.yul":7282:7284   */
      0x20
        /* "#utility.yul":7271:7280   */
      dup3
        /* "#utility.yul":7267:7285   */
      add
        /* "#utility.yul":7259:7285   */
      swap1
      pop
        /* "#utility.yul":7295:7380   */
      tag_240
        /* "#utility.yul":7377:7378   */
      0x00
        /* "#utility.yul":7366:7375   */
      dup4
        /* "#utility.yul":7362:7379   */
      add
        /* "#utility.yul":7353:7359   */
      dup5
        /* "#utility.yul":7295:7380   */
      tag_136
      jump	// in
    tag_240:
        /* "#utility.yul":7137:7387   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":7393:7562   */
    tag_137:
        /* "#utility.yul":7477:7488   */
      0x00
        /* "#utility.yul":7511:7517   */
      dup3
        /* "#utility.yul":7506:7509   */
      dup3
        /* "#utility.yul":7499:7518   */
      mstore
        /* "#utility.yul":7551:7555   */
      0x20
        /* "#utility.yul":7546:7549   */
      dup3
        /* "#utility.yul":7542:7556   */
      add
        /* "#utility.yul":7527:7556   */
      swap1
      pop
        /* "#utility.yul":7393:7562   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":7568:7731   */
    tag_138:
        /* "#utility.yul":7708:7723   */
      0x5a65726f20776974686472617700000000000000000000000000000000000000
        /* "#utility.yul":7704:7705   */
      0x00
        /* "#utility.yul":7696:7702   */
      dup3
        /* "#utility.yul":7692:7706   */
      add
        /* "#utility.yul":7685:7724   */
      mstore
        /* "#utility.yul":7568:7731   */
      pop
      jump	// out
        /* "#utility.yul":7737:8103   */
    tag_139:
        /* "#utility.yul":7879:7882   */
      0x00
        /* "#utility.yul":7900:7967   */
      tag_244
        /* "#utility.yul":7964:7966   */
      0x0d
        /* "#utility.yul":7959:7962   */
      dup4
        /* "#utility.yul":7900:7967   */
      tag_137
      jump	// in
    tag_244:
        /* "#utility.yul":7893:7967   */
      swap2
      pop
        /* "#utility.yul":7976:8069   */
      tag_245
        /* "#utility.yul":8065:8068   */
      dup3
        /* "#utility.yul":7976:8069   */
      tag_138
      jump	// in
    tag_245:
        /* "#utility.yul":8094:8096   */
      0x20
        /* "#utility.yul":8089:8092   */
      dup3
        /* "#utility.yul":8085:8097   */
      add
        /* "#utility.yul":8078:8097   */
      swap1
      pop
        /* "#utility.yul":7737:8103   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":8109:8528   */
    tag_53:
        /* "#utility.yul":8275:8279   */
      0x00
        /* "#utility.yul":8313:8315   */
      0x20
        /* "#utility.yul":8302:8311   */
      dup3
        /* "#utility.yul":8298:8316   */
      add
        /* "#utility.yul":8290:8316   */
      swap1
      pop
        /* "#utility.yul":8362:8371   */
      dup2
        /* "#utility.yul":8356:8360   */
      dup2
        /* "#utility.yul":8352:8372   */
      sub
        /* "#utility.yul":8348:8349   */
      0x00
        /* "#utility.yul":8337:8346   */
      dup4
        /* "#utility.yul":8333:8350   */
      add
        /* "#utility.yul":8326:8373   */
      mstore
        /* "#utility.yul":8390:8521   */
      tag_247
        /* "#utility.yul":8516:8520   */
      dup2
        /* "#utility.yul":8390:8521   */
      tag_139
      jump	// in
    tag_247:
        /* "#utility.yul":8382:8521   */
      swap1
      pop
        /* "#utility.yul":8109:8528   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":8534:8704   */
    tag_140:
        /* "#utility.yul":8674:8696   */
      0x496e73756666696369656e742062616c616e6365000000000000000000000000
        /* "#utility.yul":8670:8671   */
      0x00
        /* "#utility.yul":8662:8668   */
      dup3
        /* "#utility.yul":8658:8672   */
      add
        /* "#utility.yul":8651:8697   */
      mstore
        /* "#utility.yul":8534:8704   */
      pop
      jump	// out
        /* "#utility.yul":8710:9076   */
    tag_141:
        /* "#utility.yul":8852:8855   */
      0x00
        /* "#utility.yul":8873:8940   */
      tag_250
        /* "#utility.yul":8937:8939   */
      0x14
        /* "#utility.yul":8932:8935   */
      dup4
        /* "#utility.yul":8873:8940   */
      tag_137
      jump	// in
    tag_250:
        /* "#utility.yul":8866:8940   */
      swap2
      pop
        /* "#utility.yul":8949:9042   */
      tag_251
        /* "#utility.yul":9038:9041   */
      dup3
        /* "#utility.yul":8949:9042   */
      tag_140
      jump	// in
    tag_251:
        /* "#utility.yul":9067:9069   */
      0x20
        /* "#utility.yul":9062:9065   */
      dup3
        /* "#utility.yul":9058:9070   */
      add
        /* "#utility.yul":9051:9070   */
      swap1
      pop
        /* "#utility.yul":8710:9076   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":9082:9501   */
    tag_56:
        /* "#utility.yul":9248:9252   */
      0x00
        /* "#utility.yul":9286:9288   */
      0x20
        /* "#utility.yul":9275:9284   */
      dup3
        /* "#utility.yul":9271:9289   */
      add
        /* "#utility.yul":9263:9289   */
      swap1
      pop
        /* "#utility.yul":9335:9344   */
      dup2
        /* "#utility.yul":9329:9333   */
      dup2
        /* "#utility.yul":9325:9345   */
      sub
        /* "#utility.yul":9321:9322   */
      0x00
        /* "#utility.yul":9310:9319   */
      dup4
        /* "#utility.yul":9306:9323   */
      add
        /* "#utility.yul":9299:9346   */
      mstore
        /* "#utility.yul":9363:9494   */
      tag_253
        /* "#utility.yul":9489:9493   */
      dup2
        /* "#utility.yul":9363:9494   */
      tag_141
      jump	// in
    tag_253:
        /* "#utility.yul":9355:9494   */
      swap1
      pop
        /* "#utility.yul":9082:9501   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":9507:9687   */
    tag_142:
        /* "#utility.yul":9555:9632   */
      0x4e487b7100000000000000000000000000000000000000000000000000000000
        /* "#utility.yul":9552:9553   */
      0x00
        /* "#utility.yul":9545:9633   */
      mstore
        /* "#utility.yul":9652:9656   */
      0x11
        /* "#utility.yul":9649:9650   */
      0x04
        /* "#utility.yul":9642:9657   */
      mstore
        /* "#utility.yul":9676:9680   */
      0x24
        /* "#utility.yul":9673:9674   */
      0x00
        /* "#utility.yul":9666:9681   */
      revert
        /* "#utility.yul":9693:9887   */
    tag_58:
        /* "#utility.yul":9733:9737   */
      0x00
        /* "#utility.yul":9753:9773   */
      tag_256
        /* "#utility.yul":9771:9772   */
      dup3
        /* "#utility.yul":9753:9773   */
      tag_123
      jump	// in
    tag_256:
        /* "#utility.yul":9748:9773   */
      swap2
      pop
        /* "#utility.yul":9787:9807   */
      tag_257
        /* "#utility.yul":9805:9806   */
      dup4
        /* "#utility.yul":9787:9807   */
      tag_123
      jump	// in
    tag_257:
        /* "#utility.yul":9782:9807   */
      swap3
      pop
        /* "#utility.yul":9831:9832   */
      dup3
        /* "#utility.yul":9828:9829   */
      dup3
        /* "#utility.yul":9824:9833   */
      sub
        /* "#utility.yul":9816:9833   */
      swap1
      pop
        /* "#utility.yul":9855:9856   */
      dup2
        /* "#utility.yul":9849:9853   */
      dup2
        /* "#utility.yul":9846:9857   */
      gt
        /* "#utility.yul":9843:9880   */
      iszero
      tag_258
      jumpi
        /* "#utility.yul":9860:9878   */
      tag_259
      tag_142
      jump	// in
    tag_259:
        /* "#utility.yul":9843:9880   */
    tag_258:
        /* "#utility.yul":9693:9887   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":9893:10056   */
    tag_143:
        /* "#utility.yul":10033:10048   */
      0x496e76616c696420746f6b656e00000000000000000000000000000000000000
        /* "#utility.yul":10029:10030   */
      0x00
        /* "#utility.yul":10021:10027   */
      dup3
        /* "#utility.yul":10017:10031   */
      add
        /* "#utility.yul":10010:10049   */
      mstore
        /* "#utility.yul":9893:10056   */
      pop
      jump	// out
        /* "#utility.yul":10062:10428   */
    tag_144:
        /* "#utility.yul":10204:10207   */
      0x00
        /* "#utility.yul":10225:10292   */
      tag_262
        /* "#utility.yul":10289:10291   */
      0x0d
        /* "#utility.yul":10284:10287   */
      dup4
        /* "#utility.yul":10225:10292   */
      tag_137
      jump	// in
    tag_262:
        /* "#utility.yul":10218:10292   */
      swap2
      pop
        /* "#utility.yul":10301:10394   */
      tag_263
        /* "#utility.yul":10390:10393   */
      dup3
        /* "#utility.yul":10301:10394   */
      tag_143
      jump	// in
    tag_263:
        /* "#utility.yul":10419:10421   */
      0x20
        /* "#utility.yul":10414:10417   */
      dup3
        /* "#utility.yul":10410:10422   */
      add
        /* "#utility.yul":10403:10422   */
      swap1
      pop
        /* "#utility.yul":10062:10428   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":10434:10853   */
    tag_65:
        /* "#utility.yul":10600:10604   */
      0x00
        /* "#utility.yul":10638:10640   */
      0x20
        /* "#utility.yul":10627:10636   */
      dup3
        /* "#utility.yul":10623:10641   */
      add
        /* "#utility.yul":10615:10641   */
      swap1
      pop
        /* "#utility.yul":10687:10696   */
      dup2
        /* "#utility.yul":10681:10685   */
      dup2
        /* "#utility.yul":10677:10697   */
      sub
        /* "#utility.yul":10673:10674   */
      0x00
        /* "#utility.yul":10662:10671   */
      dup4
        /* "#utility.yul":10658:10675   */
      add
        /* "#utility.yul":10651:10698   */
      mstore
        /* "#utility.yul":10715:10846   */
      tag_265
        /* "#utility.yul":10841:10845   */
      dup2
        /* "#utility.yul":10715:10846   */
      tag_144
      jump	// in
    tag_265:
        /* "#utility.yul":10707:10846   */
      swap1
      pop
        /* "#utility.yul":10434:10853   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":10859:11021   */
    tag_145:
        /* "#utility.yul":10999:11013   */
      0x5a65726f206465706f7369740000000000000000000000000000000000000000
        /* "#utility.yul":10995:10996   */
      0x00
        /* "#utility.yul":10987:10993   */
      dup3
        /* "#utility.yul":10983:10997   */
      add
        /* "#utility.yul":10976:11014   */
      mstore
        /* "#utility.yul":10859:11021   */
      pop
      jump	// out
        /* "#utility.yul":11027:11393   */
    tag_146:
        /* "#utility.yul":11169:11172   */
      0x00
        /* "#utility.yul":11190:11257   */
      tag_268
        /* "#utility.yul":11254:11256   */
      0x0c
        /* "#utility.yul":11249:11252   */
      dup4
        /* "#utility.yul":11190:11257   */
      tag_137
      jump	// in
    tag_268:
        /* "#utility.yul":11183:11257   */
      swap2
      pop
        /* "#utility.yul":11266:11359   */
      tag_269
        /* "#utility.yul":11355:11358   */
      dup3
        /* "#utility.yul":11266:11359   */
      tag_145
      jump	// in
    tag_269:
        /* "#utility.yul":11384:11386   */
      0x20
        /* "#utility.yul":11379:11382   */
      dup3
        /* "#utility.yul":11375:11387   */
      add
        /* "#utility.yul":11368:11387   */
      swap1
      pop
        /* "#utility.yul":11027:11393   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":11399:11818   */
    tag_68:
        /* "#utility.yul":11565:11569   */
      0x00
        /* "#utility.yul":11603:11605   */
      0x20
        /* "#utility.yul":11592:11601   */
      dup3
        /* "#utility.yul":11588:11606   */
      add
        /* "#utility.yul":11580:11606   */
      swap1
      pop
        /* "#utility.yul":11652:11661   */
      dup2
        /* "#utility.yul":11646:11650   */
      dup2
        /* "#utility.yul":11642:11662   */
      sub
        /* "#utility.yul":11638:11639   */
      0x00
        /* "#utility.yul":11627:11636   */
      dup4
        /* "#utility.yul":11623:11640   */
      add
        /* "#utility.yul":11616:11663   */
      mstore
        /* "#utility.yul":11680:11811   */
      tag_271
        /* "#utility.yul":11806:11810   */
      dup2
        /* "#utility.yul":11680:11811   */
      tag_146
      jump	// in
    tag_271:
        /* "#utility.yul":11672:11811   */
      swap1
      pop
        /* "#utility.yul":11399:11818   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":11824:11984   */
    tag_147:
        /* "#utility.yul":11964:11976   */
      0x5a65726f206f776e657200000000000000000000000000000000000000000000
        /* "#utility.yul":11960:11961   */
      0x00
        /* "#utility.yul":11952:11958   */
      dup3
        /* "#utility.yul":11948:11962   */
      add
        /* "#utility.yul":11941:11977   */
      mstore
        /* "#utility.yul":11824:11984   */
      pop
      jump	// out
        /* "#utility.yul":11990:12356   */
    tag_148:
        /* "#utility.yul":12132:12135   */
      0x00
        /* "#utility.yul":12153:12220   */
      tag_274
        /* "#utility.yul":12217:12219   */
      0x0a
        /* "#utility.yul":12212:12215   */
      dup4
        /* "#utility.yul":12153:12220   */
      tag_137
      jump	// in
    tag_274:
        /* "#utility.yul":12146:12220   */
      swap2
      pop
        /* "#utility.yul":12229:12322   */
      tag_275
        /* "#utility.yul":12318:12321   */
      dup3
        /* "#utility.yul":12229:12322   */
      tag_147
      jump	// in
    tag_275:
        /* "#utility.yul":12347:12349   */
      0x20
        /* "#utility.yul":12342:12345   */
      dup3
        /* "#utility.yul":12338:12350   */
      add
        /* "#utility.yul":12331:12350   */
      swap1
      pop
        /* "#utility.yul":11990:12356   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":12362:12781   */
    tag_71:
        /* "#utility.yul":12528:12532   */
      0x00
        /* "#utility.yul":12566:12568   */
      0x20
        /* "#utility.yul":12555:12564   */
      dup3
        /* "#utility.yul":12551:12569   */
      add
        /* "#utility.yul":12543:12569   */
      swap1
      pop
        /* "#utility.yul":12615:12624   */
      dup2
        /* "#utility.yul":12609:12613   */
      dup2
        /* "#utility.yul":12605:12625   */
      sub
        /* "#utility.yul":12601:12602   */
      0x00
        /* "#utility.yul":12590:12599   */
      dup4
        /* "#utility.yul":12586:12603   */
      add
        /* "#utility.yul":12579:12626   */
      mstore
        /* "#utility.yul":12643:12774   */
      tag_277
        /* "#utility.yul":12769:12773   */
      dup2
        /* "#utility.yul":12643:12774   */
      tag_148
      jump	// in
    tag_277:
        /* "#utility.yul":12635:12774   */
      swap1
      pop
        /* "#utility.yul":12362:12781   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":12787:12978   */
    tag_75:
        /* "#utility.yul":12827:12830   */
      0x00
        /* "#utility.yul":12846:12866   */
      tag_279
        /* "#utility.yul":12864:12865   */
      dup3
        /* "#utility.yul":12846:12866   */
      tag_123
      jump	// in
    tag_279:
        /* "#utility.yul":12841:12866   */
      swap2
      pop
        /* "#utility.yul":12880:12900   */
      tag_280
        /* "#utility.yul":12898:12899   */
      dup4
        /* "#utility.yul":12880:12900   */
      tag_123
      jump	// in
    tag_280:
        /* "#utility.yul":12875:12900   */
      swap3
      pop
        /* "#utility.yul":12923:12924   */
      dup3
        /* "#utility.yul":12920:12921   */
      dup3
        /* "#utility.yul":12916:12925   */
      add
        /* "#utility.yul":12909:12925   */
      swap1
      pop
        /* "#utility.yul":12944:12947   */
      dup1
        /* "#utility.yul":12941:12942   */
      dup3
        /* "#utility.yul":12938:12948   */
      gt
        /* "#utility.yul":12935:12971   */
      iszero
      tag_281
      jumpi
        /* "#utility.yul":12951:12969   */
      tag_282
      tag_142
      jump	// in
    tag_282:
        /* "#utility.yul":12935:12971   */
    tag_281:
        /* "#utility.yul":12787:12978   */
      swap3
      swap2
      pop
      pop
      jump	// out
        /* "#utility.yul":12984:13143   */
    tag_149:
        /* "#utility.yul":13124:13135   */
      0x5a65726f2066726f6d0000000000000000000000000000000000000000000000
        /* "#utility.yul":13120:13121   */
      0x00
        /* "#utility.yul":13112:13118   */
      dup3
        /* "#utility.yul":13108:13122   */
      add
        /* "#utility.yul":13101:13136   */
      mstore
        /* "#utility.yul":12984:13143   */
      pop
      jump	// out
        /* "#utility.yul":13149:13514   */
    tag_150:
        /* "#utility.yul":13291:13294   */
      0x00
        /* "#utility.yul":13312:13378   */
      tag_285
        /* "#utility.yul":13376:13377   */
      0x09
        /* "#utility.yul":13371:13374   */
      dup4
        /* "#utility.yul":13312:13378   */
      tag_137
      jump	// in
    tag_285:
        /* "#utility.yul":13305:13378   */
      swap2
      pop
        /* "#utility.yul":13387:13480   */
      tag_286
        /* "#utility.yul":13476:13479   */
      dup3
        /* "#utility.yul":13387:13480   */
      tag_149
      jump	// in
    tag_286:
        /* "#utility.yul":13505:13507   */
      0x20
        /* "#utility.yul":13500:13503   */
      dup3
        /* "#utility.yul":13496:13508   */
      add
        /* "#utility.yul":13489:13508   */
      swap1
      pop
        /* "#utility.yul":13149:13514   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":13520:13939   */
    tag_84:
        /* "#utility.yul":13686:13690   */
      0x00
        /* "#utility.yul":13724:13726   */
      0x20
        /* "#utility.yul":13713:13722   */
      dup3
        /* "#utility.yul":13709:13727   */
      add
        /* "#utility.yul":13701:13727   */
      swap1
      pop
        /* "#utility.yul":13773:13782   */
      dup2
        /* "#utility.yul":13767:13771   */
      dup2
        /* "#utility.yul":13763:13783   */
      sub
        /* "#utility.yul":13759:13760   */
      0x00
        /* "#utility.yul":13748:13757   */
      dup4
        /* "#utility.yul":13744:13761   */
      add
        /* "#utility.yul":13737:13784   */
      mstore
        /* "#utility.yul":13801:13932   */
      tag_288
        /* "#utility.yul":13927:13931   */
      dup2
        /* "#utility.yul":13801:13932   */
      tag_150
      jump	// in
    tag_288:
        /* "#utility.yul":13793:13932   */
      swap1
      pop
        /* "#utility.yul":13520:13939   */
      swap2
      swap1
      pop
      jump	// out
        /* "#utility.yul":13945:14063   */
    tag_151:
        /* "#utility.yul":14032:14056   */
      tag_290
        /* "#utility.yul":14050:14055   */
      dup2
        /* "#utility.yul":14032:14056   */
      tag_120
      jump	// in
    tag_290:
        /* "#utility.yul":14027:14030   */
      dup3
        /* "#utility.yul":14020:14057   */
      mstore
        /* "#utility.yul":13945:14063   */
      pop
      pop
      jump	// out
        /* "#utility.yul":14069:14291   */
    tag_99:
        /* "#utility.yul":14162:14166   */
      0x00
        /* "#utility.yul":14200:14202   */
      0x20
        /* "#utility.yul":14189:14198   */
      dup3
        /* "#utility.yul":14185:14203   */
      add
        /* "#utility.yul":14177:14203   */
      swap1
      pop
        /* "#utility.yul":14213:14284   */
      tag_292
        /* "#utility.yul":14281:14282   */
      0x00
        /* "#utility.yul":14270:14279   */
      dup4
        /* "#utility.yul":14266:14283   */
      add
        /* "#utility.yul":14257:14263   */
      dup5
        /* "#utility.yul":14213:14284   */
      tag_151
      jump	// in
    tag_292:
        /* "#utility.yul":14069:14291   */
      swap3
      swap2
      pop
      pop
      jump	// out

    auxdata: 0xa2646970667358221220d6625ff430278afd143a5e2eadf22cc58e81b20f9a07a01a7643006081a86a7064736f6c63430008230033
}

