# ANEM16pipe

A 16-bit pipelined RISC processor implemented in VHDL with a 5-stage pipeline.

## Architecture at a Glance

| Feature | Detail |
|---------|--------|
| Word size | 16-bit |
| Instruction width | 16-bit fixed |
| Pipeline | 5 stages: IF, ID, ALU, MEM, WB |
| Registers | 16 general-purpose ($0–$15) + SP, HI, LO |
| Address space | 64K words (16-bit addresses) |
| Interrupts | 1 external IRQ line, software SYSCALL |
| Stack | Hardware stack pointer with PUSH/POP |

## Register File

| Register | Purpose |
|----------|---------|
| `$0` | Hardwired to zero |
| `$1` – `$14` | General purpose |
| `$15` | Return address (written by JAL) |
| `SP` | Stack pointer (dedicated, not in GPR file) |
| `HI`, `LO` | Multiply result / manual load |
| `EPC` | Exception Program Counter |
| `ECA` | Exception Cause |
| `IEN` | Interrupt Enable (1-bit) |

## Quick Reference

| Group | Instructions | Opcode |
|-------|-------------|--------|
| [Arithmetic & Logic](isa/r-type.md) | ADD, SUB, AND, OR, XOR, NOR, SLT, SGT, MUL | `0000` |
| [Shifts](isa/s-type.md) | SHL, SHR, SAR, ROL, ROR | `0001` |
| [Memory](isa/memory.md) | LW, SW | `0011`, `0010` |
| [Immediates](isa/immediates.md) | LIU, LIL, LIW, ADDI | `0100`, `0101`, `1011` |
| [Branches & Jumps](isa/branches.md) | J, JAL, JR, BZ, BHLEQ | `1111`, `1101`, `1100`, `1000`–`1010`, `0110` |
| [HI/LO](isa/hilo.md) | LHH, LHL, LLH, LLL, AIH, AIL, AIS, MFHI, MFLO, MTHI, MTLO | `1110` |
| [Stack](isa/stack.md) | PUSH, POP, SPRD, SPWR | `0111` |
| [Interrupts](isa/interrupt.md) | SYSCALL, RETI, EI, DI, MFEPC, MFECA, MTEPC | `1110` |

## Opcode Map

```
 0000  R-type (arithmetic/logic)    1000  BZ X (branch always)
 0001  S-type (shifts)              1001  BZ T (branch if zero)
 0010  SW (store word)              1010  BZ N (branch if not zero)
 0011  LW (load word)               1011  ADDI (add immediate)
 0100  LIU (load immediate upper)   1100  JR (jump register)
 0101  LIL (load immediate lower)   1101  JAL (jump and link)
 0110  BHLEQ (branch ≤)             1110  M1 (HI/LO, MAC, interrupts)
 0111  STK (stack operations)        1111  J (jump)
```

## Documentation Sections

- **[ISA Reference](isa/index.md)** — Complete instruction encodings, semantics, and examples
- **[Pipeline Architecture](pipeline.md)** — Stages, forwarding, hazards, and timing
- **[Assembler Guide](assembler.md)** — Syntax, directives, and pseudo-instructions
- **[Testing](testing.md)** — Test framework, running tests, adding new tests
