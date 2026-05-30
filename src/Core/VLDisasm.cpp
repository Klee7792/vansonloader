/**
 * VansonLoader L2.3 - Lightweight ARM64 Disassembler
 * 不依赖 capstone，手动解码常见 AArch64 指令
 */

#include "VLDisasm.hpp"
#include "VLCore.hpp"
#include <cstdio>
#include <cstring>

namespace vcore {

// 寄存器名
static const char *xreg(uint32_t r, bool is64) {
    static const char *x[] = {
        "X0","X1","X2","X3","X4","X5","X6","X7",
        "X8","X9","X10","X11","X12","X13","X14","X15",
        "X16","X17","X18","X19","X20","X21","X22","X23",
        "X24","X25","X26","X27","X28","X29","X30","XZR"
    };
    static const char *w[] = {
        "W0","W1","W2","W3","W4","W5","W6","W7",
        "W8","W9","W10","W11","W12","W13","W14","W15",
        "W16","W17","W18","W19","W20","W21","W22","W23",
        "W24","W25","W26","W27","W28","W29","W30","WZR"
    };
    if (r > 31) r = 31;
    return is64 ? x[r] : w[r];
}

static const char *spreg(uint32_t r, bool is64) {
    if (r == 31) return is64 ? "SP" : "WSP";
    return xreg(r, is64);
}

// 符号扩展
static int64_t signExtend(uint64_t val, uint32_t bits) {
    uint64_t mask = 1ULL << (bits - 1);
    return (int64_t)((val ^ mask) - mask);
}

std::string disasmOne(uint32_t insn, uint64_t pc) {
    char buf[128];

    // NOP
    if (insn == 0xD503201F) return "NOP";
    
    // RET (variants)
    if ((insn & 0xFFFFFC1F) == 0xD65F0000) {
        uint32_t rn = (insn >> 5) & 0x1F;
        if (rn == 30) return "RET";
        snprintf(buf, sizeof(buf), "RET %s", xreg(rn, true));
        return buf;
    }
    
    // BR Xn
    if ((insn & 0xFFFFFC1F) == 0xD61F0000) {
        uint32_t rn = (insn >> 5) & 0x1F;
        snprintf(buf, sizeof(buf), "BR %s", xreg(rn, true));
        return buf;
    }
    
    // BLR Xn
    if ((insn & 0xFFFFFC1F) == 0xD63F0000) {
        uint32_t rn = (insn >> 5) & 0x1F;
        snprintf(buf, sizeof(buf), "BLR %s", xreg(rn, true));
        return buf;
    }
    
    // B imm26
    if ((insn & 0xFC000000) == 0x14000000) {
        int64_t off = signExtend(insn & 0x3FFFFFF, 26) * 4;
        snprintf(buf, sizeof(buf), "B 0x%llX", (unsigned long long)(pc + off));
        return buf;
    }
    
    // BL imm26
    if ((insn & 0xFC000000) == 0x94000000) {
        int64_t off = signExtend(insn & 0x3FFFFFF, 26) * 4;
        snprintf(buf, sizeof(buf), "BL 0x%llX", (unsigned long long)(pc + off));
        return buf;
    }
    
    // B.cond imm19
    if ((insn & 0xFF000010) == 0x54000000) {
        static const char *conds[] = {
            "EQ","NE","CS","CC","MI","PL","VS","VC",
            "HI","LS","GE","LT","GT","LE","AL","NV"
        };
        uint32_t cond = insn & 0xF;
        int64_t off = signExtend((insn >> 5) & 0x7FFFF, 19) * 4;
        snprintf(buf, sizeof(buf), "B.%s 0x%llX", conds[cond],
                 (unsigned long long)(pc + off));
        return buf;
    }
    
    // CBZ / CBNZ
    if ((insn & 0x7E000000) == 0x34000000) {
        bool is64 = (insn >> 31) & 1;
        bool isNZ = (insn >> 24) & 1;
        uint32_t rt = insn & 0x1F;
        int64_t off = signExtend((insn >> 5) & 0x7FFFF, 19) * 4;
        snprintf(buf, sizeof(buf), "%s %s, 0x%llX",
                 isNZ ? "CBNZ" : "CBZ", xreg(rt, is64),
                 (unsigned long long)(pc + off));
        return buf;
    }
    
    // TBZ / TBNZ
    if ((insn & 0x7E000000) == 0x36000000) {
        bool isNZ = (insn >> 24) & 1;
        uint32_t b5 = (insn >> 31) & 1;
        uint32_t b40 = (insn >> 19) & 0x1F;
        uint32_t bit = (b5 << 5) | b40;
        uint32_t rt = insn & 0x1F;
        int64_t off = signExtend((insn >> 5) & 0x3FFF, 14) * 4;
        snprintf(buf, sizeof(buf), "%s %s, #%u, 0x%llX",
                 isNZ ? "TBNZ" : "TBZ", xreg(rt, b5),
                 bit, (unsigned long long)(pc + off));
        return buf;
    }
    
    // SVC
    if ((insn & 0xFFE0001F) == 0xD4000001) {
        uint32_t imm = (insn >> 5) & 0xFFFF;
        snprintf(buf, sizeof(buf), "SVC #0x%X", imm);
        return buf;
    }
    
    // MOV (wide immediate) - MOVZ / MOVK / MOVN
    if ((insn & 0x1F800000) == 0x12800000) {
        bool is64 = (insn >> 31) & 1;
        uint32_t opc = (insn >> 29) & 0x3;
        uint32_t hw = (insn >> 21) & 0x3;
        uint32_t imm16 = (insn >> 5) & 0xFFFF;
        uint32_t rd = insn & 0x1F;
        const char *op = (opc == 0) ? "MOVN" : (opc == 2) ? "MOVZ" : "MOVK";
        if (hw == 0 && opc == 2) {
            snprintf(buf, sizeof(buf), "MOV %s, #0x%X", xreg(rd, is64), imm16);
        } else {
            snprintf(buf, sizeof(buf), "%s %s, #0x%X, LSL #%u",
                     op, xreg(rd, is64), imm16, hw * 16);
        }
        return buf;
    }

    // ADRP
    if ((insn & 0x9F000000) == 0x90000000) {
        uint32_t rd = insn & 0x1F;
        uint32_t immlo = (insn >> 29) & 0x3;
        uint32_t immhi = (insn >> 5) & 0x7FFFF;
        int64_t imm = signExtend(((uint64_t)immhi << 2) | immlo, 21) << 12;
        uint64_t target = (pc & ~0xFFFULL) + imm;
        snprintf(buf, sizeof(buf), "ADRP %s, 0x%llX", xreg(rd, true),
                 (unsigned long long)target);
        return buf;
    }
    
    // ADR
    if ((insn & 0x9F000000) == 0x10000000) {
        uint32_t rd = insn & 0x1F;
        uint32_t immlo = (insn >> 29) & 0x3;
        uint32_t immhi = (insn >> 5) & 0x7FFFF;
        int64_t imm = signExtend(((uint64_t)immhi << 2) | immlo, 21);
        snprintf(buf, sizeof(buf), "ADR %s, 0x%llX", xreg(rd, true),
                 (unsigned long long)(pc + imm));
        return buf;
    }
    
    // ADD/SUB immediate
    if ((insn & 0x1F000000) == 0x11000000) {
        bool is64 = (insn >> 31) & 1;
        bool isSub = (insn >> 30) & 1;
        bool setFlags = (insn >> 29) & 1;
        uint32_t sh = (insn >> 22) & 1;
        uint32_t imm12 = (insn >> 10) & 0xFFF;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rd = insn & 0x1F;
        const char *op;
        if (setFlags && isSub && rd == 31) op = "CMP";
        else if (setFlags && !isSub && rd == 31) op = "CMN";
        else op = isSub ? (setFlags ? "SUBS" : "SUB") : (setFlags ? "ADDS" : "ADD");
        
        if ((rd == 31 && setFlags) || (rn == 31 && !setFlags)) {
            // CMP/CMN or MOV SP
            if (setFlags) {
                snprintf(buf, sizeof(buf), "%s %s, #0x%X%s", op,
                         spreg(rn, is64), imm12, sh ? ", LSL #12" : "");
            } else {
                snprintf(buf, sizeof(buf), "%s %s, %s, #0x%X%s", op,
                         spreg(rd, is64), spreg(rn, is64), imm12,
                         sh ? ", LSL #12" : "");
            }
        } else {
            snprintf(buf, sizeof(buf), "%s %s, %s, #0x%X%s", op,
                     xreg(rd, is64), spreg(rn, is64), imm12,
                     sh ? ", LSL #12" : "");
        }
        return buf;
    }
    
    // LDR/STR (unsigned offset) - 基本加载/存储
    if ((insn & 0x3B200C00) == 0x39000000) {
        uint32_t size = (insn >> 30) & 0x3;
        bool isLoad = (insn >> 22) & 1;
        uint32_t imm12 = (insn >> 10) & 0xFFF;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rt = insn & 0x1F;
        uint32_t scale = size;
        uint64_t offset = (uint64_t)imm12 << scale;
        
        const char *op;
        if (isLoad) {
            switch (size) {
                case 0: op = "LDRB"; break;
                case 1: op = "LDRH"; break;
                case 2: op = "LDR"; break;
                case 3: op = "LDR"; break;
                default: op = "LDR"; break;
            }
        } else {
            switch (size) {
                case 0: op = "STRB"; break;
                case 1: op = "STRH"; break;
                case 2: op = "STR"; break;
                case 3: op = "STR"; break;
                default: op = "STR"; break;
            }
        }
        bool regIs64 = (size == 3);
        if (offset == 0) {
            snprintf(buf, sizeof(buf), "%s %s, [%s]", op,
                     xreg(rt, regIs64), spreg(rn, true));
        } else {
            snprintf(buf, sizeof(buf), "%s %s, [%s, #0x%llX]", op,
                     xreg(rt, regIs64), spreg(rn, true),
                     (unsigned long long)offset);
        }
        return buf;
    }
    
    // LDP/STP (signed offset)
    if ((insn & 0x3E000000) == 0x28000000 ||
        (insn & 0x3E000000) == 0x2C000000) {
        bool is64 = (insn >> 31) & 1;
        bool isLoad = (insn >> 22) & 1;
        int32_t imm7 = (int32_t)signExtend((insn >> 15) & 0x7F, 7);
        uint32_t rt2 = (insn >> 10) & 0x1F;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rt = insn & 0x1F;
        int32_t offset = imm7 * (is64 ? 8 : 4);
        const char *op = isLoad ? "LDP" : "STP";
        
        if (offset == 0) {
            snprintf(buf, sizeof(buf), "%s %s, %s, [%s]", op,
                     xreg(rt, is64), xreg(rt2, is64), spreg(rn, true));
        } else {
            snprintf(buf, sizeof(buf), "%s %s, %s, [%s, #%d]", op,
                     xreg(rt, is64), xreg(rt2, is64), spreg(rn, true), offset);
        }
        return buf;
    }

    // AND/ORR/EOR/ANDS (shifted register)
    if ((insn & 0x1F000000) == 0x0A000000) {
        bool is64 = (insn >> 31) & 1;
        uint32_t opc = (insn >> 29) & 0x3;
        bool N = (insn >> 21) & 1;
        uint32_t shift = (insn >> 22) & 0x3;
        uint32_t rm = (insn >> 16) & 0x1F;
        uint32_t imm6 = (insn >> 10) & 0x3F;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rd = insn & 0x1F;
        const char *op;
        if (opc == 0 && !N) op = "AND";
        else if (opc == 0 && N) op = "BIC";
        else if (opc == 1 && !N) op = "ORR";
        else if (opc == 1 && N) op = "ORN";
        else if (opc == 2 && !N) op = "EOR";
        else if (opc == 2 && N) op = "EON";
        else if (opc == 3 && !N) op = "ANDS";
        else op = "BICS";
        // MOV alias: ORR Rd, XZR, Rm
        if (opc == 1 && !N && rn == 31 && imm6 == 0) {
            snprintf(buf, sizeof(buf), "MOV %s, %s", xreg(rd, is64), xreg(rm, is64));
            return buf;
        }
        if (imm6 == 0) {
            snprintf(buf, sizeof(buf), "%s %s, %s, %s", op,
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64));
        } else {
            static const char *shifts[] = {"LSL","LSR","ASR","ROR"};
            snprintf(buf, sizeof(buf), "%s %s, %s, %s, %s #%u", op,
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64),
                     shifts[shift], imm6);
        }
        return buf;
    }

    // ADD/SUB (shifted register)
    if ((insn & 0x1F200000) == 0x0B000000) {
        bool is64 = (insn >> 31) & 1;
        bool isSub = (insn >> 30) & 1;
        bool setFlags = (insn >> 29) & 1;
        uint32_t shift = (insn >> 22) & 0x3;
        uint32_t rm = (insn >> 16) & 0x1F;
        uint32_t imm6 = (insn >> 10) & 0x3F;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rd = insn & 0x1F;
        const char *op;
        if (setFlags && isSub && rd == 31) op = "CMP";
        else if (setFlags && !isSub) op = "ADDS";
        else if (isSub && setFlags) op = "SUBS";
        else op = isSub ? "SUB" : "ADD";

        if (rd == 31 && setFlags) {
            // CMP
            if (imm6 == 0) {
                snprintf(buf, sizeof(buf), "%s %s, %s", op,
                         xreg(rn, is64), xreg(rm, is64));
            } else {
                static const char *shifts[] = {"LSL","LSR","ASR","?"};
                snprintf(buf, sizeof(buf), "%s %s, %s, %s #%u", op,
                         xreg(rn, is64), xreg(rm, is64), shifts[shift], imm6);
            }
        } else if (imm6 == 0) {
            snprintf(buf, sizeof(buf), "%s %s, %s, %s", op,
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64));
        } else {
            static const char *shifts[] = {"LSL","LSR","ASR","?"};
            snprintf(buf, sizeof(buf), "%s %s, %s, %s, %s #%u", op,
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64),
                     shifts[shift], imm6);
        }
        return buf;
    }

    // MRS / MSR
    if ((insn & 0xFFF00000) == 0xD5300000) {
        uint32_t rt = insn & 0x1F;
        snprintf(buf, sizeof(buf), "MRS %s, S%u_%u_C%u_C%u_%u", xreg(rt, true),
                 (insn >> 19) & 1, (insn >> 16) & 7,
                 (insn >> 12) & 0xF, (insn >> 8) & 0xF, (insn >> 5) & 7);
        return buf;
    }
    if ((insn & 0xFFF00000) == 0xD5100000) {
        uint32_t rt = insn & 0x1F;
        snprintf(buf, sizeof(buf), "MSR S%u_%u_C%u_C%u_%u, %s",
                 (insn >> 19) & 1, (insn >> 16) & 7,
                 (insn >> 12) & 0xF, (insn >> 8) & 0xF, (insn >> 5) & 7,
                 xreg(rt, true));
        return buf;
    }

    // CSEL / CSINC / CSINV / CSNEG
    if ((insn & 0x1FE00000) == 0x1A800000) {
        bool is64 = (insn >> 31) & 1;
        uint32_t op2 = (insn >> 10) & 1;
        uint32_t o2 = (insn >> 30) & 1;
        uint32_t rm = (insn >> 16) & 0x1F;
        uint32_t cond = (insn >> 12) & 0xF;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rd = insn & 0x1F;
        static const char *conds[] = {
            "EQ","NE","CS","CC","MI","PL","VS","VC",
            "HI","LS","GE","LT","GT","LE","AL","NV"
        };
        const char *op;
        if (!o2 && !op2) op = "CSEL";
        else if (!o2 && op2) op = "CSINC";
        else if (o2 && !op2) op = "CSINV";
        else op = "CSNEG";
        snprintf(buf, sizeof(buf), "%s %s, %s, %s, %s", op,
                 xreg(rd, is64), xreg(rn, is64), xreg(rm, is64), conds[cond]);
        return buf;
    }

    // MADD / MSUB (and MUL alias)
    if ((insn & 0x1FE08000) == 0x1B000000) {
        bool is64 = (insn >> 31) & 1;
        bool isSub = (insn >> 15) & 1;
        uint32_t rm = (insn >> 16) & 0x1F;
        uint32_t ra = (insn >> 10) & 0x1F;
        uint32_t rn = (insn >> 5) & 0x1F;
        uint32_t rd = insn & 0x1F;
        if (ra == 31 && !isSub) {
            snprintf(buf, sizeof(buf), "MUL %s, %s, %s",
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64));
        } else {
            snprintf(buf, sizeof(buf), "%s %s, %s, %s, %s",
                     isSub ? "MSUB" : "MADD",
                     xreg(rd, is64), xreg(rn, is64), xreg(rm, is64), xreg(ra, is64));
        }
        return buf;
    }

    // Fallback: unknown
    snprintf(buf, sizeof(buf), ".inst 0x%08X", insn);
    return buf;
}

