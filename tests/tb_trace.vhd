-----------------------------
--! @file tb_trace.vhd
--! @brief Trace-generating testbench for ANEM processor
--! @date 2026
--! Runs a test program, writes a trace file for golden model comparison.
--! See tests/TRACE_FORMAT.md for the trace format specification.
--!
--! Trace file is written to "trace_output.txt" in the working directory.
--! Use GHDL generic override to change: -gTRACE_FILE=mytest.trace
--!
--! Note: RF/SR lines require test programs to SW register values to memory
--! before HALT. The MW trace captures these as regular memory writes.
-----------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_trace is
  generic (
    TRACE_FILE : string := "trace_output.txt";
    NUM_CYCLES : integer := 4096;
    HALT_INST  : std_logic_vector(15 downto 0) := x"FFFF"
  );
end tb_trace;

architecture sim of tb_trace is

  constant CLK_PERIOD : time := 20 ns;

  signal ck    : std_logic := '0';
  signal rst   : std_logic := '0';
  signal inst  : std_logic_vector(15 downto 0);
  signal inst_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal mem_w  : std_logic;
  signal mem_en : std_logic;
  signal data   : std_logic_vector(15 downto 0) := (others => 'Z');
  signal mem_addr : std_logic_vector(15 downto 0);

  signal cycle_count : integer := 0;
  signal sim_done    : boolean := false;

  -- MAC peripheral boundary (writes above this are MAC, not data memory)
  constant MAC_ADDR_START : unsigned(15 downto 0) := x"FFD0";

  -- Helper: convert slv16 to 4-char lowercase hex string
  function to_hex4(v : std_logic_vector(15 downto 0)) return string is
    variable result : string(1 to 4);
    variable nibble : integer;
    constant hex_chars : string(1 to 16) := "0123456789abcdef";
  begin
    for i in 0 to 3 loop
      nibble := to_integer(unsigned(v(15 - i*4 downto 12 - i*4)));
      result(i+1) := hex_chars(nibble + 1);
    end loop;
    return result;
  end function;

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

  -- Clock, reset, and halt detection
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

      -- Detect HALT instruction (J to self = 0xFFFF)
      if inst = HALT_INST then
        -- Allow a few more cycles for pipeline to drain
        for drain in 0 to 7 loop
          ck <= '1';
          wait for CLK_PERIOD/2;
          ck <= '0';
          wait for CLK_PERIOD/2;
          cycle_count <= cycle_count + 1;
        end loop;
        exit;
      end if;
    end loop;

    sim_done <= true;
    -- One final clock edge to unblock the trace_writer process
    wait for 1 ns;
    ck <= '1';
    wait for CLK_PERIOD/2;
    ck <= '0';
    wait;
  end process;

  -- Trace writer: monitor memory writes and write to trace file
  trace_writer: process
    file trace_fd : text;
    variable l : line;
    variable v_mw_count : integer := 0;
  begin
    -- Wait for reset to complete before opening file
    wait until rst = '0';

    file_open(trace_fd, TRACE_FILE, write_mode);

    -- Write header
    write(l, string'("# anem16-trace v1"));
    writeline(trace_fd, l);
    write(l, string'("# Source: ghdl (anem16pipe)"));
    writeline(trace_fd, l);

    -- Monitor memory writes on every rising edge until done
    loop
      wait until rising_edge(ck);
      exit when sim_done;

      if mem_en = '1' and mem_w = '1' then
        -- Only trace data memory writes, not MAC peripheral
        if unsigned(mem_addr) < MAC_ADDR_START then
          write(l, string'("MW "));
          write(l, to_hex4(mem_addr));
          write(l, string'(" "));
          write(l, to_hex4(data));
          writeline(trace_fd, l);
          v_mw_count := v_mw_count + 1;
        end if;
      end if;
    end loop;

    -- Write END marker
    write(l, string'("END "));
    write(l, v_mw_count);
    writeline(trace_fd, l);

    file_close(trace_fd);

    report "Trace written: " & integer'image(v_mw_count) & " MW events to " & TRACE_FILE
      severity note;

    -- Stop simulation
    std.env.stop;
  end process;

end sim;
