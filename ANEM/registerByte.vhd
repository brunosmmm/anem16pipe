---------------------------------------------------------
--! @file registerByte.vhd
--! @brief register with byte input and selectable write
--! @author  Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY RegANEMB IS

  GENERIC(n : INTEGER := 16);

  PORT(CK				:	IN STD_LOGIC;
       RST 				: IN STD_LOGIC;
       PARALLEL_IN	: IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);
       BYTE_IN        : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
       CONTROL        : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
       EN             : IN STD_LOGIC;
       DATA_OUT 		: BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0);
       END ENTITY;

       ARCHITECTURE shift of RegANEMB IS

              BEGIN

                       PROCESS(CK, RST, EN)

                              BEGIN

                                       IF RST = '1' THEN

                                                DATA_OUT <= (OTHERS => '0');

                                              ELSIF RISING_EDGE(CK) THEN


                                                       IF EN = '1' THEN

                                                                CASE CONTROL IS

                                                                         WHEN "010" =>

                                                                                  DATA_OUT(15 DOWNTO 8) <= BYTE_IN;
                                                                                         DATA_OUT(7 DOWNTO 0) <= DATA_OUT(7 DOWNTO 0);

                                                                         WHEN "011" =>

                                                                                  DATA_OUT(15 DOWNTO 8) <= DATA_OUT(15 DOWNTO 8);
                                                                                         DATA_OUT(7 DOWNTO 0) <= BYTE_IN;

                                                                         WHEN  "100"  =>

                                                                                  DATA_OUT <= PARALLEL_IN;


                                                                         WHEN  "001"  =>

                                                                                  DATA_OUT <= PARALLEL_IN;

                                                                         WHEN OTHERS => NULL;

                                                                       END CASE;


                                                                       END IF;

                                                                       END IF;

                                                                END PROCESS;

                                                       END ARCHITECTURE;
