-- test_basic.asm
-- Basic ANEM16 processor test program
-- Tests: R-type ALU ops, load immediate, memory ops
-- Results are stored to data memory for verification
--
-- NOTE: 3 NOPs before each SW to ensure register writeback completes
-- (no store-data forwarding yet -- Phase 3)
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
LIL $1, 3
NOP
NOP
NOP
LIL $2, 4
NOP
NOP
NOP
LIL $3, 7
NOP
NOP
NOP

-- R-type tests
-- R4 = R1 + R2 = 3 + 4 = 7
ADD $4, $1
NOP
ADD $4, $2
NOP
NOP
NOP
SW $4, 0($0)
NOP

-- R5 = R2 - R1 = 4 - 3 = 1
AND $5, $0
NOP
OR $5, $2
NOP
SUB $5, $1
NOP
NOP
NOP
SW $5, 1($0)
NOP

-- R6 = R3 AND R1 = 7 & 3 = 3
AND $6, $0
NOP
OR $6, $3
NOP
AND $6, $1
NOP
NOP
NOP
SW $6, 2($0)
NOP

-- R7 = R1 OR R3 = 3 | 7 = 7
AND $7, $0
NOP
OR $7, $1
NOP
OR $7, $3
NOP
NOP
NOP
SW $7, 3($0)
NOP

-- R8 = R3 XOR R1 = 7 ^ 3 = 4
AND $8, $0
NOP
OR $8, $3
NOP
XOR $8, $1
NOP
NOP
NOP
SW $8, 4($0)
NOP

-- R9 = NOR R3, R0 = ~(7 | 0) = 0xFFF8
AND $9, $0
NOP
OR $9, $3
NOP
NOR $9, $0
NOP
NOP
NOP
SW $9, 5($0)
NOP

-- LIW test: R10 = 0xABCD
LIW $10, 0xABCD
NOP
NOP
SW $10, 6($0)
NOP

-- Shift tests
-- R11 = R3 << 1 = 7 << 1 = 14
AND $11, $0
NOP
OR $11, $3
NOP
SHL $11, $1
NOP
NOP
NOP
SW $11, 7($0)
NOP

-- R12 = R3 >> 1 = 7 >> 1 = 3
AND $12, $0
NOP
OR $12, $3
NOP
SHR $12, $1
NOP
NOP
NOP
SW $12, 8($0)
NOP

-- End: infinite loop
HALT: J %HALT%
NOP
