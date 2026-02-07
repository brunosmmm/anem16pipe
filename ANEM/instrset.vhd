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
  constant ANEM_OPCODE_J   : std_logic_vector(3 downto 0) := "1111";
  constant ANEM_OPCODE_JAL : std_logic_vector(3 downto 0) := "1101";
  constant ANEM_OPCODE_BZ_X: std_logic_vector(3 downto 0) := "1000";
  constant ANEM_OPCODE_BZ_T: std_logic_vector(3 downto 0) := "1001";
  constant ANEM_OPCODE_BZ_N: std_logic_vector(3 downto 0) := "1010";
  constant ANEM_OPCODE_JR  : std_logic_vector(3 downto 0) := "1100";
  constant ANEM_OPCODE_SW  : std_logic_vector(3 downto 0) := "0010";
  constant ANEM_OPCODE_LW  : std_logic_vector(3 downto 0) := "0011";
  constant ANEM_OPCODE_LIU : std_logic_vector(3 downto 0) := "0100";
  constant ANEM_OPCODE_LIL : std_logic_vector(3 downto 0) := "0101";
  constant ANEM_OPCODE_M1  : std_logic_vector(3 downto 0) := "1110";
  constant ANEM_OPCODE_BHLEQ : std_logic_vector(3 downto 0) := "0110";
  constant ANEM_OPCODE_STK  : std_logic_vector(3 downto 0) := "0111";
  constant ANEM_OPCODE_ADDI : std_logic_vector(3 downto 0) := "1011";
  --STK functions
  constant ANEM_STKFUNC_PUSH : std_logic_vector(3 downto 0) := "0000";
  constant ANEM_STKFUNC_POP  : std_logic_vector(3 downto 0) := "0001";
  constant ANEM_STKFUNC_SPRD : std_logic_vector(3 downto 0) := "0010";
  constant ANEM_STKFUNC_SPWR : std_logic_vector(3 downto 0) := "0011";
  --R functions
  constant ANEM_RFUNC_AND  : std_logic_vector(4 downto 0) := "00000";
  constant ANEM_RFUNC_OR   : std_logic_vector(4 downto 0) := "00001";
  constant ANEM_RFUNC_ADD  : std_logic_vector(4 downto 0) := "00010";
  constant ANEM_RFUNC_MUL  : std_logic_vector(4 downto 0) := "00011";
  constant ANEM_RFUNC_SUB  : std_logic_vector(4 downto 0) := "00110";
  constant ANEM_RFUNC_SLT  : std_logic_vector(4 downto 0) := "00111"; 
  constant ANEM_RFUNC_NOR  : std_logic_vector(4 downto 0) := "01100";
  constant ANEM_RFUNC_XOR  : std_logic_vector(4 downto 0) := "01111";
  constant ANEM_RFUNC_SGT  : std_logic_vector(4 downto 0) := "01000";
  --! @todo put S functions here
  --M1 functions
  constant ANEM_M1FUNC_LHL : std_logic_vector(3 downto 0) := "0000";
  constant ANEM_M1FUNC_LHH : std_logic_vector(3 downto 0) := "0001";
  constant ANEM_M1FUNC_LLL : std_logic_vector(3 downto 0) := "0010";
  constant ANEM_M1FUNC_LLH : std_logic_vector(3 downto 0) := "0011";
  constant ANEM_M1FUNC_AIS : std_logic_vector(3 downto 0) := "0100";
  constant ANEM_M1FUNC_AIH : std_logic_vector(3 downto 0) := "0101";
  constant ANEM_M1FUNC_AIL : std_logic_vector(3 downto 0) := "0110";
  constant ANEM_M1FUNC_MFHI : std_logic_vector(3 downto 0) := "0111";
  constant ANEM_M1FUNC_MFLO : std_logic_vector(3 downto 0) := "1000";
  constant ANEM_M1FUNC_MTHI : std_logic_vector(3 downto 0) := "1001";
  constant ANEM_M1FUNC_MTLO : std_logic_vector(3 downto 0) := "1010";
  --Interrupt/Exception
  constant ANEM_M1FUNC_SYSCALL : std_logic_vector(3 downto 0) := "1011";
  constant ANEM_M1FUNC_M4      : std_logic_vector(3 downto 0) := "1100";
  constant ANEM_M4SUB_RETI  : std_logic_vector(3 downto 0) := "0000";
  constant ANEM_M4SUB_EI    : std_logic_vector(3 downto 0) := "0001";
  constant ANEM_M4SUB_DI    : std_logic_vector(3 downto 0) := "0010";
  constant ANEM_M4SUB_MFEPC : std_logic_vector(3 downto 0) := "0011";
  constant ANEM_M4SUB_MFECA : std_logic_vector(3 downto 0) := "0100";
  constant ANEM_M4SUB_MTEPC : std_logic_vector(3 downto 0) := "0101";
  constant ANEM_EXC_VECTOR  : std_logic_vector(15 downto 0) := x"0002";

end package;
