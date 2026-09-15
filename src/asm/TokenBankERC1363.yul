/// @use-src 1:"lib/openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol", 2:"lib/openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol", 9:"lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol", 10:"lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol", 11:"src/TokenBankERC1363.sol", 12:"src/TokenBankV2.sol"
object "TokenBankERC1363_939" {
    code {
        {
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            mstore(64, memoryguard(0xa0))
            if callvalue()
            {
                revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
            }
            let _1 := copy_arguments_for_constructor_object_TokenBankERC1363()
            constructor_TokenBankERC1363(_1)
            let _2 := allocate_unbounded()
            codecopy(_2, dataoffset("TokenBankERC1363_939_deployed"), datasize("TokenBankERC1363_939_deployed"))
            setimmutable(_2, "954", mload(128))
            return(_2, datasize("TokenBankERC1363_939_deployed"))
        }
        function allocate_unbounded() -> memPtr
        { memPtr := mload(64) }
        function revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
        { revert(0, 0) }
        function round_up_to_mul_of(value) -> result
        {
            result := and(add(value, 31), not(31))
        }
        function panic_error_0x41()
        {
            mstore(0, shl(224, 0x4e487b71))
            mstore(4, 0x41)
            revert(0, 0x24)
        }
        function finalize_allocation(memPtr, size)
        {
            let newFreePtr := add(memPtr, round_up_to_mul_of(size))
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr)) { panic_error_0x41() }
            mstore(64, newFreePtr)
        }
        function allocate_memory(size) -> memPtr
        {
            memPtr := allocate_unbounded()
            finalize_allocation(memPtr, size)
        }
        function revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
        { revert(0, 0) }
        function cleanup_uint160(value) -> cleaned
        {
            cleaned := and(value, sub(shl(160, 1), 1))
        }
        function cleanup_address(value) -> cleaned
        {
            cleaned := cleanup_uint160(value)
        }
        function cleanup_contract_IERC20(value) -> cleaned
        {
            cleaned := cleanup_address(value)
        }
        function validator_revert_contract_IERC20(value)
        {
            if iszero(eq(value, cleanup_contract_IERC20(value))) { revert(0, 0) }
        }
        function abi_decode_contract_IERC20_fromMemory(offset, end) -> value
        {
            value := mload(offset)
            validator_revert_contract_IERC20(value)
        }
        function abi_decode_tuple_contract_IERC20_fromMemory(headStart, dataEnd) -> value0
        {
            if slt(sub(dataEnd, headStart), 32)
            {
                revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
            }
            let offset := 0
            value0 := abi_decode_contract_IERC20_fromMemory(add(headStart, offset), dataEnd)
        }
        function copy_arguments_for_constructor_object_TokenBankERC1363() -> ret_param
        {
            let programSize := datasize("TokenBankERC1363_939")
            let argSize := sub(codesize(), programSize)
            let memoryDataOffset := allocate_memory(argSize)
            codecopy(memoryDataOffset, programSize, argSize)
            ret_param := abi_decode_tuple_contract_IERC20_fromMemory(memoryDataOffset, add(memoryDataOffset, argSize))
        }
        /// @ast-id 782 @src 11:1259:1308  "constructor(IERC20 token_) TokenBankV2(token_) {}"
        function constructor_TokenBankERC1363(var_token__address)
        {
            /// @src 11:1298:1304  "token_"
            let _3_address := var_token__address
            let expr_778_address := _3_address
            let _4_address := expr_778_address
            /// @src 11:1259:1308  "constructor(IERC20 token_) TokenBankV2(token_) {}"
            constructor_IERC1363Spender(_4_address)
        }
        /// @src 2:282:1118  "interface IERC1363Spender {..."
        function constructor_IERC1363Spender(_address)
        {
            constructor_IERC1363Receiver(_address)
        }
        /// @src 1:310:1315  "interface IERC1363Receiver {..."
        function constructor_IERC1363Receiver(_address)
        { constructor_ERC165(_address) }
        /// @src 9:660:878  "abstract contract ERC165 is IERC165 {..."
        function constructor_ERC165(_address)
        { constructor_IERC165(_address) }
        /// @src 10:423:870  "interface IERC165 {..."
        function constructor_IERC165(_address)
        {
            constructor_TokenBankV2(_address)
        }
        /// @ast-id 982 @src 12:812:870  "constructor(IERC20 token_) {..."
        function constructor_TokenBankV2(var_token_address)
        {
            /// @src 12:857:863  "token_"
            let _5_address := var_token_address
            let expr_address := _5_address
            /// @src 12:849:863  "token = token_"
            let _6_address := expr_address
            mstore(128, _6_address)
        }
    }
    /// @use-src 8:"lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol", 9:"lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol", 11:"src/TokenBankERC1363.sol", 12:"src/TokenBankV2.sol"
    object "TokenBankERC1363_939_deployed" {
        code {
            {
                /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
                mstore(64, memoryguard(0x80))
                if iszero(lt(calldatasize(), 4))
                {
                    let selector := shift_right_unsigned(calldataload(0))
                    switch selector
                    case 0x01ffc9a7 {
                        external_fun_supportsInterface()
                    }
                    case 0x27e235e3 { external_fun_balances() }
                    case 0x2e1a7d4d { external_fun_withdraw() }
                    case 0x7b04a2d0 {
                        external_fun_onApprovalReceived()
                    }
                    case 0x88a7ca5c {
                        external_fun_onTransferReceived()
                    }
                    case 0xb6b55f25 { external_fun_deposit() }
                    case 0xfc0c546a { external_fun_token() }
                    default { }
                }
                revert_error_42b3090547df1d2001c96683413b8cf91c1b902ef5e3cb8d9f6f304cf7446f74()
            }
            function shift_right_unsigned(value) -> newValue
            { newValue := shr(224, value) }
            function allocate_unbounded() -> memPtr
            { memPtr := mload(64) }
            function revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
            { revert(0, 0) }
            function revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
            { revert(0, 0) }
            function revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db()
            { revert(0, 0) }
            function cleanup_bytes4(value) -> cleaned
            {
                cleaned := and(value, shl(224, 0xffffffff))
            }
            function validator_revert_bytes4(value)
            {
                if iszero(eq(value, cleanup_bytes4(value))) { revert(0, 0) }
            }
            function abi_decode_t_bytes4(offset, end) -> value
            {
                value := calldataload(offset)
                validator_revert_bytes4(value)
            }
            function abi_decode_bytes4(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
                let offset := 0
                value0 := abi_decode_t_bytes4(add(headStart, offset), dataEnd)
            }
            function cleanup_bool(value) -> cleaned
            {
                cleaned := iszero(iszero(value))
            }
            function abi_encode_bool_to_bool(value, pos)
            {
                mstore(pos, cleanup_bool(value))
            }
            function abi_encode_bool(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                abi_encode_bool_to_bool(value0, add(headStart, 0))
            }
            function external_fun_supportsInterface()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param := abi_decode_bytes4(4, calldatasize())
                let ret := fun_supportsInterface_811(param)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_bool(memPos, ret)
                return(memPos, sub(memEnd, memPos))
            }
            function cleanup_uint160(value) -> cleaned
            {
                cleaned := and(value, sub(shl(160, 1), 1))
            }
            function cleanup_address(value) -> cleaned
            {
                cleaned := cleanup_uint160(value)
            }
            function validator_revert_address(value)
            {
                if iszero(eq(value, cleanup_address(value))) { revert(0, 0) }
            }
            function abi_decode_address(offset, end) -> value
            {
                value := calldataload(offset)
                validator_revert_address(value)
            }
            function abi_decode_tuple_address(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
                let offset := 0
                value0 := abi_decode_address(add(headStart, offset), dataEnd)
            }
            function identity(value) -> ret
            { ret := value }
            function convert_uint160_to_uint160(value) -> converted
            {
                converted := cleanup_uint160(identity(cleanup_uint160(value)))
            }
            function convert_uint160_to_address(value) -> converted
            {
                converted := convert_uint160_to_uint160(value)
            }
            function convert_address_to_address(value) -> converted
            {
                converted := convert_uint160_to_address(value)
            }
            function mapping_index_access_mapping_address_uint256_of_address(slot, key) -> dataSlot
            {
                mstore(0, convert_address_to_address(key))
                mstore(0x20, slot)
                dataSlot := keccak256(0, 0x40)
            }
            function shift_right_unsigned_dynamic(bits, value) -> newValue
            { newValue := shr(bits, value) }
            function cleanup_from_storage_uint256(value) -> cleaned
            { cleaned := value }
            function extract_from_storage_value_dynamict_uint256(slot_value, offset) -> value
            {
                value := cleanup_from_storage_uint256(shift_right_unsigned_dynamic(mul(offset, 8), slot_value))
            }
            function read_from_storage_split_dynamic_uint256(slot, offset) -> value
            {
                value := extract_from_storage_value_dynamict_uint256(sload(slot), offset)
            }
            /// @ast-id 959 @src 12:646:689  "mapping(address => uint256) public balances"
            function getter_fun_balances(key) -> ret
            {
                let slot := 0
                let offset := 0
                slot := mapping_index_access_mapping_address_uint256_of_address(slot, key)
                ret := read_from_storage_split_dynamic_uint256(slot, offset)
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function cleanup_uint256(value) -> cleaned
            { cleaned := value }
            function abi_encode_uint256_to_uint256(value, pos)
            {
                mstore(pos, cleanup_uint256(value))
            }
            function abi_encode_uint256(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                abi_encode_uint256_to_uint256(value0, add(headStart, 0))
            }
            function external_fun_balances()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param := abi_decode_tuple_address(4, calldatasize())
                let ret := getter_fun_balances(param)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_uint256(memPos, ret)
                return(memPos, sub(memEnd, memPos))
            }
            function validator_revert_uint256(value)
            {
                if iszero(eq(value, cleanup_uint256(value))) { revert(0, 0) }
            }
            function abi_decode_uint256(offset, end) -> value
            {
                value := calldataload(offset)
                validator_revert_uint256(value)
            }
            function abi_decode_tuple_uint256(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
                let offset := 0
                value0 := abi_decode_uint256(add(headStart, offset), dataEnd)
            }
            function abi_encode_tuple(headStart) -> tail
            { tail := add(headStart, 0) }
            function external_fun_withdraw()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param := abi_decode_tuple_uint256(4, calldatasize())
                fun_withdraw(param)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_tuple(memPos)
                return(memPos, sub(memEnd, memPos))
            }
            function revert_error_1b9f4a0a5773e33b91aa01db23bf8c55fce1411167c872835e7fa00a4f17d46d()
            { revert(0, 0) }
            function revert_error_15abf5612cd996bc235ba1e55a4a30ac60e6bb601ff7ba4ad3f179b6be8d0490()
            { revert(0, 0) }
            function revert_error_81385d8c0b31fffe14be1da910c8bd3a80be4cfa248e04f42ec0faea3132a8ef()
            { revert(0, 0) }
            function abi_decode_bytes_calldata(offset, end) -> arrayPos, length
            {
                if iszero(slt(add(offset, 0x1f), end))
                {
                    revert_error_1b9f4a0a5773e33b91aa01db23bf8c55fce1411167c872835e7fa00a4f17d46d()
                }
                length := calldataload(offset)
                if gt(length, 0xffffffffffffffff)
                {
                    revert_error_15abf5612cd996bc235ba1e55a4a30ac60e6bb601ff7ba4ad3f179b6be8d0490()
                }
                arrayPos := add(offset, 0x20)
                if gt(add(arrayPos, mul(length, 0x01)), end)
                {
                    revert_error_81385d8c0b31fffe14be1da910c8bd3a80be4cfa248e04f42ec0faea3132a8ef()
                }
            }
            function abi_decode_addresst_uint256t_bytes_calldata(headStart, dataEnd) -> value0, value1, value2, value3
            {
                if slt(sub(dataEnd, headStart), 96)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
                let offset := 0
                value0 := abi_decode_address(add(headStart, offset), dataEnd)
                let offset_1 := 32
                value1 := abi_decode_uint256(add(headStart, offset_1), dataEnd)
                let offset_2 := calldataload(add(headStart, 64))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db()
                }
                value2, value3 := abi_decode_bytes_calldata(add(headStart, offset_2), dataEnd)
            }
            function abi_encode_bytes4(value, pos)
            {
                mstore(pos, cleanup_bytes4(value))
            }
            function abi_encode_tuple_bytes4(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                abi_encode_bytes4(value0, add(headStart, 0))
            }
            function external_fun_onApprovalReceived()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param, param_1, param_2, param_3 := abi_decode_addresst_uint256t_bytes_calldata(4, calldatasize())
                let ret := fun_onApprovalReceived(param, param_1, param_2, param_3)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_tuple_bytes4(memPos, ret)
                return(memPos, sub(memEnd, memPos))
            }
            function abi_decode_addresst_addresst_uint256t_bytes_calldata(headStart, dataEnd) -> value0, value1, value2, value3, value4
            {
                if slt(sub(dataEnd, headStart), 128)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
                let offset := 0
                value0 := abi_decode_address(add(headStart, offset), dataEnd)
                let offset_1 := 32
                value1 := abi_decode_address(add(headStart, offset_1), dataEnd)
                let offset_2 := 64
                value2 := abi_decode_uint256(add(headStart, offset_2), dataEnd)
                let offset_3 := calldataload(add(headStart, 96))
                if gt(offset_3, 0xffffffffffffffff)
                {
                    revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db()
                }
                value3, value4 := abi_decode_bytes_calldata(add(headStart, offset_3), dataEnd)
            }
            function external_fun_onTransferReceived()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param, param_1, param_2, param_3, param_4 := abi_decode_addresst_addresst_uint256t_bytes_calldata(4, calldatasize())
                let ret := fun_onTransferReceived(param, param_1, param_2, param_3, param_4)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_tuple_bytes4(memPos, ret)
                return(memPos, sub(memEnd, memPos))
            }
            function external_fun_deposit()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                let param := abi_decode_tuple_uint256(4, calldatasize())
                fun_deposit(param)
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_tuple(memPos)
                return(memPos, sub(memEnd, memPos))
            }
            function abi_decode(headStart, dataEnd)
            {
                if slt(sub(dataEnd, headStart), 0)
                {
                    revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b()
                }
            }
            /// @ast-id 954 @src 12:553:582  "IERC20 public immutable token"
            function getter_fun_token() -> rval
            { rval := loadimmutable("954") }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function convert_contract_IERC20_to_address(value) -> converted
            {
                converted := convert_uint160_to_address(value)
            }
            function abi_encode_contract_IERC20_to_address(value, pos)
            {
                mstore(pos, convert_contract_IERC20_to_address(value))
            }
            function abi_encode_contract_IERC20(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                abi_encode_contract_IERC20_to_address(value0, add(headStart, 0))
            }
            function external_fun_token()
            {
                if callvalue()
                {
                    revert_error_ca66f745a3ce8ff40e2ccaf1ad45db7774001b90d25810abd9040049be7bf4bb()
                }
                abi_decode(4, calldatasize())
                let ret := getter_fun_token()
                let memPos := allocate_unbounded()
                let memEnd := abi_encode_contract_IERC20(memPos, ret)
                return(memPos, sub(memEnd, memPos))
            }
            function revert_error_42b3090547df1d2001c96683413b8cf91c1b902ef5e3cb8d9f6f304cf7446f74()
            { revert(0, 0) }
            function zero_value_for_split_bool() -> ret
            { ret := 0 }
            /// @ast-id 811 @src 11:1342:1610  "function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {..."
            function fun_supportsInterface_811(var_interfaceId) -> var
            {
                /// @src 11:1427:1431  "bool"
                let zero_bool := zero_value_for_split_bool()
                var := zero_bool
                /// @src 11:1450:1461  "interfaceId"
                let _1 := var_interfaceId
                let expr := _1
                /// @src 11:1465:1499  "type(IERC1363Receiver).interfaceId"
                let expr_1 := shl(226, 0x2229f297)
                /// @src 11:1450:1499  "interfaceId == type(IERC1363Receiver).interfaceId"
                let expr_2 := eq(cleanup_bytes4(expr), cleanup_bytes4(expr_1))
                /// @src 11:1450:1551  "interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId"
                let expr_3 := expr_2
                if iszero(expr_3)
                {
                    /// @src 11:1503:1514  "interfaceId"
                    let _2 := var_interfaceId
                    let expr_4 := _2
                    /// @src 11:1518:1551  "type(IERC1363Spender).interfaceId"
                    let expr_5 := shl(228, 0x07b04a2d)
                    /// @src 11:1503:1551  "interfaceId == type(IERC1363Spender).interfaceId"
                    let expr_6 := eq(cleanup_bytes4(expr_4), cleanup_bytes4(expr_5))
                    /// @src 11:1450:1551  "interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId"
                    expr_3 := expr_6
                }
                /// @src 11:1450:1603  "interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId..."
                let expr_7 := expr_3
                if iszero(expr_7)
                {
                    /// @src 11:1591:1602  "interfaceId"
                    let _3 := var_interfaceId
                    let expr_8 := _3
                    /// @src 11:1567:1603  "super.supportsInterface(interfaceId)"
                    let expr_9 := fun_supportsInterface(expr_8)
                    /// @src 11:1450:1603  "interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId..."
                    expr_7 := expr_9
                }
                /// @src 11:1443:1603  "return interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId..."
                var := expr_7
                leave
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function cleanup_rational_by(value) -> cleaned
            { cleaned := value }
            function convert_rational_by_to_uint256(value) -> converted
            {
                converted := cleanup_uint256(identity(cleanup_rational_by(value)))
            }
            function array_storeLengthForEncoding_string(pos, length) -> updated_pos
            {
                mstore(pos, length)
                updated_pos := add(pos, 0x20)
            }
            function store_literal_in_memory_02237bec9a023334e780f904ff454aa14fb9bf5366550c2b20964e00ebfe6bef(memPtr)
            {
                mstore(add(memPtr, 0), "Zero withdraw")
            }
            function abi_encode_stringliteral_0223(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 13)
                store_literal_in_memory_02237bec9a023334e780f904ff454aa14fb9bf5366550c2b20964e00ebfe6bef(pos)
                end := add(pos, 32)
            }
            function abi_encode_tuple_stringliteral_0223(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_0223(tail)
            }
            function require_helper_stringliteral_0223(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_tuple_stringliteral_0223(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            function shift_right_0_unsigned(value) -> newValue
            { newValue := shr(0, value) }
            function extract_from_storage_value_offset_uint256(slot_value) -> value
            {
                value := cleanup_from_storage_uint256(shift_right_0_unsigned(slot_value))
            }
            function read_from_storage_split_offset_uint256(slot) -> value
            {
                value := extract_from_storage_value_offset_uint256(sload(slot))
            }
            function store_literal_in_memory_47533c3652efd02135ecc34b3fac8efc7b14bf0618b9392fd6e044a3d8a6eef5(memPtr)
            {
                mstore(add(memPtr, 0), "Insufficient balance")
            }
            function abi_encode_stringliteral_4753(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 20)
                store_literal_in_memory_47533c3652efd02135ecc34b3fac8efc7b14bf0618b9392fd6e044a3d8a6eef5(pos)
                end := add(pos, 32)
            }
            function abi_encode_tuple_stringliteral_4753(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_4753(tail)
            }
            function require_helper_stringliteral_4753(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_tuple_stringliteral_4753(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            function panic_error_0x11()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x11)
                revert(0, 0x24)
            }
            function checked_sub_uint256(x, y) -> diff
            {
                x := cleanup_uint256(x)
                y := cleanup_uint256(y)
                diff := sub(x, y)
                if gt(diff, x) { panic_error_0x11() }
            }
            function shift_left(value) -> newValue
            { newValue := shl(0, value) }
            function update_byte_slice_shift(value, toInsert) -> result
            {
                let mask := not(0)
                toInsert := shift_left(toInsert)
                value := and(value, not(mask))
                result := or(value, and(toInsert, mask))
            }
            function convert_uint256_to_uint256(value) -> converted
            {
                converted := cleanup_uint256(identity(cleanup_uint256(value)))
            }
            function prepare_store_uint256(value) -> ret
            { ret := value }
            function update_storage_value_offset_uint256_to_uint256(slot, value)
            {
                let convertedValue := convert_uint256_to_uint256(value)
                sstore(slot, update_byte_slice_shift(sload(slot), prepare_store_uint256(convertedValue)))
            }
            /// @ast-id 1066 @src 12:1255:1598  "function withdraw(uint256 amount) external {..."
            function fun_withdraw(var_amount)
            {
                /// @src 12:1316:1322  "amount"
                let _1 := var_amount
                let expr := _1
                /// @src 12:1325:1326  "0"
                let expr_1 := 0x00
                /// @src 12:1316:1326  "amount > 0"
                let expr_2 := gt(cleanup_uint256(expr), convert_rational_by_to_uint256(expr_1))
                /// @src 12:1308:1344  "require(amount > 0, \"Zero withdraw\")"
                require_helper_stringliteral_0223(expr_2)
                /// @src 12:1362:1370  "balances"
                let _6_slot := 0x00
                let expr_1035_slot := _6_slot
                /// @src 12:1371:1381  "msg.sender"
                let expr_3 := caller()
                /// @src 12:1362:1382  "balances[msg.sender]"
                let _2 := mapping_index_access_mapping_address_uint256_of_address(expr_1035_slot, expr_3)
                let _3 := read_from_storage_split_offset_uint256(_2)
                let expr_4 := _3
                /// @src 12:1386:1392  "amount"
                let _4 := var_amount
                let expr_5 := _4
                /// @src 12:1362:1392  "balances[msg.sender] >= amount"
                let expr_6 := iszero(lt(cleanup_uint256(expr_4), cleanup_uint256(expr_5)))
                /// @src 12:1354:1417  "require(balances[msg.sender] >= amount, \"Insufficient balance\")"
                require_helper_stringliteral_4753(expr_6)
                /// @src 12:1494:1500  "amount"
                let _5 := var_amount
                let expr_7 := _5
                /// @src 12:1470:1478  "balances"
                let _11_slot := 0x00
                let expr_slot := _11_slot
                /// @src 12:1479:1489  "msg.sender"
                let expr_8 := caller()
                /// @src 12:1470:1490  "balances[msg.sender]"
                let _6 := mapping_index_access_mapping_address_uint256_of_address(expr_slot, expr_8)
                /// @src 12:1470:1500  "balances[msg.sender] -= amount"
                let _7 := read_from_storage_split_offset_uint256(_6)
                let expr_9 := checked_sub_uint256(_7, expr_7)
                update_storage_value_offset_uint256_to_uint256(_6, expr_9)
                /// @src 12:1510:1515  "token"
                let _14_address := loadimmutable("954")
                let expr_address := _14_address
                /// @src 12:1510:1528  "token.safeTransfer"
                let expr_self_address := expr_address
                /// @src 12:1529:1539  "msg.sender"
                let expr_10 := caller()
                /// @src 12:1541:1547  "amount"
                let _8 := var_amount
                let expr_11 := _8
                fun_safeTransfer(expr_self_address, expr_10, expr_11)
                /// @src 12:1572:1582  "msg.sender"
                let expr_12 := caller()
                /// @src 12:1584:1590  "amount"
                let _9 := var_amount
                let expr_13 := _9
                /// @src 12:1563:1591  "Withdraw(msg.sender, amount)"
                let _10 := 0x884edad9ce6fa2440d8a54cc123490eb96d2768479d49ff9c7366125a9424364
                let _11 := convert_address_to_address(expr_12)
                let _12 := allocate_unbounded()
                let _13 := abi_encode_uint256(_12, expr_13)
                log2(_12, sub(_13, _12), _10, _11)
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function zero_value_for_split_bytes4() -> ret
            { ret := 0 }
            function store_literal_in_memory_5e70ebd1d4072d337a7fabaa7bda70fa2633d6e3f89d5cb725a16b10d07e54c6(memPtr)
            {
                mstore(add(memPtr, 0), "Invalid token")
            }
            function abi_encode_stringliteral_5e70(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 13)
                store_literal_in_memory_5e70ebd1d4072d337a7fabaa7bda70fa2633d6e3f89d5cb725a16b10d07e54c6(pos)
                end := add(pos, 32)
            }
            function abi_encode_tuple_stringliteral_5e70(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_5e70(tail)
            }
            function require_helper_stringliteral_5e70(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_tuple_stringliteral_5e70(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            function store_literal_in_memory_6d951e8ac07dde84a43735e497d67ee4c524b854e2264cceeaaa6d903de9357f(memPtr)
            {
                mstore(add(memPtr, 0), "Zero deposit")
            }
            function abi_encode_stringliteral_6d951e8ac07dde84a43735e497d67ee4c524b854e2264cceeaaa6d903de9357f(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 12)
                store_literal_in_memory_6d951e8ac07dde84a43735e497d67ee4c524b854e2264cceeaaa6d903de9357f(pos)
                end := add(pos, 32)
            }
            function abi_encode_stringliteral_6d95(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_6d951e8ac07dde84a43735e497d67ee4c524b854e2264cceeaaa6d903de9357f(tail)
            }
            function require_helper_stringliteral_6d95(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_stringliteral_6d95(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            function convert_rational_by_to_uint160(value) -> converted
            {
                converted := cleanup_uint160(identity(cleanup_rational_by(value)))
            }
            function convert_rational_by_to_address(value) -> converted
            {
                converted := convert_rational_by_to_uint160(value)
            }
            function store_literal_in_memory_ec7ba83a4b7e2321624811208ca948566da4f2cd5a468b49eafb62932d564411(memPtr)
            {
                mstore(add(memPtr, 0), "Zero owner")
            }
            function abi_encode_stringliteral_ec7ba83a4b7e2321624811208ca948566da4f2cd5a468b49eafb62932d564411(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 10)
                store_literal_in_memory_ec7ba83a4b7e2321624811208ca948566da4f2cd5a468b49eafb62932d564411(pos)
                end := add(pos, 32)
            }
            function abi_encode_stringliteral_ec7b(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_ec7ba83a4b7e2321624811208ca948566da4f2cd5a468b49eafb62932d564411(tail)
            }
            function require_helper_stringliteral_ec7b(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_stringliteral_ec7b(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            function convert_contract_TokenBankERC1363_to_address(value) -> converted
            {
                converted := convert_uint160_to_address(value)
            }
            function checked_add_uint256(x, y) -> sum
            {
                x := cleanup_uint256(x)
                y := cleanup_uint256(y)
                sum := add(x, y)
                if gt(x, sum) { panic_error_0x11() }
            }
            /// @ast-id 938 @src 11:2200:2820  "function onApprovalReceived(..."
            function fun_onApprovalReceived(var_owner, var_value, var_offset, var__length) -> var
            {
                /// @src 11:2366:2372  "bytes4"
                let zero_t_bytes4 := zero_value_for_split_bytes4()
                var := zero_t_bytes4
                /// @src 11:2396:2406  "msg.sender"
                let expr := caller()
                /// @src 11:2418:2423  "token"
                let _address := loadimmutable("954")
                let expr_888_address := _address
                /// @src 11:2410:2424  "address(token)"
                let expr_1 := convert_contract_IERC20_to_address(expr_888_address)
                /// @src 11:2396:2424  "msg.sender == address(token)"
                let expr_2 := eq(cleanup_address(expr), cleanup_address(expr_1))
                /// @src 11:2388:2442  "require(msg.sender == address(token), \"Invalid token\")"
                require_helper_stringliteral_5e70(expr_2)
                /// @src 11:2460:2465  "value"
                let _1 := var_value
                let expr_3 := _1
                /// @src 11:2468:2469  "0"
                let expr_4 := 0x00
                /// @src 11:2460:2469  "value > 0"
                let expr_5 := gt(cleanup_uint256(expr_3), convert_rational_by_to_uint256(expr_4))
                /// @src 11:2452:2486  "require(value > 0, \"Zero deposit\")"
                require_helper_stringliteral_6d95(expr_5)
                /// @src 11:2504:2509  "owner"
                let _2 := var_owner
                let expr_6 := _2
                /// @src 11:2521:2522  "0"
                let expr_7 := 0x00
                /// @src 11:2513:2523  "address(0)"
                let expr_8 := convert_rational_by_to_address(expr_7)
                /// @src 11:2504:2523  "owner != address(0)"
                let expr_9 := iszero(eq(cleanup_address(expr_6), cleanup_address(expr_8)))
                /// @src 11:2496:2538  "require(owner != address(0), \"Zero owner\")"
                require_helper_stringliteral_ec7b(expr_9)
                /// @src 11:2631:2636  "token"
                let _25_address := loadimmutable("954")
                let expr_911_address := _25_address
                /// @src 11:2631:2653  "token.safeTransferFrom"
                let expr_913_self_address := expr_911_address
                /// @src 11:2654:2659  "owner"
                let _3 := var_owner
                let expr_10 := _3
                /// @src 11:2669:2673  "this"
                let expr_917_address := address()
                /// @src 11:2661:2674  "address(this)"
                let expr_11 := convert_contract_TokenBankERC1363_to_address(expr_917_address)
                /// @src 11:2676:2681  "value"
                let _4 := var_value
                let expr_12 := _4
                fun_safeTransferFrom_313(expr_913_self_address, expr_10, expr_11, expr_12)
                /// @src 11:2711:2716  "value"
                let _5 := var_value
                let expr_13 := _5
                /// @src 11:2692:2700  "balances"
                let _29_slot := 0x00
                let expr_922_slot := _29_slot
                /// @src 11:2701:2706  "owner"
                let _6 := var_owner
                let expr_14 := _6
                /// @src 11:2692:2707  "balances[owner]"
                let _7 := mapping_index_access_mapping_address_uint256_of_address(expr_922_slot, expr_14)
                /// @src 11:2692:2716  "balances[owner] += value"
                let _8 := read_from_storage_split_offset_uint256(_7)
                let expr_15 := checked_add_uint256(_8, expr_13)
                update_storage_value_offset_uint256_to_uint256(_7, expr_15)
                /// @src 11:2739:2744  "owner"
                let _9 := var_owner
                let expr_16 := _9
                /// @src 11:2746:2751  "value"
                let _10 := var_value
                let expr_17 := _10
                /// @src 11:2731:2752  "Deposit(owner, value)"
                let _11 := 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
                let _12 := convert_address_to_address(expr_16)
                let _13 := allocate_unbounded()
                let _14 := abi_encode_uint256(_13, expr_17)
                log2(_13, sub(_14, _13), _11, _12)
                /// @src 11:2770:2813  "IERC1363Spender.onApprovalReceived.selector"
                let expr_18 := /** @src 11:1518:1551  "type(IERC1363Spender).interfaceId" */ shl(228, 0x07b04a2d)
                /// @src 11:2763:2813  "return IERC1363Spender.onApprovalReceived.selector"
                var := expr_18
                leave
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function store_literal_in_memory_533fe2fed92f41f9b42d3b650fb48b4e979b86791ed79eaa58a02ea5fc3ce1c0(memPtr)
            {
                mstore(add(memPtr, 0), "Zero from")
            }
            function abi_encode_stringliteral_533fe2fed92f41f9b42d3b650fb48b4e979b86791ed79eaa58a02ea5fc3ce1c0(pos) -> end
            {
                pos := array_storeLengthForEncoding_string(pos, 9)
                store_literal_in_memory_533fe2fed92f41f9b42d3b650fb48b4e979b86791ed79eaa58a02ea5fc3ce1c0(pos)
                end := add(pos, 32)
            }
            function abi_encode_stringliteral_533f(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(add(headStart, 0), sub(tail, headStart))
                tail := abi_encode_stringliteral_533fe2fed92f41f9b42d3b650fb48b4e979b86791ed79eaa58a02ea5fc3ce1c0(tail)
            }
            function require_helper_stringliteral_533f(condition)
            {
                if iszero(condition)
                {
                    let memPtr := allocate_unbounded()
                    mstore(memPtr, shl(229, 4594637))
                    let end := abi_encode_stringliteral_533f(add(memPtr, 4))
                    revert(memPtr, sub(end, memPtr))
                }
            }
            /// @ast-id 870 @src 11:1653:2158  "function onTransferReceived(..."
            function fun_onTransferReceived(var_, var_from, var_value, var__offset, var_length) -> var
            {
                /// @src 11:1850:1856  "bytes4"
                let zero_bytes4 := zero_value_for_split_bytes4()
                var := zero_bytes4
                /// @src 11:1880:1890  "msg.sender"
                let expr := caller()
                /// @src 11:1902:1907  "token"
                let _40_address := loadimmutable("954")
                let expr_831_address := _40_address
                /// @src 11:1894:1908  "address(token)"
                let expr_1 := convert_contract_IERC20_to_address(expr_831_address)
                /// @src 11:1880:1908  "msg.sender == address(token)"
                let expr_2 := eq(cleanup_address(expr), cleanup_address(expr_1))
                /// @src 11:1872:1926  "require(msg.sender == address(token), \"Invalid token\")"
                require_helper_stringliteral_5e70(expr_2)
                /// @src 11:1944:1949  "value"
                let _1 := var_value
                let expr_3 := _1
                /// @src 11:1952:1953  "0"
                let expr_4 := 0x00
                /// @src 11:1944:1953  "value > 0"
                let expr_5 := gt(cleanup_uint256(expr_3), convert_rational_by_to_uint256(expr_4))
                /// @src 11:1936:1970  "require(value > 0, \"Zero deposit\")"
                require_helper_stringliteral_6d95(expr_5)
                /// @src 11:1988:1992  "from"
                let _2 := var_from
                let expr_6 := _2
                /// @src 11:2004:2005  "0"
                let expr_7 := 0x00
                /// @src 11:1996:2006  "address(0)"
                let expr_8 := convert_rational_by_to_address(expr_7)
                /// @src 11:1988:2006  "from != address(0)"
                let expr_9 := iszero(eq(cleanup_address(expr_6), cleanup_address(expr_8)))
                /// @src 11:1980:2020  "require(from != address(0), \"Zero from\")"
                require_helper_stringliteral_533f(expr_9)
                /// @src 11:2049:2054  "value"
                let _3 := var_value
                let expr_10 := _3
                /// @src 11:2031:2039  "balances"
                let _slot := 0x00
                let expr_854_slot := _slot
                /// @src 11:2040:2044  "from"
                let _4 := var_from
                let expr_11 := _4
                /// @src 11:2031:2045  "balances[from]"
                let _5 := mapping_index_access_mapping_address_uint256_of_address(expr_854_slot, expr_11)
                /// @src 11:2031:2054  "balances[from] += value"
                let _6 := read_from_storage_split_offset_uint256(_5)
                let expr_12 := checked_add_uint256(_6, expr_10)
                update_storage_value_offset_uint256_to_uint256(_5, expr_12)
                /// @src 11:2077:2081  "from"
                let _7 := var_from
                let expr_13 := _7
                /// @src 11:2083:2088  "value"
                let _8 := var_value
                let expr_14 := _8
                /// @src 11:2069:2089  "Deposit(from, value)"
                let _9 := 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
                let _10 := convert_address_to_address(expr_13)
                let _11 := allocate_unbounded()
                let _12 := abi_encode_uint256(_11, expr_14)
                log2(_11, sub(_12, _11), _9, _10)
                /// @src 11:2107:2151  "IERC1363Receiver.onTransferReceived.selector"
                let expr_15 := /** @src 11:1465:1499  "type(IERC1363Receiver).interfaceId" */ shl(226, 0x2229f297)
                /// @src 11:2100:2151  "return IERC1363Receiver.onTransferReceived.selector"
                var := expr_15
                leave
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function convert_contract_TokenBankV2_to_address(value) -> converted
            {
                converted := convert_uint160_to_address(value)
            }
            /// @ast-id 1021 @src 12:939:1182  "function deposit(uint256 amount) external {..."
            function fun_deposit(var_amount)
            {
                /// @src 12:999:1005  "amount"
                let _1 := var_amount
                let expr := _1
                /// @src 12:1008:1009  "0"
                let expr_1 := 0x00
                /// @src 12:999:1009  "amount > 0"
                let expr_2 := gt(cleanup_uint256(expr), convert_rational_by_to_uint256(expr_1))
                /// @src 12:991:1026  "require(amount > 0, \"Zero deposit\")"
                require_helper_stringliteral_6d95(expr_2)
                /// @src 12:1036:1041  "token"
                let _55_address := loadimmutable("954")
                let expr_995_address := _55_address
                /// @src 12:1036:1058  "token.safeTransferFrom"
                let expr_997_self_address := expr_995_address
                /// @src 12:1059:1069  "msg.sender"
                let expr_3 := caller()
                /// @src 12:1079:1083  "this"
                let expr_1002_address := address()
                /// @src 12:1071:1084  "address(this)"
                let expr_4 := convert_contract_TokenBankV2_to_address(expr_1002_address)
                /// @src 12:1086:1092  "amount"
                let _2 := var_amount
                let expr_5 := _2
                fun_safeTransferFrom_313(expr_997_self_address, expr_3, expr_4, expr_5)
                /// @src 12:1127:1133  "amount"
                let _3 := var_amount
                let expr_6 := _3
                /// @src 12:1103:1111  "balances"
                let _58_slot := 0x00
                let expr_1007_slot := _58_slot
                /// @src 12:1112:1122  "msg.sender"
                let expr_7 := caller()
                /// @src 12:1103:1123  "balances[msg.sender]"
                let _4 := mapping_index_access_mapping_address_uint256_of_address(expr_1007_slot, expr_7)
                /// @src 12:1103:1133  "balances[msg.sender] += amount"
                let _5 := read_from_storage_split_offset_uint256(_4)
                let expr_8 := checked_add_uint256(_5, expr_6)
                update_storage_value_offset_uint256_to_uint256(_4, expr_8)
                /// @src 12:1156:1166  "msg.sender"
                let expr_9 := caller()
                /// @src 12:1168:1174  "amount"
                let _6 := var_amount
                let expr_10 := _6
                /// @src 12:1148:1175  "Deposit(msg.sender, amount)"
                let _7 := 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c
                let _8 := convert_address_to_address(expr_9)
                let _9 := allocate_unbounded()
                let _10 := abi_encode_uint256(_9, expr_10)
                log2(_9, sub(_10, _9), _7, _8)
            }
            /// @ast-id 730 @src 9:730:876  "function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {..."
            function fun_supportsInterface(var_interfaceId) -> var
            {
                /// @src 9:806:810  "bool"
                let zero_bool := zero_value_for_split_bool()
                var := zero_bool
                /// @src 9:829:840  "interfaceId"
                let _1 := var_interfaceId
                let expr := _1
                /// @src 9:844:869  "type(IERC165).interfaceId"
                let expr_1 := shl(224, 0x01ffc9a7)
                /// @src 9:829:869  "interfaceId == type(IERC165).interfaceId"
                let expr_2 := eq(cleanup_bytes4(expr), cleanup_bytes4(expr_1))
                /// @src 9:822:869  "return interfaceId == type(IERC165).interfaceId"
                var := expr_2
                leave
            }
            /// @src 11:1136:2822  "contract TokenBankERC1363 is TokenBankV2, ERC165, IERC1363Receiver, IERC1363Spender {..."
            function abi_encode_address(value, pos)
            {
                mstore(pos, cleanup_address(value))
            }
            function abi_encode_tuple_address(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                abi_encode_address(value0, add(headStart, 0))
            }
            /// @ast-id 282 @src 8:1290:1494  "function safeTransfer(IERC20 token, address to, uint256 value) internal {..."
            function fun_safeTransfer(var_token_258_address, var_to, var_value)
            {
                /// @src 8:1391:1396  "token"
                let _68_address := var_token_258_address
                let expr_266_address := _68_address
                /// @src 8:1398:1400  "to"
                let _1 := var_to
                let expr := _1
                /// @src 8:1402:1407  "value"
                let _2 := var_value
                let expr_1 := _2
                /// @src 8:1409:1413  "true"
                let expr_2 := 0x01
                /// @src 8:1377:1414  "_safeTransfer(token, to, value, true)"
                let expr_3 := fun__safeTransfer(expr_266_address, expr, expr_1, expr_2)
                /// @src 8:1376:1414  "!_safeTransfer(token, to, value, true)"
                let expr_4 := cleanup_bool(iszero(expr_3))
                /// @src 8:1372:1488  "if (!_safeTransfer(token, to, value, true)) {..."
                if expr_4
                {
                    /// @src 8:1470:1475  "token"
                    let _71_address := var_token_258_address
                    let expr_275_address := _71_address
                    /// @src 8:1462:1476  "address(token)"
                    let expr_5 := convert_contract_IERC20_to_address(expr_275_address)
                    /// @src 8:1437:1477  "SafeERC20FailedOperation(address(token))"
                    let _3 := 0
                    mstore(_3, shl(224, 0x5274afe7))
                    let _4 := abi_encode_tuple_address(add(_3, 4), expr_5)
                    revert(_3, sub(_4, _3))
                }
            }
            /// @ast-id 313 @src 8:1733:1965  "function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {..."
            function fun_safeTransferFrom_313(var_token_address, var_from, var_to, var_value)
            {
                /// @src 8:1856:1861  "token"
                let _74_address := var_token_address
                let expr_296_address := _74_address
                /// @src 8:1863:1867  "from"
                let _1 := var_from
                let expr := _1
                /// @src 8:1869:1871  "to"
                let _2 := var_to
                let expr_1 := _2
                /// @src 8:1873:1878  "value"
                let _3 := var_value
                let expr_2 := _3
                /// @src 8:1880:1884  "true"
                let expr_3 := 0x01
                /// @src 8:1838:1885  "_safeTransferFrom(token, from, to, value, true)"
                let expr_4 := fun_safeTransferFrom(expr_296_address, expr, expr_1, expr_2, expr_3)
                /// @src 8:1837:1885  "!_safeTransferFrom(token, from, to, value, true)"
                let expr_5 := cleanup_bool(iszero(expr_4))
                /// @src 8:1833:1959  "if (!_safeTransferFrom(token, from, to, value, true)) {..."
                if expr_5
                {
                    /// @src 8:1941:1946  "token"
                    let _78_address := var_token_address
                    let expr_306_address := _78_address
                    /// @src 8:1933:1947  "address(token)"
                    let expr_6 := convert_contract_IERC20_to_address(expr_306_address)
                    /// @src 8:1908:1948  "SafeERC20FailedOperation(address(token))"
                    let _4 := 0
                    mstore(_4, /** @src 8:1437:1477  "SafeERC20FailedOperation(address(token))" */ shl(224, 0x5274afe7))
                    /// @src 8:1908:1948  "SafeERC20FailedOperation(address(token))"
                    let _5 := abi_encode_tuple_address(add(_4, 4), expr_6)
                    revert(_4, sub(_5, _4))
                }
            }
            /// @ast-id 658 @src 8:9022:10266  "function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {..."
            function fun__safeTransfer(var_token_639_address, var_to, var_value, var_bubble) -> var_success
            {
                /// @src 8:9116:9128  "bool success"
                let zero_bool := zero_value_for_split_bool()
                var_success := zero_bool
                /// @src 8:9158:9182  "IERC20.transfer.selector"
                let expr := shl(224, 0xa9059cbb)
                /// @src 8:9140:9182  "bytes4 selector = IERC20.transfer.selector"
                let var_selector := expr
                /// @src 8:9193:10260  "assembly (\"memory-safe\") {..."
                let usr$fmp := mload(0x40)
                mstore(0x00, var_selector)
                mstore(0x04, and(var_to, shr(96, not(0))))
                mstore(0x24, var_value)
                var_success := call(gas(), var_token_639_address, 0, 0x00, 0x44, 0x00, 0x20)
                if iszero(and(var_success, eq(mload(0x00), 1)))
                {
                    if and(iszero(var_success), var_bubble)
                    {
                        returndatacopy(usr$fmp, 0x00, returndatasize())
                        revert(usr$fmp, returndatasize())
                    }
                    var_success := and(var_success, and(iszero(returndatasize()), gt(extcodesize(var_token_639_address), 0)))
                }
                mstore(0x40, usr$fmp)
            }
            /// @ast-id 683 @src 8:10814:12207  "function _safeTransferFrom(..."
            function fun_safeTransferFrom(var_token_662_address, var_from, var_to, var_value, var_bubble) -> var_success
            {
                /// @src 8:10972:10984  "bool success"
                let zero_t_bool := zero_value_for_split_bool()
                var_success := zero_t_bool
                /// @src 8:11014:11042  "IERC20.transferFrom.selector"
                let expr := shl(224, 0x23b872dd)
                /// @src 8:10996:11042  "bytes4 selector = IERC20.transferFrom.selector"
                let var_selector := expr
                /// @src 8:11053:12201  "assembly (\"memory-safe\") {..."
                let usr$fmp := mload(0x40)
                mstore(0x00, var_selector)
                mstore(0x04, and(var_from, shr(96, not(0))))
                mstore(0x24, and(var_to, shr(96, not(0))))
                mstore(0x44, var_value)
                var_success := call(gas(), var_token_662_address, 0, 0x00, 0x64, 0x00, 0x20)
                if iszero(and(var_success, eq(mload(0x00), 1)))
                {
                    if and(iszero(var_success), var_bubble)
                    {
                        returndatacopy(usr$fmp, 0x00, returndatasize())
                        revert(usr$fmp, returndatasize())
                    }
                    var_success := and(var_success, and(iszero(returndatasize()), gt(extcodesize(var_token_662_address), 0)))
                }
                mstore(0x40, usr$fmp)
                mstore(0x60, 0)
            }
        }
        data ".metadata" hex"a264697066735822122038ffc200d16b443dfa96cb83e98a1f2a298fc1d638b9f4ebc2b81d20ee31e68d64736f6c63430008230033"
    }
}

