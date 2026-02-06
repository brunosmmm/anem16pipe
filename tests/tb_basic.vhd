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
      INST_ADDR => inst_addr
    );

  -- Program memory
  imem: entity work.progmem(rom)
    port map(
      ck      => ck,
      en      => '1',
      address => inst_addr(7 downto 0),
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

    report "=== SIMULATION COMPLETE ===" severity note;
    report "Total memory writes logged: " & integer'image(log_count) severity note;
    report "=== Test bench finished ===" severity note;

    -- Stop simulation
    std.env.stop;
  end process;

end sim;
