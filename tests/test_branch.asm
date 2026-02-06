-- test_branch.asm
-- Branch instruction tests for ANEM16 processor
-- Tests: BZ taken, BZ not-taken, BZ backward (loop), BZ stale Z flag
--
-- Key behavioral facts:
-- - BZ delay slot is FLUSHED (unlike J/JAL where delay slot executes)
-- - Z flag only updates on R-type/S-type instructions (gated by p_z_en)
-- - All BZ predicates (T/N/X) behave identically in hardware
-- - BZ offset = target - current - 2
--
-- Memory map for test results:
--   addr 0: BZ taken (expected: 0x0001)
--   addr 1: BZ not taken (expected: 0x0001)
--   addr 2: BZ backward loop 3x (expected: 0x0003)
--   addr 3: BZ stale Z (expected: 0x0001)

-- Test 1: BZ taken (Z=1 from SUB 0-0)
-- After reset, R1=0, so SUB R1,R1 = 0-0 = 0, Z=1
SUB $1, $1
BZ %T1TAKEN%,T
NOP
-- Not-taken path: store 0 (should not execute)
LIL $2, 0
SW $2, 0($0)
J %T2START%
NOP
T1TAKEN: LIL $2, 1
SW $2, 0($0)

-- Test 2: BZ not taken (Z=0 from ADD producing nonzero)
T2START: LIL $3, 1
ADD $3, $0
BZ %T2TAKEN%,T
NOP
-- Not-taken path: store 1 (correct)
LIL $4, 1
SW $4, 1($0)
J %T3START%
NOP
T2TAKEN: LIL $4, 0
SW $4, 1($0)

-- Test 3: BZ backward branch (loop 3 times)
-- R5=counter=3, R6=accumulator=0, R7=constant 1
T3START: LIL $5, 3
AND $6, $0
LIL $7, 1
LOOP: ADD $6, $7
SUB $5, $7
BZ %LOOPDONE%,T
NOP
J %LOOP%
NOP
LOOPDONE: SW $6, 2($0)

-- Test 4: BZ with stale Z (non-R/S instruction between ALU op and BZ)
-- SUB sets Z=1, then LIL does NOT update Z, BZ should still take
SUB $8, $8
LIL $9, 42
BZ %T4TAKEN%,T
NOP
-- Not-taken path: store 0
LIL $10, 0
SW $10, 3($0)
J %HALT%
NOP
T4TAKEN: LIL $10, 1
SW $10, 3($0)

-- End: infinite loop
HALT: J %HALT%
NOP
