Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.std_logic_arith.all;

Entity soma is 
Generic ( n : natural := 8);
Port ( A, B        : in  std_logic_vector(n downto 1);
       S           : buffer std_logic_vector(n downto 1);
       cin         : in  std_logic;
       cout        : out std_logic);
End soma;

Architecture somador of soma is
Signal vaium : std_logic_vector(n+1 downto 1);

Begin 
	vaium(1) <= cin;
	cout <= vaium(n+1);

	gerador: For i IN 1 to n Generate

           S(i)       <= A(i) xor B(i) xor vaium(i);
           vaium(i+1) <= ( A(i) and B(i) ) or ( A(i) and vaium(i) ) or ( B(i) and vaium(i) );
           

	end Generate;

End somador;           
