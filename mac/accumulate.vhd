---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       MAC
--                     Acumulador
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

ENTITY AcumuladorMAC IS


    GENERIC (N : INTEGER := 32); --LARGURA DO ACUMULADOR
    
    PORT(
            DATA_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0); --ENTRADA DE DADOS
            DATA_OUT: BUFFER STD_LOGIC_VECTOR(N-1 DOWNTO 0); --SADA DE DADOS
            
            OP_ACC: IN STD_LOGIC_VECTOR(1 DOWNTO 0); --CONTROLE
            
            ACC_RDY : OUT STD_LOGIC := '0'; --ACUMULACAO CONCLUIDA
            
            CK : IN STD_LOGIC; --CLOCK
            
            C : OUT STD_LOGIC; --CARRY OUT
            OVR : OUT STD_LOGIC; --OVERFLOW
            
            Z : OUT STD_LOGIC; --ZERO
            
            RST: IN STD_LOGIC
            );
            
END ENTITY;

ARCHITECTURE ACC OF AcumuladorMAC IS

SIGNAL ACC_DATA_OUT : STD_LOGIC_VECTOR(N DOWNTO 0) := (OTHERS=>'0');
SIGNAL LAST_DATA_SIG : STD_LOGIC := '0'; --SINAL DO ULTIMO VETOR DE DADOS
SIGNAL ZERO : STD_LOGIC_VECTOR(N-1 DOWNTO 0) := (OTHERS=>'0'); --SINAL ZERO PARA COMPARACAO

BEGIN

ZERO <= (OTHERS=>'0');

PROCESS(CK, RST)

BEGIN

    IF RST = '1' THEN
    
        DATA_OUT <= (OTHERS=>'0');
        ACC_RDY <= '0';

    ELSIF RISING_EDGE(CK) THEN
    
    CASE OP_ACC IS
    
        WHEN "01" =>  --ACUMULA (SEM SINAL)
        
            --OVERFLOW NAO E UTILIZADO
            OVR <= '0';
        
            ACC_DATA_OUT <= STD_LOGIC_VECTOR(UNSIGNED('0'&DATA_IN) + UNSIGNED('0'&DATA_OUT));
            
            --CARRY OUT
            
            C <= ACC_DATA_OUT(N);
            
            --SOMA
            
            DATA_OUT <= ACC_DATA_OUT(N-1 DOWNTO 0);
            
            IF DATA_OUT = ZERO THEN
                Z <= '1';
            ELSE
                Z <= '0';
				END IF;
            
            ACC_RDY <= '1'; --TERMINOU

        WHEN "11" =>  --ACUMULA (COM SINAL)
        
            --CARRY OUT NAO E UTILIZADO
            C <= '0';
        
            LAST_DATA_SIG <= DATA_OUT(N-1); --GUARDA SINAL DO VETOR DE DADOS ANTES DA SOMA
        
            DATA_OUT <= STD_LOGIC_VECTOR(SIGNED(DATA_IN) + SIGNED(DATA_OUT));
            
            IF DATA_OUT = ZERO THEN
                Z <= '1';
            ELSE
                Z <= '0';
				END IF;
            
            IF (((NOT DATA_OUT(N-1)) AND (DATA_IN(N-1) AND LAST_DATA_SIG)) OR 
                (DATA_OUT(N-1) AND ((NOT DATA_IN(N-1)) AND (NOT LAST_DATA_SIG)))) = '1' THEN
               
                --OVERFLOW
                OVR <= '1';
                
                --ZERA DATA_OUT?
                DATA_OUT <= (OTHERS=>'0');
            
            END IF;
            
            ACC_RDY <= '1'; --TERMINOU
           
        WHEN OTHERS => 
            
            ACC_RDY <= '0'; --NAO HOUVE OPERACAO
       
    END CASE;
    
    END IF;

END PROCESS;


END ARCHITECTURE;
