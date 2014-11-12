Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

Entity move is 
  Generic( n : natural := 4 );
  Port( A         : in     std_logic_vector(n downto 1);
        SHAMT     : in     std_logic_vector(4 downto 1);
        MOVE_OP   : in     std_logic_vector(5 downto 1);
        S         : out    std_logic_vector(n downto 1));
End move;

--	      func | Op. Deslocamento
--        10000 |      SHL - deslocamento lógico pra esquerda
--        10001 |      SHR - deslocamento lógico pra direita
--        10010 |      SAR - deslocamento aritmético pra direita
--        10011 |      ROL - rotação pra esquerda
--        10100 |      ROR - rotação pra direita
--comandos=f"SHL"=>"0010 " ,
--			'SHR'=>"0001 " ,
--			'SAR'=>"0000 " ,
--			'ROL'=>' 1000 ' ,
--			'ROR'=>' 0100 ' g

Architecture behavior of move is
Signal zero      : std_logic_vector(n downto 1) := (others => '0');
 Begin
 
 with MOVE_OP select
  
     S <= to_stdLogicVector( to_bitvector(A) sll to_integer( unsigned (SHAMT)) ) when "10010",
          to_stdLogicVector( to_bitvector(A) srl to_integer( unsigned (SHAMT)) ) when "10001",
          to_stdLogicVector( to_bitvector(A) sra to_integer( unsigned (SHAMT)) ) when "10000",
          to_stdLogicVector( to_bitvector(A) rol to_integer( unsigned (SHAMT)) ) when "11000",
          to_stdLogicVector( to_bitvector(A) ror to_integer( unsigned (SHAMT)) ) when "10100",
          zero when others;
          
  end behavior;