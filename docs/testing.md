# Testing

ANEM16pipe uses GHDL for simulation with self-checking VHDL testbenches.

## Running Tests

### All Tests

```bash
make test
```

Runs all test suites sequentially. Each test assembles a `.asm` program, loads it into program memory, runs the GHDL simulation, and checks results via assertion statements.

### Individual Tests

```bash
make test_basic       # 23 arithmetic/logic/memory tests
make test_branch      # 4 branch and jump tests
make test_hazard      # 5 pipeline hazard tests
make test_stack       # 15 stack operation tests
make test_interrupt   # 10 interrupt/exception tests
```

### Trace Comparison

```bash
make compare
```

Runs both GHDL simulation and the reference software simulator, then compares memory-write traces. This verifies cycle-accurate behavioral equivalence.

## Test Architecture

Each test suite consists of three files:

| File | Purpose |
|------|---------|
| `tests/test_*.asm` | Assembly test program |
| `tests/tb_*.vhd` | VHDL self-checking testbench |
| `Makefile` target | Build and run rules |

### Test Program Pattern

Test programs follow a common pattern:

1. Jump past any handler code to main
2. Initialize registers with known values
3. Perform operations
4. Store results to specific memory addresses
5. End with a tight infinite loop

```asm
.ADDRESS 0x0000
J %main%
NOP

.ADDRESS 0x0020
main:
    ; ... test setup ...

    ; Test N: description
    LIW $1, <input>
    <operation>
    SW $result, 0($pointer)    ; store at known address
    ADDI $pointer, 1

    ; ... more tests ...

done: J %done%
      NOP
```

### Testbench Pattern

Testbenches instantiate the CPU, program memory, data memory, and MAC peripheral. They log all memory writes and check results after simulation:

```vhdl
-- Monitor memory writes
monitor: process(ck)
begin
    if rising_edge(ck) then
        if mem_en = '1' and mem_w = '1' then
            mem_log(log_count) <= (mem_addr, data, cycle_count);
            log_count <= log_count + 1;
        end if;
    end if;
end process;

-- Check results
check: process
begin
    wait until sim_done;
    for i in 0 to log_count-1 loop
        if mem_log(i).addr = x"0010" then
            assert mem_log(i).data = x"expected"
                report "FAIL: ..." severity failure;
            report "PASS: ..." severity note;
        end if;
    end loop;
end process;
```

## Adding a New Test

### 1. Write the Assembly Program

Create `tests/test_myfeature.asm`:

```asm
-- test_myfeature.asm: Test description
.ADDRESS 0x0000
J %main%
NOP

.ADDRESS 0x0020
main:
    LIW $14, 0x0010         -- result pointer

    -- Test 1: description
    LIW $1, <value>
    <operation>
    SW $result, 0($14)       -- [0x0010] = expected
    ADDI $14, 1

done: J %done%
      NOP
```

### 2. Write the Testbench

Create `tests/tb_myfeature.vhd` following the pattern in existing testbenches. Key components:

- CPU entity instantiation with `INT => '0'`
- Program memory, data memory, MAC instances
- Clock/reset process
- Memory write monitor
- Result checker (scan `mem_log` by address)

### 3. Update the Makefile

Add to `TB_SRCS`:

```makefile
TB_SRCS += tests/tb_myfeature.vhd
```

Add to `TEST_PROGS`:

```makefile
TEST_PROGS += tests/test_myfeature
```

Add to the `test` target:

```makefile
test: ... test_myfeature
```

Add to the `compare` target:

```makefile
compare: ... compare_myfeature
```

### 4. Run and Verify

```bash
make test_myfeature      # run the test
make compare_myfeature   # compare with simulator (if supported)
```

## Test Coverage

### test_basic (23 tests)

Fundamental instruction correctness:

- R-type: ADD, SUB, AND, OR, XOR, NOR, SLT, SGT
- S-type: SHL, SHR, SAR, ROL, ROR
- Memory: LW, SW with various offsets
- Immediates: LIU, LIL, LIW, ADDI

### test_branch (4 tests)

Control flow:

- J (unconditional jump)
- JAL / JR (call and return)
- BZ T / BZ N (conditional branches)
- BHLEQ

### test_hazard (5 tests)

Pipeline hazard resolution:

- ALU→ALU forwarding (back-to-back ADD)
- LW stall + WB forwarding
- NFW stall (LIW followed by dependent)
- SW stall with in-flight producer
- JR stall

### test_stack (15 tests)

Stack operations:

- PUSH / POP single and multiple registers
- SPRD / SPWR
- ADDI with positive and negative immediates
- Function call pattern (PUSH $15 / JAL / POP $15 / JR)
- Stack interaction with forwarding

### test_interrupt (10 tests)

Exception handling:

- SYSCALL entry (ECA, EPC values)
- RETI return (execution continues correctly)
- DI blocks external interrupt
- EI enables external interrupt
- External interrupt ECA = 0x00FF
- MTEPC / MFEPC round-trip
- Register preservation through SYSCALL
- Multiple SYSCALLs with different service numbers
- ALU forwarding chain after DI

## Debugging

### VCD Waveform Dump

Add `--vcd=output.vcd` to the GHDL run command in the Makefile to generate waveform files viewable in GTKWave.

### Memory Write Trace

All testbenches report memory writes to stdout:

```
MEM_WRITE: addr=0x0010 data=0x012A cycle=15
```

This trace shows what data was written where and when, making it easy to identify which test failed and at what cycle.

### Common Issues

!!! warning "Stale register reads"
    If a test shows incorrect values after a load (LIW, LW, POP), check that the hazard unit is correctly stalling. WB→ID same-cycle overlap needs the write-through bypass.

!!! warning "Branch offset errors"
    If branches land at wrong addresses, check the assembler offset calculation. J/JAL offsets are `target - current - 1`, while BZ/BHLEQ offsets are `target - current - 2`.

!!! warning "Flush slot not respected"
    Every branch/jump has a flush slot. If the instruction after a branch is executing, the flush logic may not be propagating correctly.
