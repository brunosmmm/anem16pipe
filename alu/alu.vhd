-----------------------------------
--! @file alu.vhd
--! @brief arithmetic and logic unit
------------------------------------
-- '0'&FUNC - Arith / logic operations
--FUNC Operations
--"ADD"=>"0010 " ,
--'SUB'=>"0110 " ,
--'OR' =>' 0001 ' ,
--'AND'=>"0000 " ,
--'XOR'=>' 1111 ' ,
--'NOR'=>' 1100 ' ,
--'SLT '=>' 0111 '
-- '1'&FUNC - Shift operations
--'SHL'=>"0010 " ,
--'SHR'=>"0001 " ,
--'SAR'=>"0000 " ,
--'ROL'=>' 1000 ' ,
--'ROR'=>' 0100 '

Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

Entity ALU is 
  Generic( n : natural := 16 );
  Port( ALU_A,ALU_B    : in     std_logic_vector(n downto 1);  --! Operands
        SHAMT          : in     std_logic_vector(4 downto 1);  --! SHift AMounT
        ALU_OP         : in     std_logic_vector(3 downto 1);  --! ALU function
        FUNC           : in     std_logic_vector(4 downto 1);  --! Operation
        Z              : out    std_logic;                     --! Zero flag output
        ALU_OUT        : buffer std_logic_vector(n downto 1)); --! Data output
End ALU;

Architecture behavior of ALU is 

Signal comp_B    : std_logic_vector(n downto 1);
Signal aux_B     : std_logic_vector(n downto 1);
Signal aux_A     : std_logic_vector(n downto 1);
Signal ALU_CONT  : std_logic_vector(5 downto 1);        -- OPCODE
Signal aux_S     : std_logic_vector(n downto 1);
Signal aux_move  : std_logic_vector(n downto 1);
Signal zero      : std_logic_vector(n downto 1) := (others => '0');
Signal zero2     : std_logic_vector(n-4 downto 1) := (others => '0');
Signal compare   : std_logic_vector(n downto 1);
Signal compare_gt: std_logic_vector(n downto 1);

Begin
--  ALU_OP <= "001"; -- ALU makes type R operation (arithmetic)
--  ALU_OP <= "010"; -- ALU makes type S operation (shift)
--  ALU_OP <= "000"; -- ALU does not operate
--  ALU_OP <= "011"; -- ALU calculates BEQ
--  ALU_OP <= "100"; -- ALU sums OFFSET+(register contents)

with ALU_OP select
      ALU_CONT <= '0'&func when "001",
                  '1'&func when "010",
                  "00110"  when "011",
                  "11111"  when others;
                       
  aux_B <= comp_B when ALU_CONT = "00110" else
           ALU_B;
  aux_A <= zero2&func when ALU_OP = "100" else
           ALU_A;

  Z <= '1' when ALU_OUT = zero else
       '0' ;

-- SLT (signed): if A < B: out = 000....01, else: out = 000....00
  compare <= zero(n-1 downto 1)&'1' when (signed(ALU_A) < signed(ALU_B)) else
		     zero;

-- SGT (signed): if A > B: out = 000....01, else: out = 000....00
  compare_gt <= zero(n-1 downto 1)&'1' when (signed(ALU_A) > signed(ALU_B)) else
		     zero;

  comp: entity work.complement(sub) Generic Map ( n ) Port Map (ALU_B,comp_B);
  
  add: entity work.sum(adder) Generic Map ( n ) Port Map (aux_A, aux_B, aux_S, '0', OPEN);

  shift: entity work.move(behavior) Generic Map ( n ) Port Map (ALU_A, SHAMT, ALU_CONT, aux_move);


  with ALU_CONT select 
  
  ALU_OUT <=  aux_S       when "00010" | "00110" | "11111",
			  aux_move          when "10010" | "10001" | "10000" | "11000" |"10100",
			  (ALU_A OR ALU_B)  when "00001",
			  (ALU_A AND ALU_B) when "00000", 
			  (ALU_A XOR ALU_B) when "01111",
			  (ALU_A NOR ALU_B) when "01100",
			  compare           when "00111",
			  compare_gt        when "01000",
			  zero               when others;
  
End behavior;
