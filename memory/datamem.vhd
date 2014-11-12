library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity memoria_dados is
  generic(
          --n_endereco     : integer :=  8;
          n_endereco     : integer :=  16; --brunosmmm: a largura do barramento de endereco tambem e 16
          n_dados        : integer := 16;
          
          --ENDERECO FINAL DA MEMORIA / INICIO DO ESPACO DE ENDERECAMENTO DE PERIFERICOS
          MEM_FIM : INTEGER := CONV_INTEGER(x"FFCF"));
          
          
  port(clk, en, w : in std_logic;
       endereco   : in std_logic_vector (n_endereco-1 downto 0);
       
       --brunosmmm: barramento de dados bidirecional
       
       --d_out      : in std_logic_vector (n_dados-1 downto 0);
       --d_in       : out std_logic_vector(n_dados-1 downto 0));
       
       DADOS : INOUT STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0));
       
end memoria_dados;

architecture memo of memoria_dados is

--type arranjo_memoria is array ((2**n_endereco)-1 downto 0) of std_logic_vector(n_dados-1 downto 0);
type arranjo_memoria is array (MEM_FIM downto 0) of std_logic_vector(n_dados-1 downto 0);

signal ram: arranjo_memoria; -- sinal para guardar o dado que se encontra no endereço especificado

--brunosmmm: mantem sinais
SIGNAL D_OUT : STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL D_IN : STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0) := (OTHERS=>'0');

begin

    --BARRAMENTO DE DADOS BIDIRECIONAL
    
    DADOS <= D_IN WHEN (EN='1' AND W='0' AND (endereco <= MEM_FIM)) ELSE
             (OTHERS=>'Z');
             
    D_OUT <= DADOS;


process (clk)
  begin
    if rising_edge(clk) then
      if(en = '1') then
        if(w = '1') then
            IF (endereco <= MEM_FIM) THEN
                ram(conv_integer(endereco)) <= d_out;     
            END IF;
        end if;
      end if;
    end if;
end process;



 d_in <= ram(conv_integer(endereco)) when (en = '1' AND (endereco <= MEM_FIM)) else
         (others => '0');
    
end memo;

