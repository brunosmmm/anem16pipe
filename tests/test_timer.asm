-- test_timer.asm
-- Timer peripheral test program
-- Tests counter increment, overflow, compare match, auto-reload, prescaler
--
-- Timer addresses:
--   0xFFD7 = TMR_COUNT
--   0xFFD8 = TMR_CTRL
--   0xFFD9 = TMR_STATUS
--   0xFFDA = TMR_COMPARE
--
-- CTRL bits: [0]=EN, [2:1]=PSC, [3]=AR, [4]=OIE, [5]=CIE
-- STATUS bits: [0]=OVF, [1]=CMF (write-1-to-clear)
--
-- Memory map for test results:
--   addr 0: Counter after a few ticks (expected: nonzero, > 0)
--   addr 1: Compare match flag set (expected: 0x0002 = CMF bit)
--   addr 2: Status after W1C clear (expected: 0x0000)
--   addr 3: Overflow flag set (expected: 0x0001 = OVF bit)
--   addr 4: Counter after auto-reload (expected: 0xFFF0 = reload value)

-- Setup address registers
LIW $1, 0xFFD7         -- TMR_COUNT
LIW $2, 0xFFD8         -- TMR_CTRL
LIW $3, 0xFFD9         -- TMR_STATUS
LIW $4, 0xFFDA         -- TMR_COMPARE

-- =============================================
-- Test 1: Basic counting (prescaler=/1)
-- =============================================
-- Set compare to 10
LIW $5, 10
SW $5, 0($4)           -- TMR_COMPARE = 10

-- Set counter to 0
LIW $5, 0
SW $5, 0($1)           -- TMR_COUNT = 0

-- Enable timer: EN=1, PSC=00(/1), AR=0, OIE=0, CIE=0
LIW $5, 0x0001
SW $5, 0($2)           -- TMR_CTRL = 0x0001

-- Wait some cycles for counter to advance
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

-- Read counter (should be > 0)
LW $6, 0($1)           -- Read TMR_COUNT
SW $6, 0($0)           -- Store at addr 0

-- =============================================
-- Test 2: Compare match flag
-- =============================================
-- Counter should have reached 10 by now -> CMF set
LW $6, 0($3)           -- Read TMR_STATUS
SW $6, 1($0)           -- Store at addr 1 (expect bit 1 = CMF)

-- =============================================
-- Test 3: Write-1-to-clear status
-- =============================================
-- Clear CMF by writing 0x0002
LIW $5, 0x0003
SW $5, 0($3)           -- Write TMR_STATUS = 0x0003 (clear both OVF+CMF)
NOP
NOP
NOP
LW $6, 0($3)           -- Read TMR_STATUS
SW $6, 2($0)           -- Store at addr 2 (expect 0x0000)

-- =============================================
-- Test 4: Overflow detection
-- =============================================
-- Disable timer first
LIW $5, 0
SW $5, 0($2)           -- TMR_CTRL = 0 (disabled)

-- Set counter near overflow
LIW $5, 0xFFFC
SW $5, 0($1)           -- TMR_COUNT = 0xFFFC

-- Enable again with prescaler /1
LIW $5, 0x0001
SW $5, 0($2)           -- TMR_CTRL = EN=1

-- Wait for overflow (4 ticks: FFFC->FFFD->FFFE->FFFF->0000)
NOP
NOP
NOP
NOP
NOP
NOP

-- Read status
LW $6, 0($3)           -- TMR_STATUS
SW $6, 3($0)           -- Store at addr 3 (expect bit 0 = OVF)

-- =============================================
-- Test 5: Auto-reload
-- =============================================
-- Disable timer
LIW $5, 0
SW $5, 0($2)

-- Clear status
LIW $5, 0x0003
SW $5, 0($3)

-- Set reload value = 0xFFF0
LIW $5, 0xFFF0
SW $5, 0($1)           -- TMR_COUNT = 0xFFF0 (also sets reload)

-- Set counter near overflow
LIW $5, 0xFFFE
SW $5, 0($1)           -- TMR_COUNT = 0xFFFE (reload = 0xFFFE now)

-- Actually we need to set reload FIRST, then start near overflow
-- Reset: set counter = reload value
LIW $5, 0xFFF0
SW $5, 0($1)           -- TMR_COUNT = 0xFFF0, reload = 0xFFF0

-- Now set counter close to overflow but keep reload at 0xFFF0
-- We can't do this with current HW (writing COUNT sets both)
-- So: set counter to 0xFFFC, reload will also be 0xFFFC
LIW $5, 0xFFFC
SW $5, 0($1)           -- COUNT=0xFFFC, reload=0xFFFC

-- Enable with auto-reload: EN=1, AR=1
LIW $5, 0x0009         -- EN=1, PSC=00, AR=1
SW $5, 0($2)

-- Wait for overflow (4 ticks)
NOP
NOP
NOP
NOP
NOP
NOP

-- Read counter (should be near reload value 0xFFFC + some ticks)
LW $6, 0($1)           -- TMR_COUNT
SW $6, 4($0)           -- Store at addr 4

-- Done
done: J %done%
NOP
