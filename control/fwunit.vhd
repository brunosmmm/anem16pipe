-------------------------------
--! @file fwunit.vhd
--! @brief pipeline forwarding unit
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2014
--! @todo verify forwarding cycles
-------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity anem16_fwunit is
  port(reg_sela_wb    : in std_logic_vector(3 downto 0);
       reg_sela_alu   : in std_logic_vector(3 downto 0);
       reg_selb_alu   : in std_logic_vector(3 downto 0);
       reg_sela_mem   : in std_logic_vector(3 downto 0);

       --forwarding enable
       f_alu_alu_a    : out std_logic; --! enable ALU->ALU forwarding, A
       f_alu_alu_b    : out std_logic; --! enable ALU->ALU forwarding, B
       f_mem_alu_a    : out std_logic; --! enable MEM->ALU forwarding, A
       f_mem_alu_b    : out std_logic; --! enable MEM->ALU forwarding, B

       regbnk_write_mem : in std_logic; --! MEM stage will write register
       regbnk_write_wb  : in std_logic; --! WB stage will write register
       mem_enable     : in std_logic;
       aluctl         : in std_logic_vector(2 downto 0) --! ALU operation
       );
end entity;

architecture pipe of anem16_fwunit is
begin

--data hazards
--if destination register of MEM or WB stage matches source register of ALU stage -> forward
  f_alu_alu_a <= '1' when regbnk_write_mem = '1' and reg_sela_mem = reg_sela_alu and reg_sela_alu /= "0000" and reg_sela_mem /= "0000" else
                 '0';
  f_alu_alu_b <= '1' when regbnk_write_mem = '1' and reg_sela_mem = reg_selb_alu and reg_sela_mem /= "0000" and reg_selb_alu /= "0000" else
                 '0';
  f_mem_alu_a <= '1' when regbnk_write_wb = '1' and reg_sela_wb = reg_sela_alu and reg_sela_wb /= "0000" and reg_sela_alu /= "0000" else
                 '0';
  f_mem_alu_b <= '1' when regbnk_write_wb = '1' and reg_sela_wb = reg_selb_alu and reg_sela_wb /= "0000" and reg_selb_alu /= "0000" else
                 '0';

end architecture;
