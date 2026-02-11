-- test_uart.asm
-- UART peripheral test program
-- Tests TX byte transmission, status flags, RX readback
--
-- UART addresses:
--   0xFFDB = UART_DATA (TX write / RX read)
--   0xFFDC = UART_CTRL
--   0xFFDD = UART_STATUS
--   0xFFDE = UART_BAUD
--
-- CTRL bits: [0]=TXEN, [1]=RXEN, [2]=TXIE, [3]=RXIE
-- STATUS bits: [0]=TXRDY(RO), [1]=RXDA(RO), [2]=FE(W1C), [3]=OE(W1C)
--
-- Memory map for test results:
--   addr 0: Initial TXRDY status (expected: 0x0001 = TX ready)
--   addr 1: Baud divisor readback (expected: 0x0003)
--   addr 2: Status after TX start (expected: 0x0000 = TX busy)
--   addr 3: RX data received (expected: 0x0055 = testbench sends 0x55)
--   addr 4: Status after RX (expected: 0x0003 = TXRDY+RXDA)
--   addr 5: Status after DATA read (expected: 0x0001 = RXDA cleared)

-- Setup address registers
LIW $1, 0xFFDB         -- UART_DATA
LIW $2, 0xFFDC         -- UART_CTRL
LIW $3, 0xFFDD         -- UART_STATUS
LIW $4, 0xFFDE         -- UART_BAUD

-- =============================================
-- Test 1: Initial status (TXRDY should be 1)
-- =============================================
LW $6, 0($3)           -- Read UART_STATUS
SW $6, 0($0)           -- Store at addr 0 (expect 0x0001)

-- =============================================
-- Setup: configure baud and enable
-- =============================================
-- Set baud divisor = 3 (for fast simulation: baud = CLK/(16*4))
LIW $5, 3
SW $5, 0($4)           -- UART_BAUD = 3
NOP
NOP
NOP

-- Test 2: Baud readback
LW $6, 0($4)           -- Read UART_BAUD
SW $6, 1($0)           -- Store at addr 1 (expect 0x0003)

-- Enable TX and RX
LIW $5, 0x0003         -- TXEN=1, RXEN=1
SW $5, 0($2)           -- UART_CTRL

-- =============================================
-- Test 3: TX a byte
-- =============================================
LIW $5, 0x0041         -- 'A' = 0x41
SW $5, 0($1)           -- Write UART_DATA -> starts TX
NOP
NOP
NOP

-- Read status immediately (TXRDY should be 0 = busy)
LW $6, 0($3)           -- UART_STATUS
SW $6, 2($0)           -- Store at addr 2 (expect 0x0000 = TX busy)

-- Wait for TX to complete and RX to receive (testbench loops TX back)
-- At baud_div=3: bit time = 16*(3+1) = 64 clocks, frame = 10 bits = 640 clocks
-- TX frame + 2-bit gap + RX frame = 640+128+640 = ~1408 clocks
-- ADDI loop: 3 cycles/iter (ADDI, BZ, NOP delay slot)
-- Z-setter must be immediately before BZ (no NOP — ADD $0,$0 is R-type and overwrites Z)
-- Use counter=500: 500*3 = 1500 cycles, plenty of margin
LIW $7, 500
wait_tx_rx:
ADDI $7, -1
BZ %wait_tx_rx%,N
NOP

-- =============================================
-- Test 4-5: Check RX data (testbench sends 0x55)
-- =============================================
-- Read status (expect TXRDY=1 + RXDA=1 = 0x0003)
LW $6, 0($3)
SW $6, 4($0)           -- Store at addr 4

-- Read RX data
LW $6, 0($1)           -- Read UART_DATA (should clear RXDA)
SW $6, 3($0)           -- Store at addr 3 (expect 0x0055)

-- Test 6: Status after reading DATA (RXDA should be cleared)
NOP
NOP
NOP
LW $6, 0($3)           -- Read UART_STATUS
SW $6, 5($0)           -- Store at addr 5 (expect 0x0001 = only TXRDY)

-- Done
done: J %done%
NOP
