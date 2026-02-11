-----------------------------
--! @file tb_uart.vhd
--! @brief Self-checking test bench for UART peripheral
--! @date 2026
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart is
end tb_uart;

architecture sim of tb_uart is

  constant CLK_PERIOD : time := 20 ns;
  constant NUM_CYCLES : integer := 4096;  -- More cycles for UART timing

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

  -- UART signals
  signal uart_tx  : std_logic;
  signal uart_rx  : std_logic := '1';

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

  -- Baud timing: with div=3, one 16x sub-tick = 4 clocks = 80ns
  -- One bit = 16 * 80ns = 1280ns
  constant BAUD_DIV : integer := 3;
  constant BIT_TIME : time := 16 * (BAUD_DIV + 1) * CLK_PERIOD;

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

  -- Timer peripheral
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

  -- UART peripheral under test
  uart_inst: entity work.uart(behavioral)
    port map(
      DATA => data,
      ADDR => mem_addr,
      W    => mem_w,
      EN   => mem_en,
      CK   => ck,
      RST  => rst,
      TX   => uart_tx,
      RX   => uart_rx,
      INT  => open
    );

  -- TX loopback + RX inject: monitor TX and send data on RX
  -- After TX sends 0x41, we inject 0x55 on RX
  rx_inject: process
    variable tx_byte : std_logic_vector(7 downto 0);
    constant RX_BYTE : std_logic_vector(7 downto 0) := x"55";
  begin
    uart_rx <= '1';  -- Idle

    -- Wait for TX to start (falling edge = start bit)
    wait until uart_tx = '0';

    -- Deserialize TX output for verification
    wait for BIT_TIME;  -- Skip start bit
    for i in 0 to 7 loop
      wait for BIT_TIME / 2;  -- Mid-bit sample
      tx_byte(i) := uart_tx;
      wait for BIT_TIME / 2;
    end loop;
    wait for BIT_TIME;  -- Stop bit

    report "TX byte received: 0x" & to_hstring(unsigned(tx_byte)) severity note;
    assert tx_byte = x"41"
      report "FAIL: TX byte expected 0x41, got 0x" & to_hstring(unsigned(tx_byte))
      severity failure;

    -- Small gap then inject RX byte (0x55)
    wait for BIT_TIME * 2;

    -- Send start bit
    uart_rx <= '0';
    wait for BIT_TIME;

    -- Send data bits LSB first: 0x55 = 01010101
    for i in 0 to 7 loop
      uart_rx <= RX_BYTE(i);
      wait for BIT_TIME;
    end loop;

    -- Send stop bit
    uart_rx <= '1';
    wait for BIT_TIME;

    -- Return to idle
    uart_rx <= '1';
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
    variable found_count : integer := 0;
  begin
    wait until sim_done;
    wait for 1 ns;

    report "=== CHECKING UART TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- Scan for data memory writes
    for i in 0 to log_count-1 loop
      if unsigned(mem_log(i).addr) < x"FF00" then
        case found_count is
          when 0 =>
            -- Test 1: Initial TXRDY = 1
            assert mem_log(i).addr = x"0000" and mem_log(i).data = x"0001"
              report "FAIL Test 1: expected TXRDY=1, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 1: Initial TXRDY=1" severity note;

          when 1 =>
            -- Test 2: Baud readback = 3
            assert mem_log(i).addr = x"0001" and mem_log(i).data = x"0003"
              report "FAIL Test 2: expected baud=3, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 2: Baud readback=0003" severity note;

          when 2 =>
            -- Test 3: TX busy (TXRDY=0)
            assert mem_log(i).addr = x"0002" and mem_log(i).data = x"0000"
              report "FAIL Test 3: expected TXRDY=0, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 3: TX busy status=0000" severity note;

          when 3 =>
            -- Test 4: RX+TX status
            assert mem_log(i).addr = x"0004"
              report "FAIL Test 4: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            report "PASS Test 4: Status after wait=" &
                   to_hstring(unsigned(mem_log(i).data)) severity note;

          when 4 =>
            -- Test 5: RX data = 0x55
            assert mem_log(i).addr = x"0003"
              report "FAIL Test 5: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert mem_log(i).data = x"0055"
              report "FAIL Test 5: expected RX=0055, got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 5: RX data=0055" severity note;

          when 5 =>
            -- Test 6: RXDA cleared after DATA read
            assert mem_log(i).addr = x"0005"
              report "FAIL Test 6: wrong addr " & to_hstring(unsigned(mem_log(i).addr))
              severity failure;
            assert mem_log(i).data = x"0001"
              report "FAIL Test 6: expected TXRDY only (0001), got " &
                     to_hstring(unsigned(mem_log(i).data))
              severity failure;
            report "PASS Test 6: RXDA cleared=0001" severity note;

          when others => null;
        end case;
        found_count := found_count + 1;
      end if;
    end loop;

    assert found_count >= 3
      report "FAIL: Expected at least 3 data memory writes, got " & integer'image(found_count)
      severity failure;

    report "=== UART TESTS PASSED (found " & integer'image(found_count) & " results) ===" severity note;
    std.env.stop;
  end process;

end sim;
