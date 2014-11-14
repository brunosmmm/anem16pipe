-------------------------------
--! @file bregister.vhd
--! @brief register bank registers
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2011
-------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegSp IS
  
  GENERIC(n : INTEGER := 8);            --! width in bits
  
  PORT(SERIAL_IN        : IN STD_LOGIC; --! TEST MODE DATA, serial in
       CK               : IN STD_LOGIC; --! CLOCK
       TEST             : IN STD_LOGIC; --! TEST MODE ENABLE
       RST              : IN STD_LOGIC; --! ASYNC RST
       PARALLEL_IN      : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);    --! PARALLEL IN     
       DATA_OUT         : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);--! PARALLEL OUT
       SERIAL_OUT       : OUT STD_LOGIC); --! TEST DATA OUT, serial out

  
END ENTITY;

ARCHITECTURE shift OF RegSp IS

BEGIN
  
  PROCESS(CK,TEST, RST)
    
  BEGIN

    IF RST = '1' THEN
      
      DATA_OUT <= (OTHERS => '0');
      SERIAL_OUT <= '0';
      
    ELSIF RISING_EDGE(CK) THEN
      
      IF TEST = '1' THEN
        
        SERIAL_OUT <= DATA_OUT(n-1);
        
        DATA_OUT(n-1 DOWNTO 1) <= DATA_OUT(n-2 DOWNTO 0);
        
        DATA_OUT(0) <= SERIAL_IN;
        
      ELSE
       
        
        DATA_OUT <= PARALLEL_IN;
        
      END IF;
      
    END IF;
    
  END PROCESS;

END ARCHITECTURE;
