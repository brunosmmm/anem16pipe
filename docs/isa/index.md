# ISA Reference

The ANEM16 instruction set uses fixed 16-bit encodings. Every instruction packs an opcode in the top 4 bits, with the remaining 12 bits holding register indices, immediates, function codes, or offsets depending on the instruction format.

## Instruction Formats

### R-Type (Register-Register)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">Opcode</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Ra</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">7:4</div><div class="value">Rb</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">3:0</div><div class="value">Func</div></div>
</div>

Used by: [ADD, SUB, AND, OR, XOR, NOR, SLT, SGT, MUL](r-type.md)

### S-Type (Shift)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">Opcode</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Ra</div></div>
  <div class="field field-imm" style="flex:4"><div class="bits">7:4</div><div class="value">Shamt</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">3:0</div><div class="value">Func</div></div>
</div>

Used by: [SHL, SHR, SAR, ROL, ROR](s-type.md)

### W-Type (Memory Access)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">Opcode</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Rd/Rs</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">7:4</div><div class="value">Rb</div></div>
  <div class="field field-offset" style="flex:4"><div class="bits">3:0</div><div class="value">Offset</div></div>
</div>

Used by: [LW, SW](memory.md)

### I-Type (Immediate)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">Opcode</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Rd</div></div>
  <div class="field field-imm" style="flex:8"><div class="bits">7:0</div><div class="value">Immediate</div></div>
</div>

Used by: [LIU, LIL, ADDI](immediates.md)

### J-Type (Jump)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">Opcode</div></div>
  <div class="field field-offset" style="flex:12"><div class="bits">11:0</div><div class="value">Offset</div></div>
</div>

Used by: [J, JAL, BZ, BHLEQ](branches.md)

### M1-Type (Special)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">1110</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">11:8</div><div class="value">M1Func</div></div>
  <div class="field field-imm" style="flex:8"><div class="bits">7:0</div><div class="value">Data/Sub</div></div>
</div>

Used by: [HI/LO operations](hilo.md), [Interrupts & Exceptions](interrupt.md)

### STK-Type (Stack)

<div class="bit-field" markdown>
  <div class="field field-opcode" style="flex:4"><div class="bits">15:12</div><div class="value">0111</div></div>
  <div class="field field-reg" style="flex:4"><div class="bits">11:8</div><div class="value">Rd/Rs</div></div>
  <div class="field field-unused" style="flex:4"><div class="bits">7:4</div><div class="value">—</div></div>
  <div class="field field-func" style="flex:4"><div class="bits">3:0</div><div class="value">Func</div></div>
</div>

Used by: [PUSH, POP, SPRD, SPWR](stack.md)

## Color Legend

In bit-field diagrams throughout this documentation:

- <span style="color: #3f51b5; font-weight: bold;">Blue</span> — Opcode
- <span style="color: #4caf50; font-weight: bold;">Green</span> — Register index
- <span style="color: #ff9800; font-weight: bold;">Orange</span> — Function code
- <span style="color: #9c27b0; font-weight: bold;">Purple</span> — Immediate value
- <span style="color: #00bcd4; font-weight: bold;">Cyan</span> — Offset
- <span style="color: #9e9e9e; font-weight: bold;">Gray</span> — Unused

## Pipeline Stage Key

- <span class="stage-badge stage-if">IF</span> Instruction Fetch
- <span class="stage-badge stage-id">ID</span> Instruction Decode / Register Read
- <span class="stage-badge stage-alu">ALU</span> Execute / Address Calculate
- <span class="stage-badge stage-mem">MEM</span> Memory Access
- <span class="stage-badge stage-wb">WB</span> Write Back
