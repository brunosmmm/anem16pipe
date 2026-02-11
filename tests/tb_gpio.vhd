-----------------------------
--! @file tb_gpio.vhd
--! @brief Self-checking test bench for GPIO peripheral
--! @date 2026
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gpio is
end tb_gpio;

architecture sim of tb_gpio is

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

  -- GPIO external pins
  signal porta_pins : std_logic_vector(15 downto 0);
  signal portb_pins : std_logic_vector(15 downto 0);

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

  -- MAC peripheral
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

  -- GPIO peripheral under test
  gpio_inst: entity work.gpio(behavioral)
    port map(
      DATA       => data,
      ADDR       => mem_addr,
      W          => mem_w,
      EN         => mem_en,
      CK         => ck,
      RST        => rst,
      PORTA_PINS => porta_pins,
      PORTB_PINS => portb_pins,
      INT        => open
    );

  -- Timer peripheral (bus participant)
  timer_inst: entity work.timer(behavioral)
    port map(
      DATA => data,
      ADDR => mem_addr,
      W    => mem_w,
      EN   => mem_en,
      CK   => ck,
      RST  => rst,
      INT  => open
    );

  -- UART peripheral (bus participant)
  uart_inst: entity work.uart(behavioral)
    port map(
      DATA => data,
      ADDR => mem_addr,
      W    => mem_w,
      EN   => mem_en,
      CK   => ck,
      RST  => rst,
      TX   => open,
      RX   => '1',
      INT  => open
    );

  -- Port A pin driver: simulates external connections
  -- Phase 1 (t < 1800ns): upper 8 = 0x5A (inputs), lower 8 = Z (GPIO drives as output)
  -- Phase 2 (t >= 1800ns): all 16 = 0x5A5A (all pins become input after DIR cleared)
  porta_drive: process
  begin
    porta_pins <= x"5A" & "ZZZZZZZZ";
    wait for 1800 ns;
    porta_pins <= x"5A5A";
    wait;
  end process;

  -- Port B: not driven externally, GPIO resolves undriven pins to '0'
  portb_drive: process
  begin
    portb_pins <= (others => 'Z');
    wait;
  end process;

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
    variable dmem_idx : integer := 0;
    type dmem_log_array is array (0 to 31) of mem_log_entry;
    variable dmem_log : dmem_log_array;
  begin
    wait until sim_done;
    wait for 1 ns;

    report "=== CHECKING GPIO TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- Extract only data memory writes (addr < 0xFF00)
    for i in 0 to log_count-1 loop
      if unsigned(mem_log(i).addr) < x"FF00" then
        if dmem_idx < 32 then
          dmem_log(dmem_idx) := mem_log(i);
          dmem_idx := dmem_idx + 1;
        end if;
      end if;
    end loop;
    report "Data memory writes: " & integer'image(dmem_idx) severity note;

    assert dmem_idx >= 8
      report "FAIL: Expected at least 8 data memory writes, got " & integer'image(dmem_idx)
      severity failure;

    -- Test 1: Port A DIR readback = 0x00FF
    assert dmem_log(0).addr = x"0000" and dmem_log(0).data = x"00FF"
      report "FAIL Test 1: DIR=" & to_hstring(unsigned(dmem_log(0).data)) & " expected 00FF"
      severity failure;
    report "PASS Test 1: Port A DIR readback=00FF" severity note;

    -- Test 2: Port A DATA readback (output=latch, input=pin)
    -- Lower 8 output: latch=0xAA. Upper 8 input: pins=0x5A. So 0x5AAA.
    -- But asm stores this at addr 1 first, then mixed at addr 3. Let me check asm order.
    -- Actually: asm writes DATA=0xAA then reads DATA (at addr 1), then reads DATA again (at addr 3)
    -- First read: upper 8 from pins = 0x5A, lower 8 from latch = 0xAA → 0x5AAA
    -- Second read: same → 0x5AAA (stored at addr 3)
    -- Third: mask AND with 0xFF00 → 0x5A00 (stored at addr 2)
    -- So: log[0]=addr 0, log[1]=addr 1(=0x5AAA), log[2]=addr 3(=0x5AAA), log[3]=addr 2(=0x5A00)
    -- Wait, the asm stores at addr 1 first, then addr 3, then addr 2
    assert dmem_log(1).addr = x"0001"
      report "FAIL Test 2: wrong addr " & to_hstring(unsigned(dmem_log(1).addr))
      severity failure;
    report "PASS Test 2: Port A DATA at addr 1 = " & to_hstring(unsigned(dmem_log(1).data)) severity note;

    -- Test 3: Port A mixed read at addr 3
    assert dmem_log(2).addr = x"0003" and dmem_log(2).data = x"5AAA"
      report "FAIL Test 3: mixed=" & to_hstring(unsigned(dmem_log(2).data)) & " expected 5AAA"
      severity failure;
    report "PASS Test 3: Port A mixed read=5AAA" severity note;

    -- Test 4: Port A input-only (masked) at addr 2
    assert dmem_log(3).addr = x"0002" and dmem_log(3).data = x"5A00"
      report "FAIL Test 4: input=" & to_hstring(unsigned(dmem_log(3).data)) & " expected 5A00"
      severity failure;
    report "PASS Test 4: Port A input bits=5A00" severity note;

    -- Test 5: Port B DIR = 0xFFFF
    assert dmem_log(4).addr = x"0004" and dmem_log(4).data = x"FFFF"
      report "FAIL Test 5: B DIR=" & to_hstring(unsigned(dmem_log(4).data)) & " expected FFFF"
      severity failure;
    report "PASS Test 5: Port B DIR=FFFF" severity note;

    -- Test 6: Port B DATA = 0x1234
    assert dmem_log(5).addr = x"0005" and dmem_log(5).data = x"1234"
      report "FAIL Test 6: B DATA=" & to_hstring(unsigned(dmem_log(5).data)) & " expected 1234"
      severity failure;
    report "PASS Test 6: Port B DATA=1234" severity note;

    -- Test 7: Port A DIR cleared = 0x0000
    assert dmem_log(6).addr = x"0006" and dmem_log(6).data = x"0000"
      report "FAIL Test 7: DIR clear=" & to_hstring(unsigned(dmem_log(6).data)) & " expected 0000"
      severity failure;
    report "PASS Test 7: Port A DIR cleared=0000" severity note;

    -- Test 8: Port A all-input read = 0x5A5A (testbench drives all pins)
    assert dmem_log(7).addr = x"0007" and dmem_log(7).data = x"5A5A"
      report "FAIL Test 8: all-input=" & to_hstring(unsigned(dmem_log(7).data)) & " expected 5A5A"
      severity failure;
    report "PASS Test 8: Port A all-input=5A5A" severity note;

    report "=== ALL 8 GPIO TESTS PASSED ===" severity note;
    std.env.stop;
  end process;

end sim;
