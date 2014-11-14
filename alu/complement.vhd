--------------------------------
--! @file complement.vhd
--! @brief ALU complement unit
--------------------------------
Library ieee;
Use ieee.std_logic_1164.all;

Entity complement is 
    Generic ( n : natural := 8);
    Port ( B    : in  std_logic_vector(n downto 1);
           S    : out std_logic_vector(n downto 1));
End complement;

Architecture sub of complement is 

signal nB   : std_logic_vector(n downto 1);

Begin
  
   nB <= not B;    

   c1 : entity work.sum(adder) Generic Map( n ) Port Map ( nB, (others => '0'), S, '1' ,OPEN);

end sub;
