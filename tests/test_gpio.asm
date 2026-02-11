-- test_gpio.asm
-- GPIO peripheral test program
-- Tests direction register, output write, input readback, mixed I/O
--
-- GPIO addresses:
--   0xFFD0 = Port A Data
--   0xFFD1 = Port A Direction
--   0xFFD2 = Port B Data
--   0xFFD3 = Port B Direction
--
-- Memory map for test results:
--   addr 0: Port A DIR readback (expected: 0x00FF = lower 8 bits output)
--   addr 1: Port A DATA write+read (expected: 0x00AA = output latch for output bits)
--   addr 2: Port A input readback (expected: 0x5A00 = testbench drives upper 8 bits)
--   addr 3: Port A mixed read (expected: 0x5AAA = inputs on upper, outputs on lower)
--   addr 4: Port B DIR readback (expected: 0xFFFF = all output)
--   addr 5: Port B DATA write+read (expected: 0x1234)
--   addr 6: Port A DIR after clear (expected: 0x0000)
--   addr 7: Port A read all-input (expected: 0x5A5A = testbench drives all pins)

-- Setup base address registers
LIW $1, 0xFFD0        -- Port A Data addr
LIW $2, 0xFFD1        -- Port A Dir addr
LIW $3, 0xFFD2        -- Port B Data addr
LIW $4, 0xFFD3        -- Port B Dir addr

-- Test 1: Set Port A direction = 0x00FF (lower 8 = output, upper 8 = input)
LIW $5, 0x00FF
SW $5, 0($2)           -- Write Port A DIR
NOP
NOP
NOP
LW $6, 0($2)           -- Read back Port A DIR
SW $6, 0($0)           -- Store result at addr 0

-- Test 2: Write Port A data = 0x00AA, read back output bits
LIW $5, 0x00AA
SW $5, 0($1)           -- Write Port A DATA
NOP
NOP
NOP
LW $6, 0($1)           -- Read Port A DATA (output bits return latch, input bits return pin)
SW $6, 1($0)           -- Store at addr 1

-- Test 3: Read Port A input pins (upper 8 driven by testbench to 0x5A)
-- The readback mixes: upper 8 from pins (0x5A), lower 8 from latch (0xAA)
LW $6, 0($1)           -- Read Port A DATA
SW $6, 3($0)           -- Store mixed read at addr 3 (expect 0x5AAA)

-- Extract just the input bits (mask off output bits)
LIW $7, 0xFF00
AND $6, $7
SW $6, 2($0)           -- Store input-only at addr 2 (expect 0x5A00)

-- Test 4: Port B all output
LIW $5, 0xFFFF
SW $5, 0($4)           -- Write Port B DIR = all output
NOP
NOP
NOP
LW $6, 0($4)           -- Read back Port B DIR
SW $6, 4($0)           -- Store at addr 4

-- Test 5: Port B data write/read
LIW $5, 0x1234
SW $5, 0($3)           -- Write Port B DATA
NOP
NOP
NOP
LW $6, 0($3)           -- Read Port B DATA
SW $6, 5($0)           -- Store at addr 5

-- Test 6: Clear Port A direction to all-input
LIW $5, 0x0000
SW $5, 0($2)           -- Write Port A DIR = 0x0000
NOP
NOP
NOP
LW $6, 0($2)           -- Read back DIR
SW $6, 6($0)           -- Store at addr 6 (expect 0x0000)

-- Test 7: Read Port A as all-input (testbench drives 0x5A5A)
LW $6, 0($1)           -- Read Port A DATA (all input now)
SW $6, 7($0)           -- Store at addr 7 (expect 0x5A5A)

-- Done - infinite loop
done: J %done%
NOP
