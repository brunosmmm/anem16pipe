# ANEM16 Trace Format Specification (v1)

## Purpose

Compare CPU implementations by tracking architecturally-visible state changes.
Both the VHDL pipeline simulation (anem16pipe/GHDL) and the C++ behavioral
simulator (anem16sim) should produce **identical traces** for the same input
program. Differences indicate a bug in one implementation.

## Format Rules

- One event per line
- Lines starting with `#` are comments (ignored by comparator)
- Blank lines are ignored
- All hex values: 4 digits, lowercase, no `0x` prefix, zero-padded
- Fields separated by single space

## Events

### MW — Memory Write

```
MW <addr> <data>
```

Emitted whenever the CPU writes to data memory (SW instruction commits).

- `addr`: 4-digit hex memory address
- `data`: 4-digit hex data value

Example: `MW 0000 0007` — wrote 0x0007 to address 0x0000

**Note:** Writes to MAC peripheral addresses (>= 0xFFD0) are excluded.
Only data memory writes are traced.

### MR — Memory Read (optional, Level 2)

```
MR <addr> <data>
```

Emitted whenever the CPU reads from data memory (LW instruction commits).
This is optional — not required for basic comparison.

### RF — Register File Dump

```
RF <idx> <value>
```

Emitted once per register at end of simulation. `idx` is decimal (0-15).

Example: `RF 0 0000` — register $0 = 0x0000

### SR — Special Register Dump

```
SR <name> <value>
```

Emitted once per special register at end of simulation.

- `name`: `HI` or `LO`

Example: `SR HI 002a` — HI register = 0x002A

### END — Simulation Complete

```
END <mw_count>
```

Final line. `mw_count` is the decimal count of MW events emitted.

Example: `END 23` — 23 memory writes were traced

## Comparison Rules

1. **MW events** must match in **exact order** and **exact values**
2. **RF/SR events** must match in value (order doesn't matter)
3. **END count** must match
4. **Comments and blank lines** are ignored
5. **Cycle timing is NOT compared** — pipeline and behavioral models execute
   at different speeds; only the sequence and values matter
6. **MR events** are optional and not compared by default

## Example Trace

```
# anem16-trace v1
# Program: test_basic
# Source: ghdl (anem16pipe)
MW 0000 0007
MW 0001 0001
MW 0002 0003
MW 0003 0007
MW 0004 0004
MW 0005 fff8
MW 0006 abcd
RF 0 0000
RF 1 0003
RF 2 0004
RF 3 0007
RF 4 0007
RF 5 0010
RF 6 002a
RF 7 0063
RF 8 000c
RF 9 000c
RF 10 abcd
RF 11 0001
RF 12 0000
RF 13 0000
RF 14 000c
RF 15 0055
SR HI 002a
SR LO 0063
END 23
```

## Implementation Notes

### VHDL Side (anem16pipe) — Implemented

- Uses `std.textio` to write trace file during simulation
- MW events captured on `rising_edge(ck)` when `mem_en='1' and mem_w='1'`
- MAC peripheral writes (addr >= 0xFFD0) are excluded
- Halt detection: stops after 8 drain cycles when `inst = 0xFFFF` (J to self)
- Trace file written to `work/<testname>.trace`
- Run with: `make trace_basic`, `make trace_branch`, `make trace_hazard`
- Or: `make trace PROG=test_name` for arbitrary programs

**Limitation:** RF/SR register dump not yet implemented. GHDL's VHDL-2008
external name feature (`<< signal ... >>`) crashes with NULL access for
both composite types and sub-component buffer ports. Workaround: test
programs can SW all relevant registers to memory before HALT, making
register values appear as MW events in the trace.

### C++ Side (anem16sim)

- Emit `MW addr data` after every SW instruction executes
- At end of program (HALT detected), emit RF 0-15 and SR HI/LO
- Emit `END <count>`
- Write to `<testname>.trace`

### Comparison Script

```bash
diff <(grep -v '^#' pipe.trace | grep -v '^$') \
     <(grep -v '^#' sim.trace  | grep -v '^$')
```

Or a dedicated Python comparator for better error messages.
