-- test_basic.asm
-- Basic ANEM16 processor test program
-- Tests: R-type ALU ops, load immediate, memory ops
-- Results are stored to data memory for verification
--
-- This test relies on:
-- - ALU->ALU forwarding for back-to-back ALU operations
-- - Hazard unit SW stall detection for store-data dependencies
-- - 3 NOPs after LIL only (no LIL/LIU forwarding yet -- Phase 3)
--
-- Memory map for test results:
--   addr 0: R-type ADD result (expected: 0x0007 = 3+4)
--   addr 1: R-type SUB result (expected: 0x0001 = 4-3)
--   addr 2: R-type AND result (expected: 0x0003 = 0x07 & 0x03)
--   addr 3: R-type OR  result (expected: 0x0007 = 0x03 | 0x07)
--   addr 4: R-type XOR result (expected: 0x0004 = 0x07 ^ 0x03)
--   addr 5: R-type NOR result (expected: 0xFFF8 = ~(0x07 | 0x00))
--   addr 6: LIW result (expected: 0xABCD)
--   addr 7: SHL result (expected: 0x000E = 0x0007 << 1)
--   addr 8: SHR result (expected: 0x0003 = 0x0007 >> 1)

-- Setup: load test values into registers
-- R1 = 3, R2 = 4, R3 = 7
-- Need 3 NOPs after last LIL before registers are used
LIL $1, 3
LIL $2, 4
LIL $3, 7
NOP
NOP
NOP

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

-- End: infinite loop
HALT: J %HALT%
NOP
