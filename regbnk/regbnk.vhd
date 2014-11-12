---------------------------------------------------------
--									PLDP
--								  A N E M
--
--						Banco de registradores
--
--					Bruno Morais / Lucas Lessa
---------------------------------------------------------
--Utiliza entidade externa RegistradorEsp (Registrador de
--deslocamento) : Registrador.vhd			
---------------------------------------------------------

--Data ult. mod.	:	02/05/2011
--Changelog:
---------------------------------------------------------
--@25/04/2011	:	Primeira revisao completa
--@26/04/2011	:	
----*Renomeados sinais para maior inteligibilidade
--@28/04/2011	:
----*Corrigido erro no funcionamento do modo de teste
----*Corrigido erro na prevencao de escrita do reg 0
--@02/05/2011 :
----*Corrigido mapeamento de sinais para o reg 0
----+Adicionado RESET assincrono
----*Modificado acionamento dos registradores internos
---------------------------------------------------------
--Descrição dos sinais de controle do banco de registradores
---------------------------------------------------------
--REG_CNT controla as operações do banco segundo
--a descrição abaixo
---------------------------------------------------------
--REG_CNT              Operação
--001                  Carrega saída da ULA (ULA_IN) em SEL_A
--010                  Carrega BYTE_IN na parte superior de SEL_A
--011                  Carrega BYTE_IN na parte inferior de SEL_A
--100                  Carrega dados da memória (DATA_IN) em SEL_A
--000, 1XX             Não realiza operação
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY BancoReg IS
  
  GENERIC (W 				: INTEGER := 8; 	--LARGURA DA ENTRADA DE DADOS (BYTE_IN)
           DATA_W 		: INTEGER := 16; 	--LARGURA DOS REGISTRADORES
           REGBNK_ADDR 	: INTEGER := 4; 	--LARGURA DO ENDERECAMENTO
           REGBNK_SIZE 	: INTEGER := 16); --TAMANHO DO BANCO DE REGISTRADORES
  
  PORT(S_IN   		: IN STD_LOGIC; 											--ENTRADA SERIAL DE TESTE
       TEST   		: IN STD_LOGIC; 											--MODO DE TESTE ATIVO OU NAO
       ULA_IN 		: IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); 		--RETORNO DA ULA
       BYTE_IN   	: IN STD_LOGIC_VECTOR(W-1 DOWNTO 0); 				--ENTRADA PARALELA DE DADOS
       SEL_A  		: IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0); 	--SELETOR DO REGISTRADOR A
       SEL_B  		: IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0); 	--SELETOR DO REGISTRADOR B
       DATA_IN 	: IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); 		--ENTRADA DA MEMORIA
       CK     		: IN STD_LOGIC; 											--CLOCK
       RST    		: IN STD_LOGIC; 											--RESET ASSINCRONO
       REG_CNT		: IN STD_LOGIC_VECTOR(2 DOWNTO 0);					--CONTROLE DE OPERACOES
       SEL_W            : in std_logic_vector(regbnk_addr-1 downto 0);
       A_OUT  		: OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); 		--SAIDA DE DADOS DO REGISTRADOR A
       B_OUT  		: OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); 		--SAIDA DE DADIS DO REGISTRADOR B
       S_OUT  		: OUT STD_LOGIC);  										--SAIDA SERIAL DE TESTE
       
END ENTITY;


ARCHITECTURE ANEM OF BancoReg IS
  
--TIPO REGDATA: ARRAY DE VETORES
TYPE REGDATA IS ARRAY(REGBNK_SIZE-1 DOWNTO 0) OF STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);
  
--SINAL INTERNO PARA INTERCONEXAO DOS REGISTRADORES EM MODO DE TESTE
SIGNAL SERIAL_TEST : STD_LOGIC_VECTOR(REGBNK_SIZE-1 DOWNTO 0);

--SINAIS INTERNOS PARA INTERCONEXAO DOS REGISTRADORES COM AS ENTRADAS E SAIDAS
SIGNAL REG_DATA    : REGDATA;
SIGNAL REG_IN_DATA : REGDATA;

--SINAL DE CLOCK PROPAGADO PARA OS REGISTRADORES COM ATRASO
SIGNAL SUBCK : STD_LOGIC := '0';
  
