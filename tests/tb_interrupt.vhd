-----------------------------
--! @file tb_interrupt.vhd
--! @brief Self-checking test bench for interrupt/exception handling
--! @date 2026
--! Tests: SYSCALL, RETI, EI, DI, MFEPC, MFECA, MTEPC, external interrupt
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_interrupt is
end tb_interrupt;

architecture sim of tb_interrupt is

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
  signal int_sig : std_logic := '0';

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

  -- CPU (with INT port)
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
      INT       => int_sig
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

  -- Clock, reset, and INT driving
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

      -- Drive INT signal for DI/EI tests
      -- DI instruction is at address 0x2E (=46). It reaches ID ~2 cycles after fetch.
      -- We assert INT around the NOPs after DI (cycles ~55-70ish)
      -- Then keep it high through EI test
      -- EI instruction is at addr 0x3A (=58). Reaches ID ~2 cycles after fetch.
      -- After EI, handler should fire. Release INT after handler runs.

      -- Let the simulation run for a while first to get past SYSCALL tests
      -- DI test starts around instruction address 0x2B (=43)
      -- We need to drive INT high during the DI test NOPs and through EI
      -- Rough timing: instruction at addr N takes ~N+initial_overhead cycles
      -- Let's check inst_addr to drive INT more precisely
    end loop;

    sim_done <= true;
    wait;
  end process;

  -- Drive INT based on instruction address (more reliable than cycle counting)
  -- We want INT=1 when:
  --   1. During DI test NOPs (addresses ~0x2F-0x35): should NOT fire (DI active)
  --   2. During/after EI (address ~0x3A+): should fire
  -- We release INT after the handler starts
  int_drive: process(ck)
    variable int_released : boolean := false;
    variable handler_seen : boolean := false;
  begin
    if rising_edge(ck) then
      -- Assert INT when the CPU is in the DI test region through EI test
      -- DI is at addr 46 (0x2E), NOPs follow, EI is at addr 58 (0x3A)
      -- Assert INT when inst_addr is in range [0x30, 0x40] (NOP region)
      if unsigned(inst_addr) >= x"0030" and unsigned(inst_addr) <= x"0040" and not int_released then
        int_sig <= '1';
      elsif unsigned(inst_addr) = x"0002" and int_sig = '1' then
        -- Handler entry detected - release INT after one cycle
        handler_seen := true;
      elsif handler_seen then
        int_sig <= '0';
        int_released := true;
      else
        int_sig <= '0';
      end if;
    end if;
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
    variable found_eca_syscall42 : boolean := false;
    variable found_reti_marker   : boolean := false;
    variable found_di_block      : boolean := false;
    variable found_ei_trigger    : boolean := false;
    variable found_mtepc_rt      : boolean := false;
    variable found_preserved_reg : boolean := false;
    variable found_eca_syscall200: boolean := false;
    variable found_alu_chain     : boolean := false;
    variable test_count          : integer := 0;
  begin
    wait until sim_done;
    wait for 1 ns;

    report "=== CHECKING INTERRUPT TEST RESULTS ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;

    -- Scan all memory writes and check by address
    for i in 0 to log_count-1 loop
      -- Test 1: SYSCALL 42 ECA = 0x012A (addr 0x0010)
      if mem_log(i).addr = x"0010" then
        assert mem_log(i).data = x"012A"
          report "FAIL Test 1 SYSCALL ECA: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x012A"
          severity failure;
        report "PASS Test 1: SYSCALL 42 ECA=012A" severity note;
        found_eca_syscall42 := true;
        test_count := test_count + 1;
      end if;

      -- Test 2: SYSCALL 42 EPC (addr 0x0011) - should be non-zero, in main code area
      if mem_log(i).addr = x"0011" then
        assert unsigned(mem_log(i).data) >= x"0025" and unsigned(mem_log(i).data) <= x"0028"
          report "FAIL Test 2 SYSCALL EPC: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected in range [0025,0028]"
          severity failure;
        report "PASS Test 2: SYSCALL EPC=0x" & to_hstring(unsigned(mem_log(i).data)) severity note;
        test_count := test_count + 1;
      end if;

      -- Test 3: RETI returned correctly - marker 0xBEEF (addr 0x0012)
      if mem_log(i).addr = x"0012" then
        assert mem_log(i).data = x"BEEF"
          report "FAIL Test 3 RETI marker: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0xBEEF"
          severity failure;
        report "PASS Test 3: RETI return marker=BEEF" severity note;
        found_reti_marker := true;
        test_count := test_count + 1;
      end if;

      -- Test 4: DI blocks interrupt - $13=0x0000 (addr 0x0013)
      if mem_log(i).addr = x"0013" then
        assert mem_log(i).data = x"0000"
          report "FAIL Test 4 DI block: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x0000"
          severity failure;
        report "PASS Test 4: DI blocks interrupt=0000" severity note;
        found_di_block := true;
        test_count := test_count + 1;
      end if;

      -- Test 5: External interrupt ECA = 0x00FF (addr 0x0014)
      if mem_log(i).addr = x"0014" then
        assert mem_log(i).data = x"00FF"
          report "FAIL Test 5 ext int ECA: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x00FF"
          severity failure;
        report "PASS Test 5: External interrupt ECA=00FF" severity note;
        test_count := test_count + 1;
      end if;

      -- Test 6: EI triggers handler - $13=0x0001 (addr 0x0016)
      if mem_log(i).addr = x"0016" then
        assert mem_log(i).data = x"0001"
          report "FAIL Test 6 EI trigger: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x0001"
          severity failure;
        report "PASS Test 6: EI enabled interrupt, handler ran=0001" severity note;
        found_ei_trigger := true;
        test_count := test_count + 1;
      end if;

      -- Test 7: MTEPC/MFEPC round-trip = 0x1234 (addr 0x0017)
      if mem_log(i).addr = x"0017" then
        assert mem_log(i).data = x"1234"
          report "FAIL Test 7 MTEPC/MFEPC: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x1234"
          severity failure;
        report "PASS Test 7: MTEPC/MFEPC round-trip=1234" severity note;
        found_mtepc_rt := true;
        test_count := test_count + 1;
      end if;

      -- Test 8: Register preserved through SYSCALL = 0xAAAA (addr 0x001A)
      if mem_log(i).addr = x"001A" then
        assert mem_log(i).data = x"AAAA"
          report "FAIL Test 8 reg preserved: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0xAAAA"
          severity failure;
        report "PASS Test 8: Register preserved through SYSCALL=AAAA" severity note;
        found_preserved_reg := true;
        test_count := test_count + 1;
      end if;

      -- Test 9: SYSCALL 99 ECA = 0x0163 (addr 0x0018)
      if mem_log(i).addr = x"0018" then
        assert mem_log(i).data = x"0163"
          report "FAIL Test 9 SYSCALL 99 ECA: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x0163"
          severity failure;
        report "PASS Test 9: SYSCALL 99 ECA=0163" severity note;
        found_eca_syscall200 := true;
        test_count := test_count + 1;
      end if;

      -- Test 10: ALU chain result = 0x0019 (25) (addr 0x001D)
      if mem_log(i).addr = x"001D" then
        assert mem_log(i).data = x"0019"
          report "FAIL Test 10 ALU chain: got 0x" & to_hstring(unsigned(mem_log(i).data)) &
                 " expected 0x0019"
          severity failure;
        report "PASS Test 10: ALU chain after interrupt=0019" severity note;
        found_alu_chain := true;
        test_count := test_count + 1;
      end if;
    end loop;

    report "Tests found: " & integer'image(test_count) & " of 10" severity note;

    assert test_count >= 10
      report "FAIL: Only " & integer'image(test_count) & " tests passed, expected 10"
      severity failure;

    report "=== ALL 10 INTERRUPT TESTS PASSED ===" severity note;

    -- Stop simulation
    std.env.stop;
  end process;

end sim;
