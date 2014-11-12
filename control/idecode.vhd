
library ieee;

use ieee.std_logic_1164.all;

entity anem16_idecode is

  generic(instr_size : integer := 16 );
  
  port(mclk       : in std_logic;
       mrst       : in std_logic;

       instruction: in std_logic_vector(instr_size-1 downto 0);

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

       beq_flag   : out std_logic;
       beq_off    : out std_logic_vector(3 downto 0);

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
  alu_ctl_0 <= "001" when opcode = "0000" else
               "010" when opcode = "0001" else
               "011" when opcode = "0110" else
               "100" when opcode = "0100" else
               "100" when opcode = "0101" else
               "000";
  
  alu_shamt <= instruction(7 downto 4) when alu_ctl_0 /= "000" else
               "0000";
  
  alu_func <= instruction(3 downto 0) when alu_ctl_0 /= "000" else
              "0000";

  
  --controls register writing on WB phase
  regbnk_ctl <= regbnk_ctl_0 when reset_detected = '0' else
                "000";
  regbnk_ctl_0 <= "010" when opcode = "1100" else --LIU INSTRUCTION
                  "011" when opcode = "1101" else --LIL INSTRUCTION
                  "001" when opcode = "0000" else --R TYPE INSTRUCTION
                  "001" when opcode = "0001" else --S TYPE INSTRUCTION
                  "100" when opcode = "0101" else --LW INSTRUCTION
                  "000";

  regbnk_sela <= instruction(11 downto 8);
  regbnk_selb <= instruction(7 downto 4);

  --unconditional jumps
  j_flag <= '1' when opcode = "1000" and reset_detected = '0' else
            '0';
  
  j_dest <= "0000" & instruction(11 downto 0) when opcode = "1000" else
            regbnk_aout                       when opcode = "0111" else
            (others=>'0');

  jr_flag <= '1' when opcode = "0111" and reset_detected = '0' else
             '0';

  beq_flag <= '1' when opcode = "0110" and reset_detected = '0' else
              '0';
  beq_off  <= instruction(3 downto 0) when opcode = "0110" else
              "0000";

  mem_en <= '1' when opcode = "0100" else
            '1' when opcode = "0101" else
            '0' when reset_detected = '1' else
            '0';

  mem_w <=  '1' when opcode = "0100" and reset_detected = '0' else
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
