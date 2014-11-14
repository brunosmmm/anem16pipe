---------------------------
--! @file sum.vhd
--! @brief ALU adder unit
---------------------------
Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.std_logic_arith.all;

Entity sum is 
Generic ( n : natural := 8);
Port ( A, B        : in  std_logic_vector(n downto 1); --! operands
       S           : buffer std_logic_vector(n downto 1); --! data output
       cin         : in  std_logic; --! carry in
       cout        : out std_logic --! carry out
      );
End sum;

Architecture adder of sum is
Signal carry : std_logic_vector(n+1 downto 1);

Begin 
	carry(1) <= cin;
	cout <= carry(n+1);

	carrygen: For i IN 1 to n Generate

           S(i)       <= A(i) xor B(i) xor carry(i);
           carry(i+1) <= ( A(i) and B(i) ) or ( A(i) and carry(i) ) or ( B(i) and carry(i) );
           

	end Generate;

end architecture;           
