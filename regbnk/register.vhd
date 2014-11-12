---------------------------------------------------------
--									PLDP
--								  A N E M
--
--						Registrador de deslocamento
--
--								Bruno Morais
--							brunosmmm@gmail.com
---------------------------------------------------------	
---------------------------------------------------------

--Data ult. mod.	:	25/04/2011
--Changelog:
---------------------------------------------------------
--@11/04/2011	:	Primeira revisao
--@19/04/2011	:
----+Corrigido comportamento do modo de teste
--@25/04/2011	:
----+Adicionado sinal de RESET assincrono

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegistradorEsp IS
  
  GENERIC(n : INTEGER := 8); 		--LARGURA DO REGISTRADOR
  
  PORT(SERIAL_IN		:	IN STD_LOGIC;	--ENTRADA SERIAL UTILIZADA QUANDO EM MODO DE TESTE
		 CK				:	IN STD_LOGIC;	--CLOCK
		 TEST 			: IN STD_LOGIC;	--MODO DE TESTE
		 RST 				: IN STD_LOGIC;	--RESET ASSINCRONO
		 PARALLEL_IN	: IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--ENTRADA PARALELA DE DADOS	
       DATA_OUT 		: BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--SAIDA PARALELA DE DADOS
       SERIAL_OUT 	: OUT STD_LOGIC);	--SAIDA SERIAL UTILIZADA QUANDO EM MODO DE TESTE

       
END ENTITY;

ARCHITECTURE Deslocamento OF RegistradorEsp IS

BEGIN
    
PROCESS(CK,TEST, RST)
  
BEGIN

	--RESET ASSINCRONO

	IF RST = '1' THEN
	
		DATA_OUT <= (OTHERS => '0');
		SERIAL_OUT <= '0';
  
	ELSIF RISING_EDGE(CK) THEN	--CLOCK SUBINDO
  
		--MODO DE TESTE
  
		IF TEST = '1' THEN
	  
			--REALIZA DESLOCAMENTO
	  
			SERIAL_OUT <= DATA_OUT(n-1);
  
			DATA_OUT(n-1 DOWNTO 1) <= DATA_OUT(n-2 DOWNTO 0);
    
			DATA_OUT(0) <= SERIAL_IN;
	 
		ELSE
		
			--CARREGA DADOS
	  
			DATA_OUT <= PARALLEL_IN;
	  
		END IF;
  
  END IF;
  
END PROCESS;

END ARCHITECTURE;
