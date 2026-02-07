# Assembler Guide

The ANEM16 assembler translates assembly source files (`.asm`) into binary memory images.

## Running the Assembler

```bash
python3 assembler/assembler.py input.asm
```

Output files:

| File | Contents |
|------|----------|
| `input.bin` | Raw binary (16-bit words, big-endian) |
| `input.contents.txt` | Hex format for GHDL `progmem` initialization |
| `input.ind` | Index file (address → instruction mapping) |
| `input.sym` | Symbol table (label → address) |
| `input.clean` | Preprocessed source (comments stripped) |

## Syntax

### Comments

```asm
ADD $1, $2          -- This is a comment
; This is also a comment (full-line)
```

Both `--` and `;` start line comments.

### Labels

```asm
loop: ADD $1, $2        -- label on same line
      SUB $3, $4
      BZ %loop%, T      -- reference with %label%
```

- Labels end with `:` and define an address
- References use `%label%` syntax in branch/jump operands
- The assembler resolves labels to PC-relative offsets automatically

### Directives

```asm
.ADDRESS 0x0020         -- Set assembly origin to address 0x0020
```

`.ADDRESS` sets the next instruction's address. The assembler fills gaps with NOPs.

## Instruction Syntax

### Register Operands

Registers are written as `$0` through `$15`.

```asm
ADD $1, $2          -- $1 = $1 + $2
SUB $3, $4          -- $3 = $3 - $4
```

### Immediate Values

Immediates can be decimal or hexadecimal (with `0x` prefix).

```asm
LIU $1, 0x5A       -- hex immediate
LIL $1, 90         -- decimal immediate
ADDI $2, -5        -- signed decimal
SYSCALL 42          -- service number
```

### Memory Operands

Memory instructions use `offset($base)` syntax.

```asm
LW $1, 0($5)       -- load from address in $5
SW $2, 3($0)        -- store to address 3
LW $3, 7($4)       -- load from $4 + 7
```

### Branch Targets

Branches and jumps use `%label%` for targets.

```asm
J %main%            -- jump to label 'main'
JAL %function%      -- call function
BZ %done%, T        -- branch to 'done' if zero
BHLEQ %loop%        -- branch to 'loop'
```

## Pseudo-Instructions

### NOP

```asm
NOP                 -- Encoded as ADD $0, $0 (0x0000)
```

### LIW (Load Immediate Word)

```asm
LIW $1, 0x1234      -- Load full 16-bit value
```

Expands to:

```asm
LIU $1, 0x12         -- Upper byte first
LIL $1, 0x34         -- Lower byte second
```

!!! warning "LIU before LIL"
    The assembler always generates LIU first, then LIL. LIL only writes the lower byte, preserving the upper byte set by LIU.

### HAB (Halt and Branch)

```asm
HAB                 -- Encoded as J to address 0 (infinite loop)
```

!!! tip "Prefer tight loop"
    For test programs, a labeled tight loop is clearer:
    ```asm
    done: J %done%
          NOP
    ```

## Complete Instruction Reference

### R-Type (Opcode 0000)

```asm
ADD $ra, $rb        -- Ra = Ra + Rb
SUB $ra, $rb        -- Ra = Ra - Rb
AND $ra, $rb        -- Ra = Ra & Rb
OR  $ra, $rb        -- Ra = Ra | Rb
XOR $ra, $rb        -- Ra = Ra ^ Rb
NOR $ra, $rb        -- Ra = ~(Ra | Rb)
SLT $ra, $rb        -- Ra = (Ra < Rb) ? 1 : 0  (signed)
SGT $ra, $rb        -- Ra = (Ra > Rb) ? 1 : 0  (signed)
MUL $ra, $rb        -- HI:LO = Ra * Rb
```

### S-Type (Opcode 0001)

```asm
SHL $ra, $n         -- Shift left by n
SHR $ra, $n         -- Logical shift right by n
SAR $ra, $n         -- Arithmetic shift right by n
ROL $ra, $n         -- Rotate left by n
ROR $ra, $n         -- Rotate right by n
```

The shift amount `$n` uses register syntax but is a **literal value** (0–15).

### Memory (Opcodes 0010, 0011)

```asm
SW $rs, offset($rb) -- Store word
LW $rd, offset($rb) -- Load word
```

### Immediates (Opcodes 0100, 0101, 1011)

```asm
LIU $rd, imm8       -- Load upper byte
LIL $rd, imm8       -- Load lower byte
LIW $rd, imm16      -- Load full word (pseudo)
ADDI $rd, imm8      -- Add sign-extended immediate
```

### Branches & Jumps (Opcodes 0110, 1000–1010, 1100, 1101, 1111)

```asm
J %label%           -- Unconditional jump
JAL %label%         -- Jump and link ($15 = PC+2)
JR $rs              -- Jump to register
BZ %label%, T       -- Branch if zero
BZ %label%, N       -- Branch if not zero
BZ %label%, X       -- Branch always
BHLEQ %label%       -- Branch if ≤
```

### Stack (Opcode 0111)

```asm
PUSH $rs            -- Push register onto stack
POP $rd             -- Pop from stack to register
SPRD $rd            -- Read stack pointer
SPWR $rs            -- Write stack pointer
```

### HI/LO (Opcode 1110, M1)

```asm
LHH imm8            -- HI[15:8] = imm8
LHL imm8            -- HI[7:0] = imm8
LLH imm8            -- LO[15:8] = imm8
LLL imm8            -- LO[7:0] = imm8
AIH imm8            -- HI += imm8
AIL imm8            -- LO += imm8
AIS imm8            -- HI += imm8; LO += imm8
MFHI $rd            -- Rd = HI
MFLO $rd            -- Rd = LO
MTHI $rs            -- HI = Rs
MTLO $rs            -- LO = Rs
```

### Interrupts (Opcode 1110, M4/SYSCALL)

```asm
SYSCALL imm8        -- Software trap (service 0-255)
RETI                -- Return from exception
EI                  -- Enable interrupts
DI                  -- Disable interrupts
MFEPC $rd           -- Rd = EPC
MFECA $rd           -- Rd = ECA
MTEPC $rs           -- EPC = Rs
```

## Example Program

```asm
-- Compute sum of 1..10, store at address 0x0010
.ADDRESS 0x0000
J %main%
NOP

.ADDRESS 0x0020
main:
    LIW $1, 0           -- accumulator
    LIW $2, 1           -- counter
    LIW $3, 10          -- limit
    LIW $4, 1           -- increment

loop:
    ADD $1, $2           -- acc += counter
    ADD $2, $4           -- counter++
    SGT $5, $2, $3       -- $5 = (counter > limit) ? 1 : 0
    -- Hmm, SGT modifies $ra, so:
    -- Actually: use SUB + BZ pattern
    SUB $5, $3           -- temp = limit - counter (sets Z if equal)
    BZ %done%, T         -- if counter > limit, done
    NOP
    NOP
    J %loop%
    NOP

done:
    ADD $1, $2           -- add final value
    SW $1, 0($0)         -- store result at MEM[0x0010]
    J %done2%
    NOP

done2:
    J %done2%
    NOP
```
