---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       MAC
--                  Multiplicador
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

ENTITY MultiplicadorMAC IS

    GENERIC (N: INTEGER := 16);
    
    PORT (
           A_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
           B_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
           
           OP_MULT : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
           
           DATA_OUT : OUT STD_LOGIC_VECTOR(N*2 - 1 DOWNTO 0) := (OTHERS => '0');
           
           CK : IN STD_LOGIC;
           
           MULT_RDY : OUT STD_LOGIC := '0'
           );
END ENTITY;

ARCHITECTURE MULT OF MultiplicadorMAC IS

BEGIN

PROCESS(CK)

BEGIN
    
    IF RISING_EDGE(CK) THEN
    
            CASE OP_MULT IS
            
                WHEN "01" => --MULTIPLICA SEM SINAL?
                
                    DATA_OUT <= STD_LOGIC_VECTOR(UNSIGNED(A_IN)*UNSIGNED(B_IN));
                    
                    MULT_RDY <= '1'; --MULTIPLICACAO TERMINOU
                    
                WHEN "11" => --MULTIPLICA COM SINAL?
                
                    DATA_OUT <= STD_LOGIC_VECTOR(SIGNED(A_IN)*SIGNED(B_IN));
                    
                    MULT_RDY <= '1'; --MULTIPLICACAO TERMINOU
                    
                WHEN OTHERS => 
                
                    MULT_RDY <= '0'; --NAO HOUVE MULTIPLICACAO
                
            END CASE;
            
    END IF;
    
END PROCESS;
    
END ARCHITECTURE;
