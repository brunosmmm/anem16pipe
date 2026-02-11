-----------------------------
--! @file tb_stack.vhd
--! @brief Self-checking test bench for stack operations and ADDI
--! @date 2026
--! Tests: PUSH, POP, SPRD, SPWR, ADDI, SP forwarding
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_stack is
end tb_stack;

architecture sim of tb_stack is

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

  gpio_inst: entity work.gpio(behavioral)
    port map(
      DATA => data, ADDR => mem_addr, W => mem_w, EN => mem_en,
      CK => ck, RST => rst, PORTA_PINS => porta_pins,
      PORTB_PINS => portb_pins, INT => open
    );

  timer_inst: entity work.timer(behavioral)
    port map(
      DATA => data, ADDR => mem_addr, W => mem_w, EN => mem_en,
      CK => ck, RST => rst, INT => open
    );

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

    report "=== CHECKING STACK TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- We expect writes to stack memory (PUSH) + writes to data addresses 0-14
    -- Stack PUSH writes go to high addresses (0xFFCE etc) and are NOT test results
    -- Only check the SW writes to low addresses (test results)
    -- The mem_log captures ALL writes in order, so we need to find the right ones

    -- Let's check by address rather than by log index, since PUSH writes interleave
    -- Actually, let me trace through the execution order:
    --
    -- Write order (all writes, including PUSH to stack memory):
    --  0: SW $5, 0($0)   -> addr=0x0000 data=0xFFCF  (Test 1: SPRD initial SP)
    --  1: PUSH $1         -> addr=0xFFCE data=0x002A  (stack write, not test result)
    --  2: SW $6, 1($0)   -> addr=0x0001 data=0xFFCE  (Test 2: SP after PUSH)
    --  3: SW $7, 2($0)   -> addr=0x0002 data=0x002A  (Test 3: POP value)
    --  4: SW $8, 3($0)   -> addr=0x0003 data=0xFFCF  (Test 4: SP after POP)
    --  5: SW $10, 4($0)  -> addr=0x0004 data=0x0064  (Test 5: SPWR set SP=100)
    --  6: SW $10, 5($0)  -> addr=0x0005 data=0xFFCF  (Test 6: SPWR restore)
    --  7: PUSH $2         -> addr=0xFFCE data=0x000A  (stack write)
    --  8: PUSH $3         -> addr=0xFFCD data=0x0014  (stack write)
    --  9: PUSH $4         -> addr=0xFFCC data=0x001E  (stack write)
    -- 10: SW $11, 6($0)  -> addr=0x0006 data=0xFFCC  (Test 7: SP after 3 PUSHes)
    -- 11: SW $12, 7($0)  -> addr=0x0007 data=0x001E  (Test 8: POP 30)
    -- 12: SW $13, 8($0)  -> addr=0x0008 data=0x0014  (Test 9: POP 20)
    -- 13: SW $14, 9($0)  -> addr=0x0009 data=0x000A  (Test 10: POP 10)
    -- 14: PUSH $5         -> addr=0xFFCE data=0x000C  (stack write, ALU dep test)
    -- 15: SW $7, 10($0)  -> addr=0x000A data=0x000C  (Test 11: PUSH ALU dep)
    -- 16: PUSH $8         -> addr=0xFFCD data=0x0063  (stack write)
    -- 17: SW $9, 11($0)  -> addr=0x000B data=0x0063  (Test 12: POP load-use)
    -- 18: SW $10, 12($0) -> addr=0x000C data=0x000F  (Test 13: ADDI +5)
    -- 19: SW $10, 13($0) -> addr=0x000D data=0x000C  (Test 14: ADDI -3)
    -- 20: SW $11, 14($0) -> addr=0x000E data=0x0019  (Test 15: ADDI chain)

    -- Verify minimum writes
    assert log_count >= 21
      report "FAIL: Expected at least 21 memory writes, got " & integer'image(log_count)
      severity failure;

    -- Test 1: SPRD initial SP = 0xFFCF
    assert mem_log(0).addr = x"0000" and mem_log(0).data = x"FFCF"
      report "FAIL Test 1 SPRD init: addr=" & to_hstring(unsigned(mem_log(0).addr)) &
             " data=" & to_hstring(unsigned(mem_log(0).data)) &
             " expected addr=0000 data=FFCF"
      severity failure;
    report "PASS Test 1: SPRD initial SP=FFCF" severity note;

    -- (log 1 = PUSH to stack, skip)

    -- Test 2: SP after PUSH = 0xFFCE
    assert mem_log(2).addr = x"0001" and mem_log(2).data = x"FFCE"
      report "FAIL Test 2 SP after PUSH: addr=" & to_hstring(unsigned(mem_log(2).addr)) &
             " data=" & to_hstring(unsigned(mem_log(2).data)) &
             " expected addr=0001 data=FFCE"
      severity failure;
    report "PASS Test 2: SP after PUSH=FFCE" severity note;

    -- Test 3: POP value = 0x002A (42)
    assert mem_log(3).addr = x"0002" and mem_log(3).data = x"002A"
      report "FAIL Test 3 POP value: addr=" & to_hstring(unsigned(mem_log(3).addr)) &
             " data=" & to_hstring(unsigned(mem_log(3).data)) &
             " expected addr=0002 data=002A"
      severity failure;
    report "PASS Test 3: POP value=002A" severity note;

    -- Test 4: SP after POP = 0xFFCF
    assert mem_log(4).addr = x"0003" and mem_log(4).data = x"FFCF"
      report "FAIL Test 4 SP after POP: addr=" & to_hstring(unsigned(mem_log(4).addr)) &
             " data=" & to_hstring(unsigned(mem_log(4).data)) &
             " expected addr=0003 data=FFCF"
      severity failure;
    report "PASS Test 4: SP after POP=FFCF" severity note;

    -- Test 5: SPWR set SP=100 (0x0064)
    assert mem_log(5).addr = x"0004" and mem_log(5).data = x"0064"
      report "FAIL Test 5 SPWR 100: addr=" & to_hstring(unsigned(mem_log(5).addr)) &
             " data=" & to_hstring(unsigned(mem_log(5).data)) &
             " expected addr=0004 data=0064"
      severity failure;
    report "PASS Test 5: SPWR set SP=0064" severity note;

    -- Test 6: SPWR restore = 0xFFCF
    assert mem_log(6).addr = x"0005" and mem_log(6).data = x"FFCF"
      report "FAIL Test 6 SPWR restore: addr=" & to_hstring(unsigned(mem_log(6).addr)) &
             " data=" & to_hstring(unsigned(mem_log(6).data)) &
             " expected addr=0005 data=FFCF"
      severity failure;
    report "PASS Test 6: SPWR restore=FFCF" severity note;

    -- (log 7,8,9 = three PUSH writes to stack, skip)

    -- Test 7: SP after 3 PUSHes = 0xFFCC
    assert mem_log(10).addr = x"0006" and mem_log(10).data = x"FFCC"
      report "FAIL Test 7 SP 3 PUSHes: addr=" & to_hstring(unsigned(mem_log(10).addr)) &
             " data=" & to_hstring(unsigned(mem_log(10).data)) &
             " expected addr=0006 data=FFCC"
      severity failure;
    report "PASS Test 7: SP after 3 PUSHes=FFCC" severity note;

    -- Test 8: POP 30 (last pushed)
    assert mem_log(11).addr = x"0007" and mem_log(11).data = x"001E"
      report "FAIL Test 8 POP 30: addr=" & to_hstring(unsigned(mem_log(11).addr)) &
             " data=" & to_hstring(unsigned(mem_log(11).data)) &
             " expected addr=0007 data=001E"
      severity failure;
    report "PASS Test 8: POP 30=001E" severity note;

    -- Test 9: POP 20
    assert mem_log(12).addr = x"0008" and mem_log(12).data = x"0014"
      report "FAIL Test 9 POP 20: addr=" & to_hstring(unsigned(mem_log(12).addr)) &
             " data=" & to_hstring(unsigned(mem_log(12).data)) &
             " expected addr=0008 data=0014"
      severity failure;
    report "PASS Test 9: POP 20=0014" severity note;

    -- Test 10: POP 10
    assert mem_log(13).addr = x"0009" and mem_log(13).data = x"000A"
      report "FAIL Test 10 POP 10: addr=" & to_hstring(unsigned(mem_log(13).addr)) &
             " data=" & to_hstring(unsigned(mem_log(13).data)) &
             " expected addr=0009 data=000A"
      severity failure;
    report "PASS Test 10: POP 10=000A" severity note;

    -- (log 14 = PUSH to stack, skip)

    -- Test 11: PUSH with ALU dep = 0x000C (12)
    assert mem_log(15).addr = x"000A" and mem_log(15).data = x"000C"
      report "FAIL Test 11 PUSH ALU dep: addr=" & to_hstring(unsigned(mem_log(15).addr)) &
             " data=" & to_hstring(unsigned(mem_log(15).data)) &
             " expected addr=000A data=000C"
      severity failure;
    report "PASS Test 11: PUSH ALU dep=000C" severity note;

    -- (log 16 = PUSH to stack, skip)

    -- Test 12: POP load-use = 0x0063 (99)
    assert mem_log(17).addr = x"000B" and mem_log(17).data = x"0063"
      report "FAIL Test 12 POP load-use: addr=" & to_hstring(unsigned(mem_log(17).addr)) &
             " data=" & to_hstring(unsigned(mem_log(17).data)) &
             " expected addr=000B data=0063"
      severity failure;
    report "PASS Test 12: POP load-use=0063" severity note;

    -- Test 13: ADDI +5 = 0x000F (15)
    assert mem_log(18).addr = x"000C" and mem_log(18).data = x"000F"
      report "FAIL Test 13 ADDI +5: addr=" & to_hstring(unsigned(mem_log(18).addr)) &
             " data=" & to_hstring(unsigned(mem_log(18).data)) &
             " expected addr=000C data=000F"
      severity failure;
    report "PASS Test 13: ADDI +5=000F" severity note;

    -- Test 14: ADDI -3 = 0x000C (12)
    assert mem_log(19).addr = x"000D" and mem_log(19).data = x"000C"
      report "FAIL Test 14 ADDI -3: addr=" & to_hstring(unsigned(mem_log(19).addr)) &
             " data=" & to_hstring(unsigned(mem_log(19).data)) &
             " expected addr=000D data=000C"
      severity failure;
    report "PASS Test 14: ADDI -3=000C" severity note;

    -- Test 15: ADDI chain = 0x0019 (25)
    assert mem_log(20).addr = x"000E" and mem_log(20).data = x"0019"
      report "FAIL Test 15 ADDI chain: addr=" & to_hstring(unsigned(mem_log(20).addr)) &
             " data=" & to_hstring(unsigned(mem_log(20).data)) &
             " expected addr=000E data=0019"
      severity failure;
    report "PASS Test 15: ADDI chain=0019" severity note;

    report "=== ALL 15 STACK TESTS PASSED ===" severity note;

    -- Stop simulation
    std.env.stop;
  end process;

end sim;
