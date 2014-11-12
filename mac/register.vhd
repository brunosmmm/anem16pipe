---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       MAC
--           Registrador de configurao e dados
--
--                  Bruno Morais
--              brunosmmm@gmail.com
---------------------------------------------------------
---------------------------------------------------------

--Data ult. mod.	:	30/05/2011
--Changelog:
---------------------------------------------------------
--@30/05/2011	:	Primeira revisao

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegistradorMAC IS
  
  GENERIC(n : INTEGER := 8); 		--LARGURA DO REGISTRADOR
  
  PORT( EN          :	IN STD_LOGIC;	--ENABLE
        PARALLEL_IN : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--ENTRADA PARALELA DE DADOS	
        DATA_OUT    : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--SAIDA PARALELA DE DADOS
        CK : IN STD_LOGIC; --CLOCK
        RST : IN STD_LOGIC --RESET
        );

       
END ENTITY;

ARCHITECTURE Load OF RegistradorMAC IS

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
