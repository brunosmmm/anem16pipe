---------------------------------------------------------
--! @file
--! @brief multiplier for MAC unit
--! @author  Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY MultiplicadorMAC IS

    GENERIC (N: INTEGER := 16); --! operand size
    
    PORT (
           A_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0); --! operand
           B_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0); --! operand
           
           OP_MULT : IN STD_LOGIC_VECTOR(1 DOWNTO 0); --! control in
           
           DATA_OUT : OUT STD_LOGIC_VECTOR(N*2 - 1 DOWNTO 0) := (OTHERS => '0'); --! output
           
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
            
                WHEN "01" => --unsigned multiply
                
                    DATA_OUT <= STD_LOGIC_VECTOR(UNSIGNED(A_IN)*UNSIGNED(B_IN));
                    
                    MULT_RDY <= '1'; --done
                    
                WHEN "11" => --signed multiply
                
                    DATA_OUT <= STD_LOGIC_VECTOR(SIGNED(A_IN)*SIGNED(B_IN));
                    
                    MULT_RDY <= '1'; --ended
                    
                WHEN OTHERS => 
                
                    MULT_RDY <= '0'; --NOP
                
            END CASE;
            
    END IF;
    
END PROCESS;
    
END ARCHITECTURE;
