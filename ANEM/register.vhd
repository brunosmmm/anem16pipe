---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       ANEM
--           Registrador de instrucao e ULA
--
--                  Bruno Morais
--              brunosmmm@gmail.com
---------------------------------------------------------
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegistradorANEM IS
  
  GENERIC(n : INTEGER := 8); 		--LARGURA DO REGISTRADOR
  
  PORT( EN          :	IN STD_LOGIC;	--ENABLE
        PARALLEL_IN : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--ENTRADA PARALELA DE DADOS	
        DATA_OUT    : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--SAIDA PARALELA DE DADOS
        CK : IN STD_LOGIC; --CLOCK
        RST : IN STD_LOGIC --RESET
        );

       
END ENTITY;

ARCHITECTURE Load OF RegistradorANEM IS

BEGIN

PROCESS(CK, RST)

BEGIN

    --RESET ASSINCRONO
    IF RST = '1' THEN
    
        --IF EN = '1' THEN

            --DATA_OUT <= PARALLEL_IN; --MODO ESPECIAL, SE EN = 1 NO MOMENTO DO RESET, CARREGA DADOS

        --ELSE
            
            DATA_OUT <= (OTHERS => '0'); --EN = 0, ZERA VALORES
        
        --END IF;

    ELSIF RISING_EDGE(CK) THEN
    
        IF EN = '1' THEN
        
            DATA_OUT <= PARALLEL_IN;
            
        END IF;
    
    END IF;

END PROCESS;

--LATCHES
--DATA_OUT <= PARALLEL_IN when EN = '1' else DATA_OUT;

END ARCHITECTURE;
