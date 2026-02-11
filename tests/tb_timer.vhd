-----------------------------
--! @file tb_timer.vhd
--! @brief Self-checking test bench for Timer peripheral
--! @date 2026
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_timer is
end tb_timer;

architecture sim of tb_timer is

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

  signal porta_pins : std_logic_vector(15 downto 0) := (others => 'Z');
  signal portb_pins : std_logic_vector(15 downto 0) := (others => 'Z');

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

  -- GPIO peripheral
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

  -- Timer peripheral under test
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

  -- UART peripheral
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
    variable idx : integer;
    variable found_count : integer := 0;
  begin
    wait until sim_done;
    wait for 1 ns;

    report "=== CHECKING TIMER TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- Find first write to addr 0 (counter value after ticks)
    -- We scan for data memory writes (addr < 0xFF00)
    idx := 0;
    for i in 0 to log_count-1 loop
      if unsigned(mem_log(i).addr) < x"FF00" then
        case found_count is
          when 0 =>
            -- Test 1: Counter > 0
            assert mem_log(i).addr = x"0000"
              report "FAIL Test 1: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert unsigned(mem_log(i).data) > 0
              report "FAIL Test 1: counter should be > 0, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 1: Counter=" & to_hstring(unsigned(mem_log(i).data)) severity note;

          when 1 =>
            -- Test 2: Compare match flag (CMF = bit 1)
            assert mem_log(i).addr = x"0001"
              report "FAIL Test 2: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert mem_log(i).data(1) = '1'
              report "FAIL Test 2: CMF not set, status=" & to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 2: CMF set, status=" & to_hstring(unsigned(mem_log(i).data)) severity note;

          when 2 =>
            -- Test 3: Status cleared
            assert mem_log(i).addr = x"0002"
              report "FAIL Test 3: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert mem_log(i).data = x"0000"
              report "FAIL Test 3: status not cleared, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 3: Status cleared" severity note;

          when 3 =>
            -- Test 4: Overflow flag (OVF = bit 0)
            assert mem_log(i).addr = x"0003"
              report "FAIL Test 4: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert mem_log(i).data(0) = '1'
              report "FAIL Test 4: OVF not set, status=" & to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 4: OVF set, status=" & to_hstring(unsigned(mem_log(i).data)) severity note;

          when 4 =>
            -- Test 5: Auto-reload counter value
            assert mem_log(i).addr = x"0004"
              report "FAIL Test 5: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            report "PASS Test 5: Counter after reload=" & to_hstring(unsigned(mem_log(i).data)) severity note;

          when others => null;
        end case;
        found_count := found_count + 1;
      end if;
    end loop;

    assert found_count >= 5
      report "FAIL: Expected at least 5 data memory writes, got " & integer'image(found_count)
      severity failure;

    report "=== ALL 5 TIMER TESTS PASSED ===" severity note;
    std.env.stop;
  end process;

end sim;
