-----------------------------
--! @file tb_basic.vhd
--! @brief Self-checking test bench for ANEM processor
--! @date 2026
--! Runs a test program and checks data memory writes
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_basic is
end tb_basic;

architecture sim of tb_basic is

  constant CLK_PERIOD : time := 20 ns;
  constant NUM_CYCLES : integer := 2048;

  signal ck    : std_logic := '0';
  signal rst   : std_logic := '0';
  signal inst  : std_logic_vector(15 downto 0);
  signal inst_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal mem_w  : std_logic;
  signal mem_en : std_logic;
  signal data   : std_logic_vector(15 downto 0) := (others => 'Z');
  signal mem_addr : std_logic_vector(15 downto 0);

  -- Monitor memory writes
  type mem_log_entry is record
    addr : std_logic_vector(15 downto 0);
    data : std_logic_vector(15 downto 0);
    cycle : integer;
  end record;

  type mem_log_array is array (0 to 255) of mem_log_entry;
  signal mem_log : mem_log_array;
  signal log_count : integer := 0;
  signal cycle_count : integer := 0;
  signal sim_done : boolean := false;

  -- Peripheral signals
  signal porta_pins : std_logic_vector(15 downto 0) := (others => 'Z');
  signal portb_pins : std_logic_vector(15 downto 0) := (others => 'Z');

