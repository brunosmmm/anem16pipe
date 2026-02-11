---------------------------------------------------------
--! @file uart.vhd
--! @brief UART peripheral with TX/RX and baud generator
--! @author Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
  generic(
    UART_DATA_ADDR   : std_logic_vector := x"FFDB";
    UART_CTRL_ADDR   : std_logic_vector := x"FFDC";
    UART_STATUS_ADDR : std_logic_vector := x"FFDD";
    UART_BAUD_ADDR   : std_logic_vector := x"FFDE"
  );
  port(
    DATA : inout std_logic_vector(15 downto 0);
    ADDR : in std_logic_vector(15 downto 0);
    W    : in std_logic;
    EN   : in std_logic;
    CK   : in std_logic;
    RST  : in std_logic;
    TX   : out std_logic;
    RX   : in std_logic;
    INT  : out std_logic
  );
end entity;

architecture behavioral of uart is

  signal WEN : std_logic;
  signal REN : std_logic;

  -- Address decode
  type reg_sel_t is (SEL_DATA, SEL_CTRL, SEL_STATUS, SEL_BAUD, SEL_NONE);
  signal reg_sel : reg_sel_t;

  -- Registers
  signal ctrl_reg   : std_logic_vector(15 downto 0) := (others => '0');
  signal baud_div   : unsigned(15 downto 0) := (others => '0');

  -- Control aliases
  alias ctrl_txen : std_logic is ctrl_reg(0);
  alias ctrl_rxen : std_logic is ctrl_reg(1);
  alias ctrl_txie : std_logic is ctrl_reg(2);
  alias ctrl_rxie : std_logic is ctrl_reg(3);

  -- Status bits
  signal txrdy   : std_logic := '1';
  signal rxda    : std_logic := '0';
  signal fe_flag : std_logic := '0';
  signal oe_flag : std_logic := '0';

  -- Read data mux
  signal data_out    : std_logic_vector(15 downto 0);
  signal status_read : std_logic_vector(15 downto 0);

  -- TX FSM
  type tx_state_t is (TX_IDLE, TX_START, TX_DATA, TX_STOP);
  signal tx_state    : tx_state_t := TX_IDLE;
  signal tx_shift    : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_bit_cnt  : unsigned(2 downto 0) := (others => '0');
  signal tx_clk_cnt  : unsigned(15 downto 0) := (others => '0');
  signal tx_sub_cnt  : unsigned(3 downto 0) := (others => '0');
  signal tx_out      : std_logic := '1';

  -- RX FSM
  type rx_state_t is (RX_IDLE, RX_START, RX_DATA, RX_STOP);
  signal rx_state    : rx_state_t := RX_IDLE;
  signal rx_shift    : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_data_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_bit_cnt  : unsigned(2 downto 0) := (others => '0');
  signal rx_clk_cnt  : unsigned(15 downto 0) := (others => '0');
  signal rx_sub_cnt  : unsigned(3 downto 0) := (others => '0');

  -- RX synchronizer
  signal rx_sync : std_logic_vector(1 downto 0) := "11";
  signal rx_s    : std_logic;  -- synchronized RX

  -- TX/RX baud tick: fires every (baud_div+1) clocks = 1/16th of a bit period
  signal tx_tick : std_logic;
  signal rx_tick : std_logic;

