---------------------------------------------------------
--! @file gpio.vhd
--! @brief General Purpose I/O peripheral
--! @author Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio is
  generic(
    PORTA_DATA_ADDR : std_logic_vector := x"FFD0";
    PORTA_DIR_ADDR  : std_logic_vector := x"FFD1";
    PORTB_DATA_ADDR : std_logic_vector := x"FFD2";
    PORTB_DIR_ADDR  : std_logic_vector := x"FFD3"
  );
  port(
    DATA : inout std_logic_vector(15 downto 0);
    ADDR : in std_logic_vector(15 downto 0);
    W    : in std_logic;
    EN   : in std_logic;
    CK   : in std_logic;
    RST  : in std_logic;
    PORTA_PINS : inout std_logic_vector(15 downto 0);
    PORTB_PINS : inout std_logic_vector(15 downto 0);
    INT  : out std_logic
  );
end entity;

architecture behavioral of gpio is

  signal WEN : std_logic;
  signal REN : std_logic;

  -- Registers
  signal porta_data_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal porta_dir_reg  : std_logic_vector(15 downto 0) := (others => '0');
  signal portb_data_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal portb_dir_reg  : std_logic_vector(15 downto 0) := (others => '0');

  -- Address decode
  type reg_sel_t is (SEL_PORTA_DATA, SEL_PORTA_DIR, SEL_PORTB_DATA, SEL_PORTB_DIR, SEL_NONE);
  signal reg_sel : reg_sel_t;

  -- Read data mux
  signal data_out : std_logic_vector(15 downto 0);

  -- Readback: output bits return latch, input bits return pin state
  signal porta_readback : std_logic_vector(15 downto 0);
  signal portb_readback : std_logic_vector(15 downto 0);

begin

  INT <= '0';

  WEN <= W and EN;
  REN <= (not W) and EN;

  -- Address decode
  reg_sel <= SEL_PORTA_DATA when ADDR = PORTA_DATA_ADDR else
             SEL_PORTA_DIR  when ADDR = PORTA_DIR_ADDR  else
             SEL_PORTB_DATA when ADDR = PORTB_DATA_ADDR else
             SEL_PORTB_DIR  when ADDR = PORTB_DIR_ADDR  else
             SEL_NONE;

  -- Pin drive: per-bit tristate
  -- Readback: output bits return latch, input bits return pin state
  -- Resolve non-logic pin values (Z/U/X) to '0' (weak pull-down) to avoid metavalues
  pin_a_gen: for i in 0 to 15 generate
    PORTA_PINS(i) <= porta_data_reg(i) when porta_dir_reg(i) = '1' else 'Z';
    porta_readback(i) <= porta_data_reg(i) when porta_dir_reg(i) = '1' else
                         PORTA_PINS(i)     when PORTA_PINS(i) = '0' or PORTA_PINS(i) = '1' else
                         '0';
  end generate;

  pin_b_gen: for i in 0 to 15 generate
    PORTB_PINS(i) <= portb_data_reg(i) when portb_dir_reg(i) = '1' else 'Z';
    portb_readback(i) <= portb_data_reg(i) when portb_dir_reg(i) = '1' else
                         PORTB_PINS(i)     when PORTB_PINS(i) = '0' or PORTB_PINS(i) = '1' else
                         '0';
  end generate;

  -- Read data mux
  data_out <= porta_readback when reg_sel = SEL_PORTA_DATA else
              porta_dir_reg  when reg_sel = SEL_PORTA_DIR  else
              portb_readback when reg_sel = SEL_PORTB_DATA else
              portb_dir_reg  when reg_sel = SEL_PORTB_DIR  else
              (others => '0');

  -- Tristate bus
  DATA <= data_out when REN = '1' and reg_sel /= SEL_NONE else (others => 'Z');

  -- Register writes
  process(CK, RST)
  begin
    if RST = '1' then
      porta_data_reg <= (others => '0');
      porta_dir_reg  <= (others => '0');
      portb_data_reg <= (others => '0');
      portb_dir_reg  <= (others => '0');
    elsif rising_edge(CK) then
      if WEN = '1' then
        case reg_sel is
          when SEL_PORTA_DATA => porta_data_reg <= DATA;
          when SEL_PORTA_DIR  => porta_dir_reg  <= DATA;
          when SEL_PORTB_DATA => portb_data_reg <= DATA;
          when SEL_PORTB_DIR  => portb_dir_reg  <= DATA;
          when SEL_NONE       => null;
        end case;
      end if;
    end if;
  end process;

end behavioral;
