---------------------------------------------------------
--! @file accumulate.vhd
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

SIGNAL ZERO : STD_LOGIC_VECTOR(N-1 DOWNTO 0) := (OTHERS=>'0'); --! all zeros

BEGIN

ZERO <= (OTHERS=>'0');

PROCESS(CK, RST)
  variable sum_u   : std_logic_vector(N downto 0);
  variable sum_s   : std_logic_vector(N-1 downto 0);
  variable old_sig : std_logic;
BEGIN

    IF RST = '1' THEN

        DATA_OUT <= (OTHERS=>'0');
        ACC_RDY <= '0';

    ELSIF RISING_EDGE(CK) THEN

    CASE OP_ACC IS

        WHEN "01" =>  --unsigned accumulate

            OVR <= '0';

            sum_u := STD_LOGIC_VECTOR(UNSIGNED('0'&DATA_IN) + UNSIGNED('0'&DATA_OUT));

            --CARRY OUT
            C <= sum_u(N);

            --sum
            DATA_OUT <= sum_u(N-1 DOWNTO 0);

            IF sum_u(N-1 DOWNTO 0) = ZERO THEN
                Z <= '1';
            ELSE
                Z <= '0';
            END IF;

            ACC_RDY <= '1'; --done

        WHEN "11" =>  --signed accumulate

            --no carry out
            C <= '0';

            old_sig := DATA_OUT(N-1); --current accumulator sign (before add)

            sum_s := STD_LOGIC_VECTOR(SIGNED(DATA_IN) + SIGNED(DATA_OUT));

            DATA_OUT <= sum_s;

            IF sum_s = ZERO THEN
                Z <= '1';
            ELSE
                Z <= '0';
            END IF;

            --Overflow: both inputs same sign, result different sign
            IF (DATA_IN(N-1) = old_sig) AND (sum_s(N-1) /= old_sig) THEN

                OVR <= '1';

                DATA_OUT <= (OTHERS=>'0');

            ELSE

                OVR <= '0';

            END IF;

            ACC_RDY <= '1'; --done

        WHEN OTHERS =>

            ACC_RDY <= '0'; --NOP

    END CASE;

    END IF;

END PROCESS;


END ARCHITECTURE;
