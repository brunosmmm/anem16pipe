# ANEM16pipe Interrupt & Exception Handling Specification

## Overview

ANEM16pipe supports synchronous software traps (SYSCALL) and asynchronous external interrupts, using a single exception vector at fixed address **0x0002**.

Three new architectural registers:
- **EPC** (Exception PC, 16-bit): return address saved on exception entry
- **ECA** (Exception Cause, 16-bit): identifies exception source
- **IEN** (Interrupt Enable, 1-bit): gates external interrupt delivery

## Instruction Encodings

All new instructions are encoded under the existing M1 opcode (0xE).

### SYSCALL (M1 func "1011")

```
15  12 11   8 7              0
+------+------+----------------+
| 1110 | 1011 |  service_num   |
+------+------+----------------+
```

Software trap with 8-bit service number (0-255). Triggers exception entry sequence.

### M4 Group (M1 func "1100")

```
15  12 11   8 7    4 3    0
+------+------+------+------+
| 1110 | 1100 | sub  |  Rn  |
+------+------+------+------+
```

| subfunc (7:4) | Mnemonic   | Semantics                              |
|---------------|------------|----------------------------------------|
| `0000`        | RETI       | PC <- EPC, IEN <- 1, flush pipeline    |
| `0001`        | EI         | IEN <- 1 (enable interrupts)           |
| `0010`        | DI         | IEN <- 0 (disable interrupts)          |
| `0011`        | MFEPC $rn  | GPR[rn] <- EPC (via ALU pass-through)  |
| `0100`        | MFECA $rn  | GPR[rn] <- ECA (via ALU pass-through)  |
| `0101`        | MTEPC $rn  | EPC <- GPR[rn] (pipelined, writes at WB)|

## New Registers

| Register | Width  | Reset  | Purpose |
|----------|--------|--------|---------|
| EPC      | 16-bit | 0x0000 | Return address saved on exception entry |
| ECA      | 16-bit | 0x0000 | Exception cause (see encoding below) |
| IEN      | 1-bit  | 0      | Interrupt enable; cleared on exception entry, set by EI/RETI |

### ECA Encoding

```
15          9   8      7              0
+-------------+--------+----------------+
|   0000000   | source |  service_num   |
+-------------+--------+----------------+
```

- **Bit 8**: `1` = SYSCALL (synchronous), `0` = external interrupt
- **Bits 7:0**: SYSCALL service number (0-255), or `0xFF` for external interrupt

Examples:
- `SYSCALL 42` -> ECA = 0x012A
- External interrupt -> ECA = 0x00FF

## Exception Entry Sequence

### SYSCALL (Synchronous, ID Stage)

SYSCALL resolves at the ID stage, same as J/JAL. 2-cycle penalty.

1. EPC <- SYSCALL_addr + 2 (skips the flush slot instruction)
2. ECA <- {7'b0, 1'b1, instruction[7:0]}
3. IEN <- 0
4. PC <- 0x0002 (exception vector, highest priority in ifetch)
5. Instruction in IF is flushed (NOP inserted into pipeline)

```
Cycle  IF          ID          ALU         MEM         WB
T      SYSCALL     prev_inst   ...         ...         ...
T+1    next_inst   SYSCALL->   prev_inst   ...         ...
       ^flushed    EPC/ECA/IEN set, PC=0x0002
T+2    handler[0]  NOP(flush)  ...         prev_inst   ...
T+3    handler[1]  handler[0]  NOP         ...         prev_inst
```

### External Interrupt (Asynchronous, IF Level)

Fires on a "quiet cycle" when all conditions are met:
```
ext_int_take = INT AND IEN AND (NOT flush_active) AND (NOT stalled)
```

Where `flush_active` = jflag OR jrflag OR reti_flag OR bztrue OR bhleqtrue OR syscall_flag.

1. EPC <- next_inst_addr (flushed instruction address; re-executed after RETI)
2. ECA <- 0x00FF
3. IEN <- 0
4. PC <- 0x0002
5. In-flight instructions (ID/ALU/MEM/WB) complete normally

```
Cycle  IF          ID          ALU         MEM         WB
T      instr_k     instr_k-1   ...         ...         ...
       ^INT=1, IEN=1, quiet
       EPC=addr_k, IEN=0
T+1    handler[0]  NOP(flush)  instr_k-1   ...         ...
       (0x0002)                completes   completes
T+2    handler[1]  handler[0]  NOP         instr_k-1   ...
```

### RETI (Return from Exception, ID Stage)

RETI acts like JR but targets EPC instead of a GPR. Same timing as JR.

1. PC <- EPC (absolute jump)
2. IEN <- 1 (re-enable interrupts)
3. Instruction in IF is flushed

```
Cycle  IF          ID          ALU
T      next_inst   RETI->      ...
                   PC=EPC, IEN=1
T+1    EPC_target  NOP(flush)  ...
T+2    EPC_tgt+1   EPC_target  NOP
```

## Pipeline Integration

### Decoder Outputs

| Instruction | regctl | aluctl | func | mem_en | mem_w | exc_ctl | Notes |
|-------------|--------|--------|------|--------|-------|---------|-------|
| SYSCALL     | 000    | 000    | -    | 0      | 0     | -       | syscall_flag=1 |
| RETI        | 000    | 000    | -    | 0      | 0     | -       | reti_flag=1 |
| EI          | 000    | 000    | -    | 0      | 0     | -       | ei_flag=1 |
| DI          | 000    | 000    | -    | 0      | 0     | -       | di_flag=1 |
| MFEPC $rn   | 001    | 001    | ADD  | 0      | 0     | 001     | ALU_A=EPC, ALU_B=0 |
| MFECA $rn   | 001    | 001    | ADD  | 0      | 0     | 010     | ALU_A=ECA, ALU_B=0 |
| MTEPC $rn   | 000    | 001    | ADD  | 0      | 0     | 011     | ALU_A=GPR, ALU_B=0, write EPC at WB |

