----------------------------------------------
--! @file instrset.vhd
--! @brief instruction set constants - OPCODES
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @since 12/05/2014
-----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package instrset is
  constant ANEM_OPCODE_R   : std_logic_vector(3 downto 0) := "0000";
  constant ANEM_OPCODE_S   : std_logic_vector(3 downto 0) := "0001";
  constant ANEM_OPCODE_J   : std_logic_vector(3 downto 0) := "1000";
  constant ANEM_OPCODE_JAL : std_logic_vector(3 downto 0) := "1001";
  constant ANEM_OPCODE_BZ  : std_logic_vector(3 downto 0) := "0110";
  constant ANEM_OPCODE_JR  : std_logic_vector(3 downto 0) := "0111";
  constant ANEM_OPCODE_SW  : std_logic_vector(3 downto 0) := "0100";
  constant ANEM_OPCODE_LW  : std_logic_vector(3 downto 0) := "0101";
  constant ANEM_OPCODE_LIU : std_logic_vector(3 downto 0) := "1100";
  constant ANEM_OPCODE_LIL : std_logic_vector(3 downto 0) := "1101";

end package;
