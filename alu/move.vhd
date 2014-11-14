-----------------------------------
--! @file move.vhd
--! @brief ALU shift unit
-----------------------------------
Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

Entity move is 
  Generic( n : natural := 4 );
  Port( A         : in     std_logic_vector(n downto 1); --! data input
        SHAMT     : in     std_logic_vector(4 downto 1); --! SHift AMounT
        MOVE_OP   : in     std_logic_vector(5 downto 1); --! shift type
        S         : out    std_logic_vector(n downto 1)  --! data output
        );
End move;

--	   func | Shift operation
--        10000 |      SHL - logic left shift
--        10001 |      SHR - logic right shift
--        10010 |      SAR - arithmetic right shift
--        10011 |      ROL - rotate left
--        10100 |      ROR - rotate right
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
