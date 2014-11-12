library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity anem16_hazunit is

  port(mrst      : in std_logic;
       mclk      : in std_logic;
       beqtrue   : in std_logic;
       
       p_stall_if_n   : out std_logic;
       p_stall_id_n   : out std_logic;
       p_stall_alu_n  : out std_logic;
       p_stall_mem_n  : out std_logic;

       --branch hazards
       beq_flag      : in std_logic;

       --data hazards detectors
       mem_en_alu       : in std_logic;
       mem_w_alu            : in std_logic;
       reg_sela_alu      : in std_logic_vector(3 downto 0);
       reg_selb_alu      : in std_logic_vector(3 downto 0);
       next_instruction : in std_logic_vector(15 downto 0);

       reg_sela_wb      : in std_logic_vector(3 downto 0);

       mem_en_id  : in std_logic;
       mem_w_id   : in std_logic;
       reg_sela_id   : in std_logic_vector(3 downto 0);
       reg_selb_id   : in std_logic_vector(3 downto 0)
      
       );

end entity;

architecture pipe of anem16_hazunit is
signal lw_stall_counter : std_logic_vector(1 downto 0);
signal lw_hazard_verify : std_logic;
signal lw_hazard_detect : std_logic;
signal sw_hazard_detect : std_logic;
signal sw_stall_if_n    : std_logic;
signal lw_stall_if_n    : std_logic;
begin

  --p_stall_if_n <= '1';
  p_stall_id_n <= '1';
  p_stall_alu_n <= '1';
  p_stall_mem_n <= '1';

--some instructions after a LW instruction dont actually cause a hazard
  lw_hazard_verify <= '1' when next_instruction(15 downto 12) = "0000" else
                      '1' when next_instruction(15 downto 12) = "0001" else
                      '1' when next_instruction(15 downto 12) = "0111" else
                      '1' when next_instruction(15 downto 12) = "0110" else
                      '1' when next_instruction(15 downto 12) = "0100" else
                      '0';
  
  lw_hazard_detect <= '1' when reg_sela_id = reg_sela_alu else
                      '1' when reg_sela_id = reg_selb_alu else
                      '0';

  --B selector in new instruction and A selector in old
  sw_hazard_detect <= '1' when reg_selb_id = reg_sela_wb else
                      '0';

  sw_stall_if_n <= not  (sw_hazard_detect and mem_en_id and mem_w_id);

  p_stall_if_n <= lw_stall_if_n and sw_stall_if_n;
  
--branch hazards
--beqtrue = 1 , must flush pipeline
  
process(mclk,mrst)
begin

  if mrst = '1' then

    lw_stall_if_n <= '1';
    lw_stall_counter <= "00";

  elsif rising_edge(mclk) then

    if lw_stall_counter /= "00" then

      lw_stall_counter <= std_logic_vector(unsigned(lw_stall_counter) - 1);
      
    elsif mem_en_alu = '1' and mem_w_alu = '0' and lw_hazard_detect = '1' and lw_hazard_verify = '1' then

      --this is a data hazard that cannot be solved by forwarding.
      --insert stalls
      lw_stall_if_n <= '0';
      lw_stall_counter <= "10";

    else

      lw_stall_if_n <= '1'; --stop stalls
      
    end if;

  end if;

end process;
  
end architecture;
