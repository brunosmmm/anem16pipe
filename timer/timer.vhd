---------------------------------------------------------
--! @file timer.vhd
--! @brief 16-bit Timer peripheral with prescaler and compare
--! @author Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
  generic(
    TMR_COUNT_ADDR   : std_logic_vector := x"FFD7";
    TMR_CTRL_ADDR    : std_logic_vector := x"FFD8";
    TMR_STATUS_ADDR  : std_logic_vector := x"FFD9";
    TMR_COMPARE_ADDR : std_logic_vector := x"FFDA"
  );
  port(
    DATA : inout std_logic_vector(15 downto 0);
    ADDR : in std_logic_vector(15 downto 0);
    W    : in std_logic;
    EN   : in std_logic;
    CK   : in std_logic;
    RST  : in std_logic;
    INT  : out std_logic
  );
end entity;

architecture behavioral of timer is

  signal WEN : std_logic;
  signal REN : std_logic;

  -- Registers
  signal counter     : unsigned(15 downto 0) := (others => '0');
  signal reload_val  : unsigned(15 downto 0) := (others => '0');
  signal ctrl_reg    : std_logic_vector(15 downto 0) := (others => '0');
  signal status_reg  : std_logic_vector(15 downto 0) := (others => '0');
  signal compare_reg : unsigned(15 downto 0) := (others => '0');

  -- Prescaler
  signal psc_counter : unsigned(7 downto 0) := (others => '0');
  signal psc_tick    : std_logic;

  -- Control bit aliases
  alias ctrl_en  : std_logic is ctrl_reg(0);
  alias ctrl_psc : std_logic_vector(1 downto 0) is ctrl_reg(2 downto 1);
  alias ctrl_ar  : std_logic is ctrl_reg(3);
  alias ctrl_oie : std_logic is ctrl_reg(4);
  alias ctrl_cie : std_logic is ctrl_reg(5);

  -- Status bit aliases
  alias status_ovf : std_logic is status_reg(0);
  alias status_cmf : std_logic is status_reg(1);

  -- Address decode
  type reg_sel_t is (SEL_COUNT, SEL_CTRL, SEL_STATUS, SEL_COMPARE, SEL_NONE);
  signal reg_sel : reg_sel_t;

  -- Read data mux
  signal data_out : std_logic_vector(15 downto 0);

  -- Prescaler divisor
  signal psc_top : unsigned(7 downto 0);

begin

  WEN <= W and EN;
  REN <= (not W) and EN;

  -- Address decode
  reg_sel <= SEL_COUNT   when ADDR = TMR_COUNT_ADDR   else
             SEL_CTRL    when ADDR = TMR_CTRL_ADDR    else
             SEL_STATUS  when ADDR = TMR_STATUS_ADDR  else
             SEL_COMPARE when ADDR = TMR_COMPARE_ADDR else
             SEL_NONE;

  -- Prescaler divisor lookup
  psc_top <= x"00" when ctrl_psc = "00" else  -- /1
             x"03" when ctrl_psc = "01" else  -- /4
             x"0F" when ctrl_psc = "10" else  -- /16
             x"FF";                            -- /256

  -- Read data mux
  data_out <= std_logic_vector(counter)    when reg_sel = SEL_COUNT   else
              ctrl_reg                     when reg_sel = SEL_CTRL    else
              status_reg                   when reg_sel = SEL_STATUS  else
              std_logic_vector(compare_reg) when reg_sel = SEL_COMPARE else
              (others => '0');

  -- Tristate bus
  DATA <= data_out when REN = '1' and reg_sel /= SEL_NONE else (others => 'Z');

  -- Interrupt output
  INT <= (status_ovf and ctrl_oie) or (status_cmf and ctrl_cie);

  -- Main process
  process(CK, RST)
    variable v_status_clear : std_logic_vector(15 downto 0);
  begin
    if RST = '1' then
      counter     <= (others => '0');
      reload_val  <= (others => '0');
      ctrl_reg    <= (others => '0');
      status_reg  <= (others => '0');
      compare_reg <= (others => '0');
      psc_counter <= (others => '0');
    elsif rising_edge(CK) then

      -- Register writes (bus writes take priority)
      if WEN = '1' then
        case reg_sel is
          when SEL_COUNT =>
            counter    <= unsigned(DATA);
            reload_val <= unsigned(DATA);
          when SEL_CTRL =>
            ctrl_reg <= DATA;
          when SEL_STATUS =>
            -- Write-1-to-clear: clear bits where DATA has '1'
            v_status_clear := status_reg and (not DATA);
            status_reg <= v_status_clear;
          when SEL_COMPARE =>
            compare_reg <= unsigned(DATA);
          when SEL_NONE =>
            null;
        end case;
      end if;

      -- Timer counting (only when enabled and not being written)
      if ctrl_en = '1' and not (WEN = '1' and reg_sel = SEL_COUNT) then
        if psc_counter >= psc_top then
          psc_counter <= (others => '0');

          -- Counter increment
          if counter = x"FFFF" then
            -- Overflow
            status_ovf <= '1';
            if ctrl_ar = '1' then
              counter <= reload_val;
            else
              counter <= (others => '0');
              ctrl_en <= '0';
            end if;
          else
            counter <= counter + 1;

            -- Compare match (check against next value)
            if counter + 1 = compare_reg then
              status_cmf <= '1';
            end if;
          end if;
        else
          psc_counter <= psc_counter + 1;
        end if;
      end if;

    end if;
  end process;

end behavioral;
