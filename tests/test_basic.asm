-- test_basic.asm
-- Basic ANEM16 processor test program
-- Tests: R-type ALU ops, load immediate, memory ops, LW forwarding, JAL/JR
-- Results are stored to data memory for verification
--
-- This test relies on:
-- - ALU->ALU forwarding for back-to-back ALU operations
-- - WB->ALU forwarding for LW data (Phase 3)
-- - Hazard unit SW stall for store-data dependencies
-- - Hazard unit NFW stall for LIL/LIU dependencies (Phase 3)
-- - 0 NOPs needed between LIL and dependent instructions
--
-- Memory map for test results:
--   addr 0:  R-type ADD result (expected: 0x0007 = 3+4)
--   addr 1:  R-type SUB result (expected: 0x0001 = 4-3)
--   addr 2:  R-type AND result (expected: 0x0003 = 0x07 & 0x03)
--   addr 3:  R-type OR  result (expected: 0x0007 = 0x03 | 0x07)
--   addr 4:  R-type XOR result (expected: 0x0004 = 0x07 ^ 0x03)
--   addr 5:  R-type NOR result (expected: 0xFFF8 = ~(0x07 | 0x00))
--   addr 6:  LIW result (expected: 0xABCD)
--   addr 7:  SHL result (expected: 0x000E = 0x0007 << 1)
--   addr 8:  SHR result (expected: 0x0003 = 0x0007 >> 1)
--   addr 9:  LW result  (expected: 0x0007 = value loaded from addr 0)
--   addr 10: SLT result (expected: 0x0001 = -8 < 3 signed)
--   addr 11: SGT result (expected: 0x0001 = 3 > -8 signed)
--   addr 12: JAL subroutine result (expected: 0x0042 = 66)
--   addr 13: JAL return address R15 (expected: address after delay slot)
--   addr 14: SAR result (expected: 0xFFFC = 0xFFF8 >>> 1)
--   addr 15: ROL result (expected: 0xFFF1 = 0xFFF8 ROL 1)
--   addr 16: ROR result (expected: 0x8003 = 0x0007 ROR 1)
--   addr 17: $0 immutability (expected: 0x0000)
--   addr 18: LW base+offset (expected: 0x8003 from addr 16)
--   addr 19: LIL stale byte (expected: 0xFF05 = LIU FF then LIL 05)
--   addr 20: MFHI result (expected: 0x002A = 42, from HI register)
--   addr 21: MFLO result (expected: 0x0063 = 99, from LO register)

-- Setup: load test values into registers
-- R1 = 3, R2 = 4, R3 = 7
-- NFW stall handles LIL dependencies (no NOPs needed)
LIL $1, 3
LIL $2, 4
LIL $3, 7

-- Test 1: ADD. R4 = R1 + R2 = 3 + 4 = 7
-- Back-to-back ALU ops rely on forwarding (ALU->ALU)
ADD $4, $1
ADD $4, $2
SW $4, 0($0)

-- Test 2: SUB. R5 = R2 - R1 = 4 - 3 = 1
AND $5, $0
OR $5, $2
SUB $5, $1
SW $5, 1($0)

-- Test 3: AND. R6 = R3 AND R1 = 7 & 3 = 3
AND $6, $0
OR $6, $3
AND $6, $1
SW $6, 2($0)

-- Test 4: OR. R7 = R1 OR R3 = 3 | 7 = 7
AND $7, $0
OR $7, $1
OR $7, $3
SW $7, 3($0)

-- Test 5: XOR. R8 = R3 XOR R1 = 7 ^ 3 = 4
AND $8, $0
OR $8, $3
XOR $8, $1
SW $8, 4($0)

-- Test 6: NOR. R9 = NOR(R3, R0) = ~(7 | 0) = 0xFFF8
AND $9, $0
OR $9, $3
NOR $9, $0
SW $9, 5($0)

-- Test 7: LIW. R10 = 0xABCD (SW stall handles LIU/LIL writeback)
LIW $10, 0xABCD
SW $10, 6($0)

-- Test 8: SHL. R11 = R3 << 1 = 7 << 1 = 14 = 0x000E
AND $11, $0
OR $11, $3
SHL $11, $1
SW $11, 7($0)

