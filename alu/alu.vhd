-- '0'&FUNC
--comandos func
--			"ADD"=>"0010 " ,
--			'SUB'=>"0110 " ,
--			'OR' =>' 0001 ' ,
--			'AND'=>"0000 " ,
--			'XOR'=>' 1111 ' ,
--			'NOR'=>' 1100 ' ,
--			'SLT '=>' 0111 '
-- '1'&FUNC
--comandos func
--          "SHL"=>"0010 " ,
--			'SHR'=>"0001 " ,
--			'SAR'=>"0000 " ,
--			'ROL'=>' 1000 ' ,
--			'ROR'=>' 0100 '

Library ieee;
Use ieee.std_logic_1164.all;

Entity Ula is 
  Generic( n : natural := 16 );
  Port( ULA_A,ULA_B    : in     std_logic_vector(n downto 1);
        SHAMT          : in     std_logic_vector(4 downto 1);        -- nº de deslocamentos
        ULA_OP   	     :  in     std_logic_vector(3 downto 1);
        FUNC           : in     std_logic_vector(4 downto 1);
        Z              : out    std_logic;
        ULA_OUT        : buffer std_logic_vector(n downto 1));
End Ula;

Architecture behavior of Ula is 

Signal comp_B    : std_logic_vector(n downto 1);
Signal aux_B     : std_logic_vector(n downto 1);
Signal aux_A     : std_logic_vector(n downto 1);
Signal ULA_CONT  : std_logic_vector(5 downto 1);        -- OPCODE
Signal aux_S     : std_logic_vector(n downto 1);
Signal aux_move  : std_logic_vector(n downto 1);
Signal zero      : std_logic_vector(n downto 1) := (others => '0');
Signal zero2     : std_logic_vector(n-4 downto 1) := (others => '0');
Signal compara   : std_logic_vector(n downto 1);


Component complemento is 

    Generic ( n : natural := 8);
    Port ( B    : in  std_logic_vector(n downto 1);
           S    : out std_logic_vector(n downto 1));
 
End Component;

Component soma is 

    Generic ( n : natural := 8);
    Port ( A, B        : in  std_logic_vector(n downto 1);
           S           : out std_logic_vector(n downto 1);
           cin         : in  std_logic;
           cout    : out std_logic);
           
End Component;

Component move is 
  Generic( n : natural := 8 );
  Port( A         : in     std_logic_vector(n downto 1);
        SHAMT     : in     std_logic_vector(4 downto 1);
        MOVE_OP   : in     std_logic_vector(5 downto 1);
        S         : out    std_logic_vector(n downto 1));
End component;

Begin
--	ULA_OP <= "001"; -- ULA recebe operação tipo R (aritmetico)
--	ULA_OP <= "010"; -- ULA recebe operação tipo S (shift)
--  ULA_OP <= "000"; -- ULA não realiza nenhuma operação
--  ULA_OP <= "011"; -- ULA realiza BEQ
--  ULA_OP <= "100"; -- ULA soma OFFSET+(conteúdo de registrador)

with ULA_OP select
      ULA_CONT <= '0'&func when "001",
                  '1'&func when "010",
                  "00110"  when "011",
                  "11111"  when others;
                       
  aux_B <= comp_B when ULA_CONT = "00110" else
           ULA_B;
  aux_A <= zero2&func when ULA_OP = "100" else
           ULA_A;

  Z <= '1' when ULA_OUT = zero else
       '0' ;

-- definição de SLT:
-- se A < B:       saída = 000....01
-- caso contrário: saída = 000....00   
  compara <= zero(n-1 downto 1)&'1' when (ULA_A < ULA_B) else
		     zero;

  rotulo1: complemento Generic Map ( n ) Port Map (ULA_B,comp_B);
  
  rotulo2: soma Generic Map ( n ) Port Map (aux_A, aux_B, aux_S, '0', OPEN);

  rotulo3: move Generic Map ( n ) Port Map (ULA_A, SHAMT, ULA_CONT, aux_move);


  with ULA_CONT select 
  
  ULA_OUT <=  aux_S       when "00010" | "00110" | "11111",
			  aux_move          when "10010" | "10001" | "10000" | "11000" |"10100",
			  (ULA_A OR ULA_B)  when "00001",
			  (ULA_A AND ULA_B) when "00000", 
			  (ULA_A XOR ULA_B) when "01111",
			  (ULA_A NOR ULA_B) when "01100",
			  compara           when "00111",
			  zero               when others; -- mtos latchs
  
End behavior;