begin

  WEN <= W and EN;
  REN <= (not W) and EN;

  -- Address decode
  reg_sel <= SEL_DATA   when ADDR = UART_DATA_ADDR   else
             SEL_CTRL   when ADDR = UART_CTRL_ADDR   else
             SEL_STATUS when ADDR = UART_STATUS_ADDR else
             SEL_BAUD   when ADDR = UART_BAUD_ADDR   else
             SEL_NONE;

  -- Synchronized RX
  rx_s <= rx_sync(1);

  -- Status register assembly
  status_read(0)            <= txrdy;
  status_read(1)            <= rxda;
  status_read(2)            <= fe_flag;
  status_read(3)            <= oe_flag;
  status_read(15 downto 4)  <= (others => '0');

  -- Read data mux
  data_out <= x"00" & rx_data_reg          when reg_sel = SEL_DATA   else
              ctrl_reg                     when reg_sel = SEL_CTRL   else
              status_read                  when reg_sel = SEL_STATUS else
              std_logic_vector(baud_div)   when reg_sel = SEL_BAUD   else
              (others => '0');

  -- Tristate bus
  DATA <= data_out when REN = '1' and reg_sel /= SEL_NONE else (others => 'Z');

  -- TX output
  TX <= tx_out;

  -- Interrupt
  INT <= (txrdy and ctrl_txie) or (rxda and ctrl_rxie);

  -- Main clocked process
  process(CK, RST)
  begin
    if RST = '1' then
      ctrl_reg    <= (others => '0');
      baud_div    <= (others => '0');
      txrdy       <= '1';
      rxda        <= '0';
      fe_flag     <= '0';
      oe_flag     <= '0';
      tx_state    <= TX_IDLE;
      tx_shift    <= (others => '0');
      tx_bit_cnt  <= (others => '0');
      tx_clk_cnt  <= (others => '0');
      tx_sub_cnt  <= (others => '0');
      tx_out      <= '1';
      rx_state    <= RX_IDLE;
      rx_shift    <= (others => '0');
      rx_data_reg <= (others => '0');
      rx_bit_cnt  <= (others => '0');
      rx_clk_cnt  <= (others => '0');
      rx_sub_cnt  <= (others => '0');
      rx_sync     <= "11";
    elsif rising_edge(CK) then

      -- RX synchronizer (2-stage)
      rx_sync <= rx_sync(0) & RX;

      -- =================== Register writes ===================
      if WEN = '1' then
        case reg_sel is
          when SEL_DATA =>
            if ctrl_txen = '1' and txrdy = '1' then
              tx_shift   <= DATA(7 downto 0);
              txrdy      <= '0';
              tx_state   <= TX_START;
              tx_clk_cnt <= (others => '0');
              tx_sub_cnt <= (others => '0');
              tx_bit_cnt <= (others => '0');
            end if;
          when SEL_CTRL =>
            ctrl_reg <= DATA;
          when SEL_STATUS =>
            -- W1C for FE and OE (bits 2,3)
            if DATA(2) = '1' then fe_flag <= '0'; end if;
            if DATA(3) = '1' then oe_flag <= '0'; end if;
          when SEL_BAUD =>
            baud_div <= unsigned(DATA);
          when SEL_NONE =>
            null;
        end case;
      end if;

      -- Clear RXDA on DATA read
      if REN = '1' and reg_sel = SEL_DATA then
        rxda <= '0';
      end if;

      -- =================== TX FSM ===================
      -- Baud tick: every (baud_div+1) clocks = one 16x sub-tick
      -- One bit = 16 sub-ticks
      case tx_state is
        when TX_IDLE =>
          tx_out <= '1';

        when TX_START =>
          tx_out <= '0';  -- Start bit = 0
          if tx_clk_cnt >= baud_div then
            tx_clk_cnt <= (others => '0');
            if tx_sub_cnt = x"F" then
              tx_sub_cnt <= (others => '0');
              -- Start bit done, move to data
              tx_state <= TX_DATA;
              tx_bit_cnt <= (others => '0');
            else
              tx_sub_cnt <= tx_sub_cnt + 1;
            end if;
          else
            tx_clk_cnt <= tx_clk_cnt + 1;
          end if;

        when TX_DATA =>
          tx_out <= tx_shift(0);  -- LSB first
          if tx_clk_cnt >= baud_div then
            tx_clk_cnt <= (others => '0');
            if tx_sub_cnt = x"F" then
              tx_sub_cnt <= (others => '0');
              -- Bit done, shift right
              tx_shift <= '0' & tx_shift(7 downto 1);
              if tx_bit_cnt = "111" then
                -- All 8 bits sent
                tx_state <= TX_STOP;
              else
                tx_bit_cnt <= tx_bit_cnt + 1;
              end if;
            else
              tx_sub_cnt <= tx_sub_cnt + 1;
            end if;
          else
            tx_clk_cnt <= tx_clk_cnt + 1;
          end if;

        when TX_STOP =>
          tx_out <= '1';  -- Stop bit = 1
          if tx_clk_cnt >= baud_div then
            tx_clk_cnt <= (others => '0');
            if tx_sub_cnt = x"F" then
              tx_sub_cnt <= (others => '0');
              -- Stop bit done
              tx_state <= TX_IDLE;
              txrdy <= '1';
            else
              tx_sub_cnt <= tx_sub_cnt + 1;
            end if;
          else
            tx_clk_cnt <= tx_clk_cnt + 1;
          end if;
      end case;

      -- =================== RX FSM ===================
      case rx_state is
        when RX_IDLE =>
          if ctrl_rxen = '1' and rx_s = '0' then
            -- Falling edge detected (start bit)
            rx_state   <= RX_START;
            rx_clk_cnt <= (others => '0');
            rx_sub_cnt <= (others => '0');
          end if;

        when RX_START =>
          -- Wait to mid-bit of start (8 sub-ticks)
          if rx_clk_cnt >= baud_div then
            rx_clk_cnt <= (others => '0');
            if rx_sub_cnt = x"7" then
              -- Mid-bit of start: verify still low
              if rx_s = '0' then
                rx_sub_cnt <= (others => '0');
                rx_state   <= RX_DATA;
                rx_bit_cnt <= (others => '0');
                rx_shift   <= (others => '0');
              else
                -- False start
                rx_state <= RX_IDLE;
              end if;
            else
              rx_sub_cnt <= rx_sub_cnt + 1;
            end if;
          else
            rx_clk_cnt <= rx_clk_cnt + 1;
          end if;

        when RX_DATA =>
          -- Sample at mid-bit (every 16 sub-ticks from last mid-bit)
          if rx_clk_cnt >= baud_div then
            rx_clk_cnt <= (others => '0');
            if rx_sub_cnt = x"F" then
              rx_sub_cnt <= (others => '0');
              -- Sample data bit (LSB first)
              rx_shift <= rx_s & rx_shift(7 downto 1);
              if rx_bit_cnt = "111" then
                rx_state <= RX_STOP;
              else
                rx_bit_cnt <= rx_bit_cnt + 1;
              end if;
            else
              rx_sub_cnt <= rx_sub_cnt + 1;
            end if;
          else
            rx_clk_cnt <= rx_clk_cnt + 1;
          end if;

        when RX_STOP =>
          -- Wait for mid-bit of stop
          if rx_clk_cnt >= baud_div then
            rx_clk_cnt <= (others => '0');
            if rx_sub_cnt = x"F" then
              rx_sub_cnt <= (others => '0');
              rx_state <= RX_IDLE;
              if rx_s = '1' then
                -- Valid stop bit
                rx_data_reg <= rx_shift;
                if rxda = '1' then
                  oe_flag <= '1';  -- Overrun
                end if;
                rxda <= '1';
              else
                -- Framing error
                fe_flag <= '1';
              end if;
            else
              rx_sub_cnt <= rx_sub_cnt + 1;
            end if;
          else
            rx_clk_cnt <= rx_clk_cnt + 1;
          end if;
      end case;

    end if;
  end process;

end behavioral;