-- Test 9: SHR. R12 = R3 >> 1 = 7 >> 1 = 3
AND $12, $0
OR $12, $3
SHR $12, $1
SW $12, 8($0)

-- Test 10: LW. R13 = MEM[0] (should be 0x0007 from test 1)
-- LW followed immediately by dependent ADD — tests LW forwarding from WB
LW $13, 0($0)
ADD $13, $0
SW $13, 9($0)

-- Test 11: SLT (signed). R14 = (R9 < R1) = (-8 < 3) = 1
-- Unsigned would give 0 (0xFFF8 > 3), so this validates signed comparison
AND $14, $0
OR $14, $9
SLT $14, $1
SW $14, 10($0)

-- Test 12: SGT (signed). R14 = (R1 > R9) = (3 > -8) = 1
-- Unsigned would give 0 (3 < 0xFFF8), so this validates signed comparison
AND $14, $0
OR $14, $1
SGT $14, $9
SW $14, 11($0)

-- Test 15: SAR. R9 = 0xFFF8 >>> 1 = 0xFFFC (sign-extended right shift)
-- R9 already has 0xFFF8 from test 6 (NOR clobbered later by test 11, but
-- actually test 11 puts R9 through SLT, which doesn't write back to R9;
-- wait — test 11 uses R14, and R9 still has the NOR result)
-- Actually SAR reads R9 which was set to FFF8 by NOR in test 6.
-- But test 11 did OR $14,$9 / SLT $14,$1 — so R9 still = 0xFFF8.
SAR $9, $1
SW $9, 14($0)

-- Test 16: ROL. R9 = 0xFFF8 ROL 1 = 0xFFF1 (rotate left)
-- Reload R9 = 0xFFF8 = NOR(7|0) since SAR modified it
AND $9, $0
OR $9, $3
NOR $9, $0
ROL $9, $1
SW $9, 15($0)

-- Test 17: ROR. R6 = 0x0007 ROR 1 = 0x8003 (rotate right)
-- Use R5=16 as base for addresses >= 16
LIL $5, 16
AND $6, $0
OR $6, $3
ROR $6, $1
SW $6, 0($5)

-- Test 18: $0 immutability. Write to $0, read back, should be 0x0000
ADD $0, $3
SW $0, 1($5)

-- Test 19: LW base+offset. Load from addr 16 (where ROR result was stored)
-- R4 = MEM[R5 + 0] = MEM[16] = 0x8003
LW $4, 0($5)
ADD $4, $0
SW $4, 2($5)

-- Test 20: LIL stale byte. LIU sets upper byte, LIL sets lower byte
-- LIL does NOT clear upper byte (only writes lower 8 bits)
-- R8 = LIU 0xFF, then LIL 0x05 => upper byte stays 0xFF => 0xFF05
LIU $8, 255
LIL $8, 5
SW $8, 3($5)

-- Test 21: MFHI. Load HI=42 via LHI, then move to GPR
-- Test 22: MFLO. Load LO=99 via LLO, then move to GPR
-- LHI expands to LHH+LHL, LLO expands to LLH+LLL (M1 instructions)
-- 1 NOP needed after LLO for HI/LO register writeback timing
-- MFLO gets correct LO automatically because SW stall after MFHI provides delay
LIL $5, 20
LHI 42
LLO 99
NOP
MFHI $6
SW $6, 0($5)
MFLO $7
SW $7, 1($5)

-- Test 13: JAL/JR. Call subroutine, verify return and R15 value.
-- JAL saves PC+2 to R15 (skip JAL + delay slot). Subroutine stores
-- 66 (0x0042) to addr 12. After return, store R15 to addr 13 to verify
-- it equals the address of the instruction after the delay slot.
JAL %SUBR%
NOP
-- We return here. R15 should contain this instruction's address.
-- Store R15 to addr 13 for verification.
SW $15, 13($0)
J %HALT%
NOP

-- Subroutine: store 0x0042 to addr 12, then return
SUBR: LIL $14, 66
SW $14, 12($0)
JR $15
NOP

-- End: infinite loop
HALT: J %HALT%
NOP
