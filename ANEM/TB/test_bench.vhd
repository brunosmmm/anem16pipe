LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY TEST_BENCH IS 
	GENERIC( N: NATURAL := 256);
END TEST_BENCH;

ARCHITECTURE TESTE OF TEST_BENCH IS

SIGNAL CK, RST: STD_LOGIC := '0';
SIGNAL INST: STD_LOGIC_VECTOR(15 DOWNTO 0);      						             -- INSTRUCAO A SER ENVIADA   
SIGNAL INST_END: STD_LOGIC_VECTOR(15 DOWNTO 0):= (OTHERS => '0');         				        -- PROXIMA INSTRUCAO RECEBIDA
SIGNAL TEST: STD_LOGIC := '0';											                           -- BIT DE TESTE - CARREGA/DESLOCA
SIGNAL MEM_W: STD_LOGIC;						                          -- INFORMACAO CONTROLE/MD
SIGNAL MEM_EN: STD_LOGIC;						                         -- INFORMACAO CONTROLE/MD

--BARRAMENTO DE DADOS BIDIRECIONAL
SIGNAL DADOS : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS=>'Z');

SIGNAL MEM_END: STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL BIT_INST_OUT: STD_LOGIC;

component memoria_dados
  generic(n_endereco     : integer :=  16;
          n_dados        : integer := 16);
  port(clk, en, w : in std_logic;
       endereco   : in std_logic_vector (n_endereco-1 downto 0);
       
       DADOS : INOUT STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0));
       
end component;

component memoria_de_programa
  generic (n_tamanho        : integer := 8;
           n_instrucao      : integer := 16);
  port(clk,en         : in std_logic;
       endereco       : in std_logic_vector(n_tamanho-1 downto 0);
       instrucao      : out std_logic_vector(15 downto 0));
end component;


BEGIN
  
cpu:  entity work.ANEM(test)	PORT MAP(CK,RST,TEST,INST,'0',BIT_INST_OUT,MEM_W,MEM_EN,MEM_END,DADOS,INST_END);

memProg: memoria_de_programa PORT MAP(CK,'1',INST_END(7 downto 0),INST);
memData: memoria_dados PORT MAP(CK,MEM_EN,MEM_W,MEM_END,DADOS);

--MAC
MAC: ENTITY WORK.MAC(MultAcc) PORT MAP(DADOS=>DADOS, CK=>CK, RST=>RST, ENDE=>MEM_END, W=>MEM_W, EN=>MEM_EN, INT=>OPEN);

PROCESS

begin
  
  RST <=  '1';
  WAIT FOR 30NS;
  RST <=  '0';
  
 FOR I IN 0 TO 2048 LOOP		-- clk
  CK <= NOT CK;
  WAIT FOR 10 NS;
 END LOOP;
END PROCESS;
END TESTE;
