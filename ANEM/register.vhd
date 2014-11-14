---------------------------------------------------------
--! @file register.vhd
--! @brief General purpose register
--! @author  Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegANEM IS
  
  GENERIC(n : INTEGER := 8); 		--! register width
  
  PORT( EN          :	IN STD_LOGIC;	--! write enable
        PARALLEL_IN : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--! parallel data input
        DATA_OUT    : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);	--! parallel data output
        CK : IN STD_LOGIC;
        RST : IN STD_LOGIC
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