begin

  -- CPU
  cpu: entity work.ANEM(test)
    port map(
      CK        => ck,
      RST       => rst,
      TEST      => '0',
      INST      => inst,
      S_IN      => '0',
      S_OUT     => open,
      MEM_W     => mem_w,
      MEM_EN    => mem_en,
      MEM_ADDR  => mem_addr,
      DATA      => data,
      INST_ADDR => inst_addr,
      INT       => '0'
    );

  -- Program memory
  imem: entity work.progmem(rom)
    port map(
      ck      => ck,
      en      => '1',
      address => inst_addr,
      instr   => inst
    );

  -- Data memory
  dmem: entity work.datamem(ram)
    port map(
      ck      => ck,
      en      => mem_en,
      w       => mem_w,
      address => mem_addr,
      data    => data
    );

  -- MAC peripheral (needed since CPU may drive MAC addresses)
  mac_inst: entity work.MAC(MultAcc)
    port map(
      DATA => data,
      CK   => ck,
      RST  => rst,
      ADDR => mem_addr,
      W    => mem_w,
      EN   => mem_en,
      INT  => open
    );

  -- GPIO peripheral
  gpio_inst: entity work.gpio(behavioral)
    port map(
      DATA => data, ADDR => mem_addr, W => mem_w, EN => mem_en,
      CK => ck, RST => rst, PORTA_PINS => porta_pins,
      PORTB_PINS => portb_pins, INT => open
    );

  -- Timer peripheral
  timer_inst: entity work.timer(behavioral)
    port map(
      DATA => data, ADDR => mem_addr, W => mem_w, EN => mem_en,
      CK => ck, RST => rst, INT => open
    );

  -- UART peripheral
  uart_inst: entity work.uart(behavioral)
    port map(
      DATA => data, ADDR => mem_addr, W => mem_w, EN => mem_en,
      CK => ck, RST => rst, TX => open, RX => '1', INT => open
    );

  -- Clock and reset
  clk_proc: process
  begin
    rst <= '1';
    wait for 30 ns;
    rst <= '0';

    for i in 0 to NUM_CYCLES-1 loop
      ck <= '1';
      wait for CLK_PERIOD/2;
      ck <= '0';
      wait for CLK_PERIOD/2;
      cycle_count <= cycle_count + 1;
    end loop;

    sim_done <= true;
    wait;
  end process;

  -- Monitor memory writes
  monitor: process(ck)
  begin
    if rising_edge(ck) then
      if mem_en = '1' and mem_w = '1' then
        -- Log the write
        if log_count < 256 then
          mem_log(log_count).addr <= mem_addr;
          -- data bus is driven by the CPU during writes
          mem_log(log_count).data <= data;
          mem_log(log_count).cycle <= cycle_count;
          log_count <= log_count + 1;
        end if;

        report "MEM_WRITE: addr=0x" &
          to_hstring(unsigned(mem_addr)) &
          " data=0x" &
          to_hstring(unsigned(data)) &
          " cycle=" & integer'image(cycle_count)
          severity note;
      end if;
    end if;
  end process;

  -- Check results after simulation
  check: process
  begin
    wait until sim_done;
    wait for 1 ns;

    report "=== CHECKING TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- Verify we got all expected writes
    assert log_count >= 23
      report "FAIL: Expected at least 23 memory writes, got " & integer'image(log_count)
      severity failure;

    -- Test 1: ADD 3+4 = 7
    assert mem_log(0).addr = x"0000" and mem_log(0).data = x"0007"
      report "FAIL Test 1 ADD: addr=" & to_hstring(unsigned(mem_log(0).addr)) &
             " data=" & to_hstring(unsigned(mem_log(0).data)) &
             " expected addr=0000 data=0007"
      severity failure;
    report "PASS Test 1: ADD 3+4=7" severity note;

    -- Test 2: SUB 4-3 = 1
    assert mem_log(1).addr = x"0001" and mem_log(1).data = x"0001"
      report "FAIL Test 2 SUB: addr=" & to_hstring(unsigned(mem_log(1).addr)) &
             " data=" & to_hstring(unsigned(mem_log(1).data)) &
             " expected addr=0001 data=0001"
      severity failure;
    report "PASS Test 2: SUB 4-3=1" severity note;

    -- Test 3: AND 7&3 = 3
    assert mem_log(2).addr = x"0002" and mem_log(2).data = x"0003"
      report "FAIL Test 3 AND: addr=" & to_hstring(unsigned(mem_log(2).addr)) &
             " data=" & to_hstring(unsigned(mem_log(2).data)) &
             " expected addr=0002 data=0003"
      severity failure;
    report "PASS Test 3: AND 7&3=3" severity note;

    -- Test 4: OR 3|7 = 7
    assert mem_log(3).addr = x"0003" and mem_log(3).data = x"0007"
      report "FAIL Test 4 OR: addr=" & to_hstring(unsigned(mem_log(3).addr)) &
             " data=" & to_hstring(unsigned(mem_log(3).data)) &
             " expected addr=0003 data=0007"
      severity failure;
    report "PASS Test 4: OR 3|7=7" severity note;

    -- Test 5: XOR 7^3 = 4
    assert mem_log(4).addr = x"0004" and mem_log(4).data = x"0004"
      report "FAIL Test 5 XOR: addr=" & to_hstring(unsigned(mem_log(4).addr)) &
             " data=" & to_hstring(unsigned(mem_log(4).data)) &
             " expected addr=0004 data=0004"
      severity failure;
    report "PASS Test 5: XOR 7^3=4" severity note;

    -- Test 6: NOR ~(7|0) = 0xFFF8
    assert mem_log(5).addr = x"0005" and mem_log(5).data = x"FFF8"
      report "FAIL Test 6 NOR: addr=" & to_hstring(unsigned(mem_log(5).addr)) &
             " data=" & to_hstring(unsigned(mem_log(5).data)) &
             " expected addr=0005 data=FFF8"
      severity failure;
    report "PASS Test 6: NOR ~(7|0)=FFF8" severity note;

    -- Test 7: LIW 0xABCD
    assert mem_log(6).addr = x"0006" and mem_log(6).data = x"ABCD"
      report "FAIL Test 7 LIW: addr=" & to_hstring(unsigned(mem_log(6).addr)) &
             " data=" & to_hstring(unsigned(mem_log(6).data)) &
             " expected addr=0006 data=ABCD"
      severity failure;
    report "PASS Test 7: LIW 0xABCD" severity note;

    -- Test 8: SHL 7<<1 = 14
    assert mem_log(7).addr = x"0007" and mem_log(7).data = x"000E"
      report "FAIL Test 8 SHL: addr=" & to_hstring(unsigned(mem_log(7).addr)) &
             " data=" & to_hstring(unsigned(mem_log(7).data)) &
             " expected addr=0007 data=000E"
      severity failure;
    report "PASS Test 8: SHL 7<<1=000E" severity note;

    -- Test 9: SHR 7>>1 = 3
    assert mem_log(8).addr = x"0008" and mem_log(8).data = x"0003"
      report "FAIL Test 9 SHR: addr=" & to_hstring(unsigned(mem_log(8).addr)) &
             " data=" & to_hstring(unsigned(mem_log(8).data)) &
             " expected addr=0008 data=0003"
      severity failure;
    report "PASS Test 9: SHR 7>>1=0003" severity note;

    -- Test 10: LW forwarding (load from addr 0, expected 7)
    assert mem_log(9).addr = x"0009" and mem_log(9).data = x"0007"
      report "FAIL Test 10 LW: addr=" & to_hstring(unsigned(mem_log(9).addr)) &
             " data=" & to_hstring(unsigned(mem_log(9).data)) &
             " expected addr=0009 data=0007"
      severity failure;
    report "PASS Test 10: LW forwarding=0007" severity note;

    -- Test 11: SLT -8<3 = 1 (signed)
    assert mem_log(10).addr = x"000A" and mem_log(10).data = x"0001"
      report "FAIL Test 11 SLT: addr=" & to_hstring(unsigned(mem_log(10).addr)) &
             " data=" & to_hstring(unsigned(mem_log(10).data)) &
             " expected addr=000A data=0001"
      severity failure;
    report "PASS Test 11: SLT (-8<3)=1" severity note;

    -- Test 12: SGT 3>-8 = 1 (signed)
    assert mem_log(11).addr = x"000B" and mem_log(11).data = x"0001"
      report "FAIL Test 12 SGT: addr=" & to_hstring(unsigned(mem_log(11).addr)) &
             " data=" & to_hstring(unsigned(mem_log(11).data)) &
             " expected addr=000B data=0001"
      severity failure;
    report "PASS Test 12: SGT (3>-8)=1" severity note;

    -- Test 15: SAR 0xFFF8 >>> 1 = 0xFFFC
    assert mem_log(12).addr = x"000E" and mem_log(12).data = x"FFFC"
      report "FAIL Test 15 SAR: addr=" & to_hstring(unsigned(mem_log(12).addr)) &
             " data=" & to_hstring(unsigned(mem_log(12).data)) &
             " expected addr=000E data=FFFC"
      severity failure;
    report "PASS Test 15: SAR 0xFFF8>>>1=FFFC" severity note;

    -- Test 16: ROL 0xFFF8 ROL 1 = 0xFFF1
    assert mem_log(13).addr = x"000F" and mem_log(13).data = x"FFF1"
      report "FAIL Test 16 ROL: addr=" & to_hstring(unsigned(mem_log(13).addr)) &
             " data=" & to_hstring(unsigned(mem_log(13).data)) &
             " expected addr=000F data=FFF1"
      severity failure;
    report "PASS Test 16: ROL 0xFFF8 rol 1=FFF1" severity note;

    -- Test 17: ROR 0x0007 ROR 1 = 0x8003
    assert mem_log(14).addr = x"0010" and mem_log(14).data = x"8003"
      report "FAIL Test 17 ROR: addr=" & to_hstring(unsigned(mem_log(14).addr)) &
             " data=" & to_hstring(unsigned(mem_log(14).data)) &
             " expected addr=0010 data=8003"
      severity failure;
    report "PASS Test 17: ROR 0x0007 ror 1=8003" severity note;

    -- Test 18: $0 immutability = 0x0000
    assert mem_log(15).addr = x"0011" and mem_log(15).data = x"0000"
      report "FAIL Test 18 $0: addr=" & to_hstring(unsigned(mem_log(15).addr)) &
             " data=" & to_hstring(unsigned(mem_log(15).data)) &
             " expected addr=0011 data=0000"
      severity failure;
    report "PASS Test 18: $0 immutability=0000" severity note;

    -- Test 19: LW base+offset = 0x8003 (from addr 16)
    assert mem_log(16).addr = x"0012" and mem_log(16).data = x"8003"
      report "FAIL Test 19 LW base: addr=" & to_hstring(unsigned(mem_log(16).addr)) &
             " data=" & to_hstring(unsigned(mem_log(16).data)) &
             " expected addr=0012 data=8003"
      severity failure;
    report "PASS Test 19: LW base+offset=8003" severity note;

    -- Test 20: LIL stale byte = 0xFF05
    assert mem_log(17).addr = x"0013" and mem_log(17).data = x"FF05"
      report "FAIL Test 20 LIL: addr=" & to_hstring(unsigned(mem_log(17).addr)) &
             " data=" & to_hstring(unsigned(mem_log(17).data)) &
             " expected addr=0013 data=FF05"
      severity failure;
    report "PASS Test 20: LIL stale byte=FF05" severity note;

    -- Test 21: MFHI = 0x002A (42 from HI register)
    assert mem_log(18).addr = x"0014" and mem_log(18).data = x"002A"
      report "FAIL Test 21 MFHI: addr=" & to_hstring(unsigned(mem_log(18).addr)) &
             " data=" & to_hstring(unsigned(mem_log(18).data)) &
             " expected addr=0014 data=002A"
      severity failure;
    report "PASS Test 21: MFHI=002A" severity note;

    -- Test 22: MFLO = 0x0063 (99 from LO register)
    assert mem_log(19).addr = x"0015" and mem_log(19).data = x"0063"
      report "FAIL Test 22 MFLO: addr=" & to_hstring(unsigned(mem_log(19).addr)) &
             " data=" & to_hstring(unsigned(mem_log(19).data)) &
             " expected addr=0015 data=0063"
      severity failure;
    report "PASS Test 22: MFLO=0063" severity note;

    -- Test 23: MUL 3*4 = 12 = 0x000C
    assert mem_log(20).addr = x"0016" and mem_log(20).data = x"000C"
      report "FAIL Test 23 MUL: addr=" & to_hstring(unsigned(mem_log(20).addr)) &
             " data=" & to_hstring(unsigned(mem_log(20).data)) &
             " expected addr=0016 data=000C"
      severity failure;
    report "PASS Test 23: MUL 3*4=000C" severity note;

    -- Test 13: JAL subroutine result = 0x0042
    assert mem_log(21).addr = x"000C" and mem_log(21).data = x"0042"
      report "FAIL Test 13 JAL sub: addr=" & to_hstring(unsigned(mem_log(21).addr)) &
             " data=" & to_hstring(unsigned(mem_log(21).data)) &
             " expected addr=000C data=0042"
      severity failure;
    report "PASS Test 13: JAL subroutine=0042" severity note;

    -- Test 14: JAL return address R15
    assert mem_log(22).addr = x"000D" and mem_log(22).data = x"0055"
      report "FAIL Test 14 JAL R15: addr=" & to_hstring(unsigned(mem_log(22).addr)) &
             " data=" & to_hstring(unsigned(mem_log(22).data)) &
             " expected addr=000D data=0055"
      severity failure;
    report "PASS Test 14: JAL return addr=0055" severity note;

    report "=== ALL 23 TESTS PASSED ===" severity note;

    -- Stop simulation
    std.env.stop;
  end process;

end sim;