// 反汇编地址附近的指令
std::vector<DisasmLine> disassemble(uint64_t addr, uint32_t countBefore,
                                     uint32_t countAfter, uint64_t imageBase) {
    std::vector<DisasmLine> lines;

    // ARM64 指令固定 4 字节对齐
    uint64_t startAddr = addr - (uint64_t)countBefore * 4;
    uint32_t totalCount = countBefore + 1 + countAfter;

    for (uint32_t i = 0; i < totalCount; i++) {
        uint64_t curAddr = startAddr + (uint64_t)i * 4;
        DisasmLine line{};
        line.address = curAddr;
        line.offset = (imageBase != 0) ? (curAddr - imageBase) : curAddr;
        line.isPC = (curAddr == addr);

        uint32_t opcode = 0;
        if (MemEngine::inst().readMem(curAddr, &opcode, 4)) {
            line.opcode = opcode;
            // Hex string (little-endian bytes as displayed)
            char hex[12];
            snprintf(hex, sizeof(hex), "%02X%02X%02X%02X",
                     opcode & 0xFF, (opcode >> 8) & 0xFF,
                     (opcode >> 16) & 0xFF, (opcode >> 24) & 0xFF);
            line.hexStr = hex;
            line.mnemonic = disasmOne(opcode, curAddr);
        } else {
            line.opcode = 0;
            line.hexStr = "????????";
            line.mnemonic = "???";
        }
        lines.push_back(line);
    }
    return lines;
}

