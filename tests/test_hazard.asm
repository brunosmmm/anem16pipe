-- test_hazard.asm
-- Pipeline hazard tests for ANEM16 processor
-- Tests forwarding paths and stall mechanisms
--
-- These tests produce WRONG results without working forwarding/stalls,
-- making them effective regression tests.
--
-- Memory map for test results:
--   addr 0: Back-to-back ADD (ALU->ALU forwarding) (expected: 0x000A = 10)
--   addr 1: Triple chain ADD (expected: 0x000A = 10)
--   addr 2: LW then ADD (LW stall + WB->ALU forwarding) (expected: 0x000A = 10)
--   addr 3: LIL then ADD (NFW stall, 3 cycles) (expected: 0x0026 = 38)
--   addr 4: LIL then SW (SW stall) (expected: 0x004D = 77)

-- Test 1: Back-to-back ADD (ALU->ALU forwarding)
-- R1 = 1, R2 = 2, R3 = 3, R4 = 4
-- Without forwarding: R1 reads stale 0, result would be wrong
LIL $1, 1
LIL $2, 2
LIL $3, 3
LIL $4, 4
-- Chain: R5 = R1+R2 = 3, then R5 = R5+R3 = 6, then R5 = R5+R4 = 10
AND $5, $0
ADD $5, $1
ADD $5, $2
ADD $5, $3
ADD $5, $4
SW $5, 0($0)

-- Test 2: Triple forwarding chain (all ALU->ALU)
-- R6 = 0 + 1 = 1, R7 = R6 + 2 = 3, R8 = R7 + 3 = 6, R9 = R8 + 4 = 10
AND $6, $0
ADD $6, $1
AND $7, $0
ADD $7, $6
ADD $7, $2
AND $8, $0
ADD $8, $7
ADD $8, $3
AND $9, $0
ADD $9, $8
ADD $9, $4
SW $9, 1($0)

-- Test 3: LW then ADD (load-use hazard)
-- Store 10 to addr 10, then load it back and use immediately
LIL $10, 10
SW $10, 10($0)
-- Now load from addr 10 into R11 and add 0 (tests LW stall + WB forwarding)
LW $11, 10($0)
ADD $11, $0
SW $11, 2($0)

-- Test 4: LIL then ADD (NFW stall)
-- LIL $12, 38 then immediately use R12
-- Without NFW stall, R12 would still be 0 (stale value)
LIL $12, 38
ADD $12, $0
SW $12, 3($0)

-- Test 5: LIL then SW (SW data hazard stall)
-- LIL $13, 77 then immediately store R13
-- Without SW stall, the stored value would be stale (0)
LIL $13, 77
SW $13, 4($0)

-- End: infinite loop
HALT: J %HALT%
NOP
