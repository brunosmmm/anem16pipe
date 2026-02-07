# HI/LO Registers (M1 Group)

Operations on the HI and LO special-purpose registers, used for multiply results and manual data loading.

**Opcode:** `1110` (M1)

## M1 Function Codes

All M1 instructions share opcode `1110`. Bits 11:8 select the sub-operation.

| M1Func | Category | Instructions |
|--------|----------|-------------|
| `0000` | Load byte | LHL (HI low byte) |
| `0001` | Load byte | LHH (HI high byte) |
| `0010` | Load byte | LLL (LO low byte) |
| `0011` | Load byte | LLH (LO high byte) |
| `0100` | Add immediate | AIS (add to both) |
| `0101` | Add immediate | AIH (add to HI) |
| `0110` | Add immediate | AIL (add to LO) |
| `0111` | Move GPR | MFHI (move from HI) |
| `1000` | Move GPR | MFLO (move from LO) |
| `1001` | Move GPR | MTHI (move to HI) |
| `1010` | Move GPR | MTLO (move to LO) |

---

## Byte Load Instructions

<div class="bit-field">
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">1110</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">11:8</div><div class="value">M1Func</div></div>
  <div class="field field-imm" style="flex:8"><div class="bits">7:0</div><div class="value">Data (8-bit)</div></div>
</div>

| Mnemonic | M1Func | Operation |
|----------|--------|-----------|
| `LHH` | `0001` | `HI[15:8] = Data` |
| `LHL` | `0000` | `HI[7:0] = Data` |
| `LLH` | `0011` | `LO[15:8] = Data` |
| `LLL` | `0010` | `LO[7:0] = Data` |

Each instruction writes a **single byte** — the other byte is preserved.

```asm
LHH 0x12            ; HI[15:8] = 0x12
LHL 0x34            ; HI[7:0] = 0x34    → HI = 0x1234
LLH 0x56            ; LO[15:8] = 0x56
LLL 0x78            ; LO[7:0] = 0x78    → LO = 0x5678
```

!!! note "Byte merge at WB"
    Partial writes use a byte-merge bypass at the WB stage. When reading HI/LO on the same cycle as a write, the bypass combines the new byte with the old byte from the register.

---

## Add Immediate Instructions

<div class="bit-field">
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">1110</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">11:8</div><div class="value">M1Func</div></div>
  <div class="field field-imm" style="flex:8"><div class="bits">7:0</div><div class="value">Data (8-bit)</div></div>
</div>

| Mnemonic | M1Func | Operation |
|----------|--------|-----------|
| `AIH` | `0101` | `HI = HI + Data` |
| `AIL` | `0110` | `LO = LO + Data` |
| `AIS` | `0100` | `HI = HI + Data; LO = LO + Data` |

```asm
AIH 1                ; HI = HI + 1
AIL 10               ; LO = LO + 10
AIS 5                ; HI += 5; LO += 5
```

---

## Move Instructions (M3 Group)

<div class="bit-field">
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">1110</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">11:8</div><div class="value">M1Func</div></div>
  <div class="field field-unused" style="flex:4"><div class="bits">7:4</div><div class="value">0000</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">3:0</div><div class="value">Rn</div></div>
</div>

!!! warning "Register index is in bits 3:0"
    Unlike most instructions where the register is in bits 11:8, M3 instructions encode the GPR in bits **3:0**. The decoder has a special override to route `instruction(3:0)` to the register file's select lines.

| Mnemonic | M1Func | Operation |
|----------|--------|-----------|
| `MFHI` | `0111` | `Rn = HI` (move from HI to GPR) |
| `MFLO` | `1000` | `Rn = LO` (move from LO to GPR) |
| `MTHI` | `1001` | `HI = Rn` (move from GPR to HI) |
| `MTLO` | `1010` | `LO = Rn` (move from GPR to LO) |

```asm
MUL $3, $5           ; HI:LO = $3 * $5
NOP                  ; 1 NOP for HI/LO propagation
MFHI $6              ; $6 = HI (upper 16 bits)
MFLO $7              ; $7 = LO (lower 16 bits)
```

## Pipeline Behavior

### Byte Load / Add Immediate

- **Write stage:** <span class="stage-badge stage-wb">WB</span> (partial byte write to HI/LO)
- **No GPR interaction** — these don't read or write general-purpose registers

### MFHI / MFLO

- **Read HI/LO at:** <span class="stage-badge stage-id">ID</span>
- **Write GPR at:** <span class="stage-badge stage-wb">WB</span>
- **Hazard type:** NFW stall (data comes from HI/LO snapshot, not ALU output)
- **Stall cycles:** Up to 3 for dependent instructions

!!! tip "1 NOP between M1 write and MFHI/MFLO"
    After writing HI or LO (via LHH/LHL/LLH/LLL/AIH/AIL/MUL), insert at least 1 NOP before reading with MFHI/MFLO to allow the write to propagate through the pipeline.

### MTHI / MTLO

- **Read GPR at:** <span class="stage-badge stage-id">ID</span>
- **Write HI/LO at:** <span class="stage-badge stage-wb">WB</span>
- **Reads from:** `instruction(3:0)` (same M3 register routing)
