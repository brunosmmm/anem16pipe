---------------------------------------------------------
--                      ANEM
--           Instruction / ALU register
--
--                  Bruno Morais
--              brunosmmm@gmail.com
---------------------------------------------------------
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegANEM IS
  
  GENERIC(n : INTEGER := 8); 		--WIDTH IN BITS
  
  PORT( EN          :	IN STD_LOGIC;	--ENABLE
        PARALLEL_IN : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--PARALLEL IN
        DATA_OUT    : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--PARALLEL OUT
        CK : IN STD_LOGIC; --CLOCK
        RST : IN STD_LOGIC --RESET
        );

  
END ENTITY;

ARCHITECTURE Load OF RegANEM IS

BEGIN

  PROCESS(CK, RST)

  BEGIN

    --ASYNCHRONOUS RESET
    IF RST = '1' THEN
      
      DATA_OUT <= (OTHERS => '0');

    ELSIF RISING_EDGE(CK) THEN
      
      IF EN = '1' THEN
        
        DATA_OUT <= PARALLEL_IN;
        
      END IF;
      
    END IF;

  END PROCESS;

END ARCHITECTURE;