### exc_ctl Pipeline Signal (3-bit, ID->ALU->MEM->WB)

- `"001"` = MFEPC (overrides ALU_A to EPC)
- `"010"` = MFECA (overrides ALU_A to ECA)
- `"011"` = MTEPC (writes EPC at WB from ALU output)
- `"000"` = none

### ALU Overrides

MFEPC: `ALU_A = EPC, ALU_B = 0` -> ALU output = EPC (written to GPR[rn] at WB)
MFECA: `ALU_A = ECA, ALU_B = 0` -> ALU output = ECA (written to GPR[rn] at WB)
MTEPC: `ALU_A = GPR[rn], ALU_B = 0` -> ALU output = GPR[rn] (written to EPC at WB)

## Hazard Handling

### id_reads_regs Deny List

SYSCALL and M4 group (except MTEPC) are added to the deny list of instructions that do NOT read GPRs, preventing false data hazard stalls. MTEPC reads a GPR via sela and is NOT in the deny list.

### MFEPC/MFECA Forwarding

Since MFEPC/MFECA produce results via the ALU (regctl="001"), the existing forwarding unit handles dependents automatically. No NFW stall needed.

### MTEPC -> RETI/MFEPC Timing

MTEPC writes EPC at WB. RETI and MFEPC read EPC at ID.

- **Distance 3 (WB/ID overlap)**: handled by EPC write-through bypass mux
- **Distance 1-2 (MTEPC in ALU/MEM)**: EPC read stall in hazard unit

```vhdl
-- Bypass
epc_bypass <= p_alu_wb_aluout_3 when p_id_wb_epcwr_3 = '1' else epc_reg;

-- Stall
epc_read_stall = (RETI or MFEPC in ID) and (epcwr in ALU or MEM)
```

### SYSCALL/EI/DI Gating

SYSCALL flag is gated by the same stall/flush condition as regctl:
```
syscall_flag_gated = syscall_flag when NOT_stalled AND NOT_bz AND NOT_bhleq else '0'
```

EI/DI only take effect when `p_stall_if_n = '1'`.

RETI is NOT gated — it IS a flush source (like jrflag).

## Assembler Syntax

```asm
SYSCALL 42           -- Software trap, service number 42
RETI                 -- Return from exception
EI                   -- Enable interrupts
DI                   -- Disable interrupts
MFEPC $5             -- $5 <- EPC
MFECA $3             -- $3 <- ECA
MTEPC $7             -- EPC <- $7
```

## Exception Handler Convention

The handler at address 0x0002 is responsible for:
1. Saving any registers it uses (PUSH)
2. Reading ECA to determine cause (MFECA)
3. Reading EPC if needed (MFEPC)
4. Dispatching based on cause (SYSCALL service number or external interrupt)
5. Restoring saved registers (POP)
6. Returning via RETI

Example minimal handler:
```asm
.ADDRESS 0x0002
handler:
    PUSH $1              -- save scratch register
    MFECA $1             -- read cause
    -- ... handle exception based on $1 ...
    POP $1               -- restore
    RETI
    NOP                  -- flush slot
```

## Test Vectors

| Test | Description                    | Result Address | Expected Value |
|------|--------------------------------|----------------|----------------|
| 1    | SYSCALL 42 ECA                 | 0x0010         | 0x012A         |
| 2    | SYSCALL 42 EPC                 | 0x0011         | 0x0026         |
| 3    | RETI returns correctly         | 0x0012         | 0xBEEF         |
| 4    | DI blocks external interrupt   | 0x0013         | 0x0000         |
| 5    | External interrupt ECA         | 0x0014         | 0x00FF         |
| 6    | EI enables interrupt           | 0x0016         | 0x0001         |
| 7    | MTEPC/MFEPC round-trip         | 0x0017         | 0x1234         |
| 8    | Register preserved in handler  | 0x001A         | 0xAAAA         |
| 9    | SYSCALL 99 ECA                 | 0x0018         | 0x0163         |
| 10   | ALU chain after DI             | 0x001D         | 0x0019         |

## Simulator Implementation Notes

### Key State

- `epc` (uint16): Exception PC register, reset to 0
- `eca` (uint16): Exception Cause register, reset to 0
- `ien` (bool): Interrupt Enable flag, reset to false

### SYSCALL Execution

When SYSCALL is decoded:
1. Set `epc = pc + 2` (skip SYSCALL + flush slot)
2. Set `eca = 0x0100 | instruction[7:0]`
3. Set `ien = false`
4. Set `pc = 0x0002`
5. Insert 1 NOP (flush slot, same as J/JAL)

### External Interrupt

Check at each cycle (before fetch):
```python
if int_pin and ien and not (flush_pending or stall_pending):
    epc = pc  # address of instruction about to be fetched
    eca = 0x00FF
    ien = False
    pc = 0x0002
    # flush current IF instruction (insert NOP)
```

### RETI Execution

When RETI is decoded:
1. Set `pc = epc`
2. Set `ien = true`
3. Insert 1 NOP (flush slot, same as JR)

### EI/DI

- EI: `ien = true` (takes effect immediately in pipelined sim, next cycle in cycle-accurate)
- DI: `ien = false`

### MFEPC/MFECA/MTEPC

These are ALU pass-through operations:
- MFEPC: result = epc + 0, written to GPR[rn]
- MFECA: result = eca + 0, written to GPR[rn]
- MTEPC: result = GPR[rn] + 0, written to epc (at WB stage in pipeline)
