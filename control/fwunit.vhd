library ieee;
use ieee.std_logic_1164.all;

entity anem16_fwunit is
  port(reg_sela_wb    : in std_logic_vector(3 downto 0);
       reg_sela_alu   : in std_logic_vector(3 downto 0);
       reg_selb_alu   : in std_logic_vector(3 downto 0);
       reg_sela_mem   : in std_logic_vector(3 downto 0);

       --forwarding enable
       f_alu_alu_a    : out std_logic;
       f_alu_alu_b    : out std_logic;
       f_mem_alu_a    : out std_logic;
       f_mem_alu_b    : out std_logic;

       regbnk_write   : in std_logic;
       mem_enable     : in std_logic;
       aluctl         : in std_logic_vector(2 downto 0)
       );
end entity;

architecture pipe of anem16_fwunit is
signal fw_en : std_logic;
begin

--forwarding can occur with register bank writes or memory operations?
  fw_en <= regbnk_write;
--data hazards
--if reg_sela_wb, reg_selb_wb = reg_sela_id -> RAW
--setup forwarding
  f_alu_alu_a <= '1' when fw_en = '1' and reg_sela_mem = reg_sela_alu and reg_sela_alu /= "0000" and reg_sela_mem /= "0000" and aluctl /= "000" else
                 '0';
  f_alu_alu_b <= '1' when fw_en = '1' and reg_sela_mem = reg_selb_alu and reg_sela_mem /= "0000" and reg_selb_alu /= "0000" and aluctl /= "000" else
                 '0';
  f_mem_alu_a <= '1' when fw_en = '1' and reg_sela_wb = reg_sela_alu and reg_sela_wb /= "0000" and reg_sela_alu /= "0000" and aluctl /= "000" else
                 '0';
  f_mem_alu_b <= '1' when fw_en = '1' and reg_sela_wb = reg_selb_alu and reg_sela_wb /= "0000" and reg_selb_alu /= "0000" and aluctl /= "000" else
                 '0';

end architecture;