BEGIN

	--CONECTA SINAIS FIXOS
	
	--SAIDA SERIAL: ULTIMO BIT DO VETOR SERIAL_TEST
  
        S_OUT <= SERIAL_TEST(REGBNK_SIZE-1);
	
	--ENTRADA SERIAL: PRIMEIRO BIT DO VETOR SERIAL_TEST
	
	SERIAL_TEST(0) <= S_IN;
  
	--DADOS NAS SAIDAS: FUNCIONA DE FORMA ASSINCRONA
  
	A_OUT <= REG_DATA(TO_INTEGER(UNSIGNED(SEL_A)));
        B_OUT <= REG_DATA(TO_INTEGER(UNSIGNED(SEL_B)));
  
  --GERA OS REGISTRADORES DO BANCO
  
	--REGISTRADOR 0
	--NAO E POSSIVEL ESCREVE NO REGISTRADOR 0. O MODO DE TESTE COLOCA OS DADOS NO REGISTRADOR 1.
	--POR ISSO, O REGISTRADOR 0 TEM SUA ENTRADA SERIAL ATERRADA E SUA SAIDA E DEIXADA EM ABERTO, MANTENDO SEMPRE O VALOR ZERO
	--MESMO QUANDO EM MODO DE TESTE.
  
	REG0 : ENTITY WORK.RegistradorEsp(Deslocamento) GENERIC MAP(DATA_W) PORT MAP(SERIAL_OUT=>OPEN,CK=>'0',TEST=>'0',DATA_OUT=>REG_DATA(0),SERIAL_IN=>'0',PARALLEL_IN=>(OTHERS=>'0'), RST=>RST);
   
	--DEMAIS REGISTRADORES
	
	--A ENTRADA SERIAL DE TESTE, ATRAVES DO VETOR SERIAL_TEST, E CONECTADA A ENTRADA SERIAL DO REG 1.
	
	GEN_REG : FOR I IN 1 TO REGBNK_SIZE-1 GENERATE
    
		REGX : ENTITY WORK.RegistradorEsp(Deslocamento) GENERIC MAP(DATA_W) PORT MAP(SERIAL_OUT=>SERIAL_TEST(I),CK=>SUBCK,TEST=>TEST, DATA_OUT=>REG_DATA(I),SERIAL_IN=>SERIAL_TEST(I-1),PARALLEL_IN=>REG_IN_DATA(I), RST=>RST);
    
  END GENERATE;
  
  
PROCESS(CK, RST, TEST)
  
BEGIN
  
  IF RST = '1' THEN
    
    FOR I IN 0 TO REGBNK_SIZE-1 LOOP
      
      REG_IN_DATA(I) <= (OTHERS => '0');    
      
  END LOOP;

	ELSIF TEST = '0' THEN --SE NAO ESTA EM MODO DE TESTE
  
		IF RISING_EDGE(CK) THEN --CLOCK SUBINDO
  
		--CARREGA REGISTRADORES
  
		--PREVINE ESCRITA NO REGISTRADOR 0
  
			--IF TO_INTEGER(UNSIGNED(SEL_A)) /= 0  THEN
  
			--SO VERIFICA O REGISTRADOR A POIS OS DADOS SO SAO ESCRITOS NELE
  
				CASE REG_CNT IS
  
					WHEN "100" => --CARREGA DADOS DA MEMORIA NO SEL_A
	
						REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W))) <= DATA_IN;
		
					WHEN "010" => --CARREGA BYTE_IN NA PARTE SUPERIOR DE SEL_A

						REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W)))(DATA_W-1 DOWNTO W) <= BYTE_IN;

					WHEN "011" => --CARREGA BYTE_IN NA PARTE INFERIOR DE SEL_A
	
						REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W)))(W-1 DOWNTO 0) <= BYTE_IN;
	
					WHEN "001" => --CARREGA SAIDA DA ULA EM SEL_A
	
						REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W))) <= ULA_IN;
	
					WHEN OTHERS => NULL;
	
				END CASE;
	
			--END IF;
     
		END IF;

	END IF;
	
	--PROPAGA O CLOCK AOS REGISTRADORES INTERNOS, DEPOIS DE DEFINIDOS SEUS SINAIS DE ENTRADA		
  SUBCK <= CK;
  
END PROCESS;
 
END ARCHITECTURE;
