# Shifts (S-Type)

Shift and rotate operations on a single register by a constant amount.

**Opcode:** `0001`

## Encoding

<div class="bit-field">
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">0001</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Ra</div></div>
  <div class="field field-imm" style="flex:4"><div class="bits">7:4</div><div class="value">Shamt</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">3:0</div><div class="value">Func</div></div>
</div>

- **Ra** — Source and destination register
- **Shamt** — Shift amount (0–15), taken from the instruction field
- **Func** — Shift type selector

!!! warning "Shift amount is an immediate, not a register"
    The `Shamt` field occupies the same bit positions as Rb in R-type instructions, but it is used as a **literal 4-bit value**, not as a register index. `SHL $1, $3` shifts `$1` left by 3, not by the contents of `$3`.

## Instructions

| Mnemonic | Syntax | Func | Operation | Z flag |
|----------|--------|------|-----------|--------|
| `SHL` | `SHL $ra, $n` | `0010` | `Ra = Ra << n` | Yes |
| `SHR` | `SHR $ra, $n` | `0001` | `Ra = Ra >> n` (logical) | Yes |
| `SAR` | `SAR $ra, $n` | `0000` | `Ra = Ra >>> n` (arithmetic) | Yes |
| `ROL` | `ROL $ra, $n` | `1000` | `Ra = rotate_left(Ra, n)` | Yes |
| `ROR` | `ROR $ra, $n` | `0100` | `Ra = rotate_right(Ra, n)` | Yes |

## Details

### SHL / SHR / SAR

```asm
SHL $1, $4      ; $1 = $1 << 4  (shift left, zero fill)
SHR $2, $1      ; $2 = $2 >> 1  (logical shift right, zero fill)
SAR $3, $8      ; $3 = $3 >>> 8 (arithmetic shift right, sign-extend)
```

SAR preserves the sign bit — useful for dividing signed values by powers of 2.

### ROL / ROR

```asm
ROL $5, $3      ; Rotate $5 left by 3 positions
ROR $6, $1      ; Rotate $6 right by 1 position
```

Bits shifted out on one side re-enter on the other.

## Pipeline Behavior

- **Resolves in:** <span class="stage-badge stage-alu">ALU</span>
- **ALU control:** `alu_ctl = "010"` (S-type)
- **Z flag update:** Yes — same gating as R-type
- **Forwarding:** Same as R-type (full ALU→ALU and MEM→ALU)

Identical timing to R-type — no stalls for back-to-back shift operations.
