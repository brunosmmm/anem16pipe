library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_unsigned.all;

entity memoria_de_programa is
  generic (n_tamanho        : integer := 8;
           n_instrucao      : integer := 16);
  port(clk,en         : in std_logic;
       endereco       : in std_logic_vector(n_tamanho-1 downto 0); -- endereco da linha na memória
       instrucao      : out std_logic_vector(15 downto 0));
end memoria_de_programa;

architecture teste of memoria_de_programa is
type memoria_rom is array (((2**n_tamanho)-1) downto 0) of std_logic_vector(n_instrucao-1 downto 0);
signal rom: memoria_rom;

begin
    
  abc: process
    
  file arquivo : text is in "arquivo.txt";
  variable linha : line;
  -- variable addr, valor, to_do, inst : std_logic_vector (n_instrucao-1 downto 0);
  variable addr, inst : bit_vector (n_instrucao-1 downto 0); 
  -- é pra deixar o clk mesmo?
  
    begin
      
        while not endfile(arquivo) loop
        
        readline(arquivo, linha);
        read(linha, addr);
         --read(linha, valor);
         --addr <= valor;
        
         read(linha, inst);
         --read(linha, to_do);
         --inst <= to_do;
        
        rom(conv_integer(to_stdlogicvector(addr))) <= to_stdlogicvector(inst);  
           
        end loop;      
  
    wait;
  
  end process abc;
   
   def: process(endereco) 
   begin
     
   if (en = '1') then
     instrucao <= rom(conv_integer(endereco));
   else instrucao <= (others => 'Z');
   
   end if; 
   
    end process def;
    
    
end teste; 
