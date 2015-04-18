-------------------------------
--! @file idecode.vhd
--! @brief pipeline instruction decoding unit
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2014
-------------------------------
library ieee;

use ieee.std_logic_1164.all;
use work.instrset.all;
  
entity anem16_idecode is

  generic(instr_size : integer := 16 );
  
  port(mclk       : in std_logic;
       mrst       : in std_logic;

       instruction: in std_logic_vector(instr_size-1 downto 0);
       instr_addr : in std_logic_vector(15 downto 0);

       regbnk_ctl : out std_logic_vector(2 downto 0);
       regbnk_sela : out std_logic_vector(3 downto 0);
       regbnk_selb : out std_logic_vector(3 downto 0);
       regbnk_aout : in std_logic_vector(15 downto 0);
       
       alu_ctl    : out std_logic_vector(2 downto 0);
       alu_shamt  : out std_logic_vector(3 downto 0);
       alu_func   : out std_logic_vector(3 downto 0);

       j_flag     : out std_logic;
       j_dest     : out std_logic_vector(15 downto 0);

       jr_flag    : out std_logic;

       bz_flag   : out std_logic;
       bz_off    : out std_logic_vector(11 downto 0);

       mem_en     : out std_logic;
       mem_w      : out std_logic;
       limmval    : out std_logic_vector(7 downto 0)

    );
end entity;


architecture pipe of anem16_idecode is
alias opcode : std_logic_vector(3 downto 0) is instruction(15 downto 12);
signal alu_ctl_0 : std_logic_vector(2 downto 0);
signal regbnk_ctl_0 : std_logic_vector(2 downto 0);
signal reset_detected : std_logic;
begin
  
  --asynchronous instruction decoding

  --controls ALU in ALU phase
  alu_ctl <= alu_ctl_0 when reset_detected = '0' else
             "000";
  alu_ctl_0 <= "001" when opcode = ANEM_OPCODE_S else
               "010" when opcode = ANEM_OPCODE_R else
               "011" when opcode = ANEM_OPCODE_BZ else
               "100" when opcode = ANEM_OPCODE_SW else
               "100" when opcode = ANEM_OPCODE_LW else
               "000";
  
  alu_shamt <= instruction(7 downto 4) when alu_ctl_0 /= "000" else
               "0000";
  
  alu_func <= instruction(3 downto 0) when alu_ctl_0 /= "000" else
              "0000";

  
  --controls register writing on WB phase
  regbnk_ctl <= regbnk_ctl_0 when reset_detected = '0' else
                "000";
  regbnk_ctl_0 <= "010" when opcode = ANEM_OPCODE_LIU else --LIU INSTRUCTION
                  "011" when opcode = ANEM_OPCODE_LIL else --LIL INSTRUCTION
                  "001" when opcode = ANEM_OPCODE_R else --R TYPE INSTRUCTION
                  "001" when opcode = ANEM_OPCODE_S else --S TYPE INSTRUCTION
                  "100" when opcode = ANEM_OPCODE_LW else --LW INSTRUCTION
                  "101" when opcode = ANEM_OPCODE_JAL else --JAL INSTRUCTION
                  "000";

  regbnk_sela <= instruction(11 downto 8);
  regbnk_selb <= instruction(7 downto 4);

  --unconditional jumps
  j_flag <= '1' when (opcode = ANEM_OPCODE_J or opcode = ANEM_OPCODE_JAL) and reset_detected = '0' else
            '0';
  
  --! @todo this is going to be a relative jump when using J type
  j_dest <= "0000" & instruction(11 downto 0) when opcode = ANEM_OPCODE_J else
            regbnk_aout                       when opcode = ANEM_OPCODE_JR else
            (others=>'0');

  jr_flag <= '1' when opcode = ANEM_OPCODE_JR and reset_detected = '0' else
             '0';

  bz_flag <= '1' when opcode = ANEM_OPCODE_BZ and reset_detected = '0' else
              '0';
  
  bz_off  <= instruction(11 downto 0) when opcode = ANEM_OPCODE_BZ else
              (others=>'0');

  mem_en <= '1' when opcode = ANEM_OPCODE_SW else
            '1' when opcode = ANEM_OPCODE_LW else
            '0' when reset_detected = '1' else
            '0';

  mem_w <=  '1' when opcode = ANEM_OPCODE_SW and reset_detected = '0' else
            '0';

  limmval <= instruction(7 downto 0);

process(mclk,mrst)
begin

  if mrst = '1' then

    reset_detected <= '1';

  elsif rising_edge(mclk) then

    reset_detected <= '0';
    
  end if;
  
end process;
  
end architecture;
