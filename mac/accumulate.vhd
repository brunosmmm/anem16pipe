---------------------------------------------------------
--! @file
--! @brief accumulator for MAC unit
--! @author  Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY AcumuladorMAC IS


    GENERIC (N : INTEGER := 32); --! accumulator width
    
    PORT(
            DATA_IN : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0); --! data in
            DATA_OUT: BUFFER STD_LOGIC_VECTOR(N-1 DOWNTO 0); --! data out
            
            OP_ACC: IN STD_LOGIC_VECTOR(1 DOWNTO 0); --! control in
            
            ACC_RDY : OUT STD_LOGIC := '0'; --! done flag
            
            CK : IN STD_LOGIC;
            
            C : OUT STD_LOGIC; --! CARRY OUT
            OVR : OUT STD_LOGIC; --! OVERFLOW flag
            
            Z : OUT STD_LOGIC; --! ZERO flag
            
            RST: IN STD_LOGIC
            );
            
END ENTITY;

ARCHITECTURE ACC OF AcumuladorMAC IS

SIGNAL ACC_DATA_OUT : STD_LOGIC_VECTOR(N DOWNTO 0) := (OTHERS=>'0');
SIGNAL LAST_DATA_SIG : STD_LOGIC := '0';
SIGNAL ZERO : STD_LOGIC_VECTOR(N-1 DOWNTO 0) := (OTHERS=>'0'); --! all zeros

BEGIN

ZERO <= (OTHERS=>'0');

PROCESS(CK, RST)

BEGIN

    IF RST = '1' THEN
    
        DATA_OUT <= (OTHERS=>'0');
        ACC_RDY <= '0';

    ELSIF RISING_EDGE(CK) THEN
    
    CASE OP_ACC IS
    
        WHEN "01" =>  --unsigned accumulate
        
            --there is no overflow
            OVR <= '0';
        
            ACC_DATA_OUT <= STD_LOGIC_VECTOR(UNSIGNED('0'&DATA_IN) + UNSIGNED('0'&DATA_OUT));
            
            --CARRY OUT
            
            C <= ACC_DATA_OUT(N);
            
            --sum
            
            DATA_OUT <= ACC_DATA_OUT(N-1 DOWNTO 0);
            
            IF DATA_OUT = ZERO THEN
                Z <= '1';
            ELSE
                Z <= '0';
				END IF;
            
            ACC_RDY <= '1'; --done

        WHEN "11" =>  --signed accumulate
        
            --no carry out
            C <= '0';
        
            LAST_DATA_SIG <= DATA_OUT(N-1); --saves current vector
        
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
                
                DATA_OUT <= (OTHERS=>'0');
            
            END IF;
            
            ACC_RDY <= '1'; --done
           
        WHEN OTHERS => 
            
            ACC_RDY <= '0'; --NOP
       
    END CASE;
    
    END IF;

END PROCESS;


END ARCHITECTURE;
