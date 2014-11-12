Library ieee;
Use ieee.std_logic_1164.all;

Entity complemento is 
    Generic ( n : natural := 8);
    Port ( B    : in  std_logic_vector(n downto 1);
           S    : out std_logic_vector(n downto 1));
End complemento;

Architecture sub of complemento is 

	Component soma is 
		Generic ( n : natural := 8);
		Port ( A, B        : in  std_logic_vector(n downto 1);
	        S           : out std_logic_vector(n downto 1);
	        cin         : in  std_logic;
	        cout    : out std_logic);

	End Component;

signal nB   : std_logic_vector(n downto 1);

Begin
   
   
   nB <= not B;    

   c1 : soma Generic Map( n ) Port Map ( nB, (others => '0'), S, '1' ,OPEN);


end sub;
