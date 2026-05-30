/**
 * VansonLoader L2.3 - Lightweight ARM64 Disassembler
 * 覆盖常见 AArch64 指令: 分支/加载/存储/算术/NOP/RET
 * 用于断点触发后的反汇编视图
 */

#ifndef VLDisasm_hpp
#define VLDisasm_hpp

#include <cstdint>
#include <string>
#include <vector>

namespace vcore {

struct DisasmLine {
    uint64_t address;       // 运行时地址
    uint64_t offset;        // 相对模块基址的偏移
    uint32_t opcode;        // 原始 4 字节指令
    std::string hexStr;     // "C0035FD6"
    std::string mnemonic;   // "RET" / "STR X0, [X1, #0x10]"
    bool isPC;              // 是否为当前 PC 指令
};

// 反汇编指定地址附近的指令
// addr: 中心地址 (PC), countBefore/After: 前后各多少条
// imageBase: 模块基址 (用于计算 offset)
std::vector<DisasmLine> disassemble(uint64_t addr, uint32_t countBefore,
                                     uint32_t countAfter, uint64_t imageBase);

// 反汇编单条指令
std::string disasmOne(uint32_t insn, uint64_t pc);

// 反汇编整个函数 (从 PC 向前扫描 prologue，向后扫描 epilogue)
// 上限 MAX_SCAN=256 条扫描，总指令数上限 1024
std::vector<DisasmLine> disassembleFunction(uint64_t pc, uint64_t imageBase);

} // namespace vcore

#endif /* VLDisasm_hpp */