// ── Prologue / Epilogue detection ──

static bool isARM64Prologue(uint32_t insn) {
    // STP X29, X30, [SP, #imm]! (pre-index)
    if ((insn & 0xFFE07FFF) == 0xA9807BFD) return true;
    if ((insn & 0xFFC07FFF) == 0xA9007BFD) return true;
    // SUB SP, SP, #imm — stack frame setup
    if ((insn & 0xFF0003FF) == 0xD10003FF) return true;
    // PACIBSP (pointer auth)
    if (insn == 0xD503237F) return true;
    return false;
}

static bool isARM64Epilogue(uint32_t insn) {
    // RET (any variant)
    if ((insn & 0xFFFFFC1F) == 0xD65F0000) return true;
    // RETAB / RETAA (pointer auth returns)
    if (insn == 0xD65F0FFF || insn == 0xD65F0BFF) return true;
    return false;
}

// 反汇编整个函数
std::vector<DisasmLine> disassembleFunction(uint64_t pc, uint64_t imageBase) {
    static const uint32_t MAX_SCAN = 256;
    static const uint32_t BULK_READ = 256;

    // --- Scan backward for prologue ---
    uint64_t funcStart = pc;
    {
        uint32_t scanned = 0;
        uint64_t scanAddr = pc;
        bool found = false;
        while (scanned < MAX_SCAN) {
            uint32_t chunk = std::min(BULK_READ, MAX_SCAN - scanned);
            uint64_t readStart = scanAddr - (uint64_t)chunk * 4;

            uint32_t buf[BULK_READ];
            bool ok = MemEngine::inst().readMem(readStart, buf, chunk * 4);
            if (!ok) break;

            for (int32_t i = (int32_t)chunk - 1; i >= 0; i--) {
                if (isARM64Prologue(buf[i])) {
                    funcStart = readStart + (uint64_t)i * 4;
                    found = true;
                    break;
                }
            }
            if (found) break;
            scanned += chunk;
            scanAddr = readStart;
        }
        if (!found) {
            funcStart = pc - std::min((uint64_t)64 * 4, pc);
        }
    }

    // --- Scan forward for epilogue ---
    uint64_t funcEnd = pc;
    {
        uint32_t scanned = 0;
        uint64_t scanAddr = pc;
        bool found = false;
        while (scanned < MAX_SCAN) {
            uint32_t chunk = std::min(BULK_READ, MAX_SCAN - scanned);

            uint32_t buf[BULK_READ];
            bool ok = MemEngine::inst().readMem(scanAddr, buf, chunk * 4);
            if (!ok) break;

            for (uint32_t i = 0; i < chunk; i++) {
                if (isARM64Epilogue(buf[i])) {
                    funcEnd = scanAddr + (uint64_t)i * 4;
                    found = true;
                    break;
                }
            }
            if (found) break;
            scanned += chunk;
            scanAddr += (uint64_t)chunk * 4;
        }
        if (!found) {
            funcEnd = pc + 64 * 4;
        }
    }

    // --- Bulk read & disassemble ---
    uint32_t totalInsns = (uint32_t)((funcEnd - funcStart) / 4) + 1;
    if (totalInsns > 1024) totalInsns = 1024;

    std::vector<DisasmLine> lines;
    lines.reserve(totalInsns);

    // Read all at once for performance
    std::vector<uint32_t> codeBuf(totalInsns);
    bool readOk = MemEngine::inst().readMem(funcStart, codeBuf.data(), totalInsns * 4);
    uint32_t readInsns = readOk ? totalInsns : 0;

    for (uint32_t i = 0; i < totalInsns; i++) {
        uint64_t curAddr = funcStart + (uint64_t)i * 4;
        DisasmLine line{};
        line.address = curAddr;
        line.offset = (imageBase != 0) ? (curAddr - imageBase) : curAddr;
        line.isPC = (curAddr == pc);

        if (i < readInsns) {
            line.opcode = codeBuf[i];
            char hex[12];
            snprintf(hex, sizeof(hex), "%02X%02X%02X%02X",
                     codeBuf[i] & 0xFF, (codeBuf[i] >> 8) & 0xFF,
                     (codeBuf[i] >> 16) & 0xFF, (codeBuf[i] >> 24) & 0xFF);
            line.hexStr = hex;
            line.mnemonic = disasmOne(codeBuf[i], curAddr);
        } else {
            line.opcode = 0;
            line.hexStr = "????????";
            line.mnemonic = "???";
        }
        lines.push_back(line);
    }
    return lines;
}

} // namespace vcore
