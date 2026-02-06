-------------------------------
--! @file hazunit.vhd
--! @brief pipeline hazards unit
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2014
-------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity anem16_hazunit is

  port(mrst      : in std_logic;
       mclk      : in std_logic;
       bztrue    : in std_logic;
       bhleqtrue : in std_logic;

       p_stall_if_n   : out std_logic;
       p_stall_id_n   : out std_logic;
       p_stall_alu_n  : out std_logic;
       p_stall_mem_n  : out std_logic;

       --LW hazard detection (ALU stage)
       mem_en_alu       : in std_logic;
       mem_w_alu        : in std_logic;
       reg_sela_alu     : in std_logic_vector(3 downto 0);

       --ID stage (dependent instruction)
       reg_sela_id      : in std_logic_vector(3 downto 0);
       reg_selb_id      : in std_logic_vector(3 downto 0);
       mem_en_id        : in std_logic;
       mem_w_id         : in std_logic;
       next_instruction : in std_logic_vector(15 downto 0);

       --SW hazard detection: producer write-back info per stage
       regctl_alu       : in std_logic_vector(2 downto 0);
       reg_sela_mem     : in std_logic_vector(3 downto 0);
       regctl_mem       : in std_logic_vector(2 downto 0);
       reg_sela_wb      : in std_logic_vector(3 downto 0);
       regctl_wb        : in std_logic_vector(2 downto 0)

       );

end entity;

architecture pipe of anem16_hazunit is
signal lw_stall_counter : std_logic_vector(1 downto 0);
signal lw_hazard_verify : std_logic;
signal lw_hazard_detect : std_logic;
signal sw_data_hazard   : std_logic;
signal sw_stall_if_n    : std_logic;
signal lw_stall_if_n    : std_logic;

signal bz_stall_if_n    : std_logic;
signal bz_stall_counter : std_logic_vector(1 downto 0);
begin

  p_stall_id_n <= '1';
  p_stall_alu_n <= '1';
  p_stall_mem_n <= '1';

  --instructions that do NOT read registers cannot cause LW hazard
  lw_hazard_verify <= '0' when next_instruction(15 downto 12) = "0100" else  --LIU
                      '0' when next_instruction(15 downto 12) = "0101" else  --LIL
                      '0' when next_instruction(15 downto 12) = "1111" else  --J
                      '0' when next_instruction(15 downto 12) = "1101" else  --JAL
                      '0' when next_instruction(15 downto 12) = "1000" else  --BZ_X
                      '0' when next_instruction(15 downto 12) = "1001" else  --BZ_T
                      '0' when next_instruction(15 downto 12) = "1010" else  --BZ_N
                      '0' when next_instruction(15 downto 12) = "0110" else  --BHLEQ
                      '1';

  --LW destination matches either source register of dependent instruction
  lw_hazard_detect <= '1' when reg_sela_alu = reg_sela_id and reg_sela_alu /= "0000" else
                      '1' when reg_sela_alu = reg_selb_id and reg_sela_alu /= "0000" else
                      '0';

  --SW data register hazard: SW in ID, producer writing same register in ALU/MEM/WB
  sw_data_hazard <= '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_alu and regctl_alu /= "000" else
                    '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_mem and regctl_mem /= "000" else
                    '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_wb and regctl_wb /= "000" else
                    '0';

  sw_stall_if_n <= not sw_data_hazard;

  p_stall_if_n <= lw_stall_if_n and sw_stall_if_n and bz_stall_if_n;

process(mclk,mrst)
begin

  if mrst = '1' then

    lw_stall_if_n <= '1';
    lw_stall_counter <= "00";

    bz_stall_if_n <= '1';
    bz_stall_counter <= "00";

  elsif rising_edge(mclk) then

    --bz/bhleq stalls
    if bz_stall_counter /= "00"then

      bz_stall_counter <= std_logic_vector(unsigned(bz_stall_counter) - 1);

    elsif bztrue = '1' or bhleqtrue = '1' then

      --hold until resolution
      bz_stall_if_n <= '0';
      bz_stall_counter <= "01";

    else

      --release
      bz_stall_if_n <= '1';

    end if;

    --lw stalls
    if lw_stall_counter /= "00" then

      lw_stall_counter <= std_logic_vector(unsigned(lw_stall_counter) - 1);

    elsif mem_en_alu = '1' and mem_w_alu = '0' and lw_hazard_detect = '1' and lw_hazard_verify = '1' then

      --load-use hazard: stall until LW data available through register bank
      lw_stall_if_n <= '0';
      lw_stall_counter <= "01";

    else

      lw_stall_if_n <= '1';

    end if;

  end if;

end process;

end architecture;
