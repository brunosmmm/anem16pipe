-------------------------------
--! @file regbnk.vhd
--! @brief register bank
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2011
-------------------------------
---------------------------------------------------------
--Register bank control
---------------------------------------------------------
--REG_CNT selects operation
---------------------------------------------------------
--REG_CNT              Operation
--001                  Loads ALU output (ALU_IN) in selected register (A)
--010                  Loads BYTE_IN in upper half of selected register (A)
--011                  Loads BYTE_IN in lower half of selected register (A)
--100                  Loads data from memory in selected register (A)
--101                  Load  PC into register 15 (JAL)
--110                  Loads HI register value into selected register (MFHI)
--111                  Loads LO register value into selected register (MFLO)
--000                  No operation
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY regbnk IS

  GENERIC (W            : INTEGER := 8; --! width of a byte
           DATA_W       : INTEGER := 16; --! data width
           REGBNK_ADDR  : INTEGER := 4; --! addressing width = lg(data_w)
           REGBNK_SIZE  : INTEGER := 16 --! register count
	   );

  PORT(S_IN             : IN STD_LOGIC; --! test mode data input
       TEST             : IN STD_LOGIC; --! test mode enable
       ALU_IN           : IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); --! data from ALU
       BYTE_IN          : IN STD_LOGIC_VECTOR(W-1 DOWNTO 0); --! data from immediate value
       SEL_A            : IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0); --! A selector
       SEL_B            : IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0); --! B selector
       DATA_IN  : IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); --! data from memory
       CK               : IN STD_LOGIC;
       RST              : IN STD_LOGIC;
       REG_CNT          : IN STD_LOGIC_VECTOR(2 DOWNTO 0); --! register bank control
       SEL_W            : in std_logic_vector(regbnk_addr-1 downto 0); --! write select
       A_OUT            : OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); --! A output
       B_OUT            : OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0); --! B output
       S_OUT            : OUT STD_LOGIC; --! test mode data output
       PC_IN            : in STD_LOGIC_VECTOR(15 downto 0); --! PC Input for JAL jumps
       HI_IN            : in std_logic_vector(15 downto 0); --! data from HI register
       LO_IN            : in std_logic_vector(15 downto 0) --! data from LO register
       );

END ENTITY;


ARCHITECTURE ANEM OF regbnk IS

  TYPE REGDATA IS ARRAY(REGBNK_SIZE-1 DOWNTO 0) OF STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);

  SIGNAL REG_DATA : REGDATA;

BEGIN

  --test mode stub (not implemented)
  S_OUT <= '0';

  --asynchronous data out with write-through bypass
  --When WB writes a register at the same rising_edge that ID reads it,
  --the combinational read gets the stale (pre-write) value. Bypass the
  --write data for full-word writes (R/S="001", LW="100", MFHI="110",
  --MFLO="111"). Partial writes (LIU="010", LIL="011") and JAL ("101")
  --are covered by NFW stall, so no bypass needed.
  A_OUT <= ALU_IN  when REG_CNT = "001" and SEL_W = SEL_A and SEL_W /= "0000" else
           DATA_IN when REG_CNT = "100" and SEL_W = SEL_A and SEL_W /= "0000" else
           HI_IN   when REG_CNT = "110" and SEL_W = SEL_A and SEL_W /= "0000" else
           LO_IN   when REG_CNT = "111" and SEL_W = SEL_A and SEL_W /= "0000" else
           REG_DATA(TO_INTEGER(UNSIGNED(SEL_A)));

  B_OUT <= ALU_IN  when REG_CNT = "001" and SEL_W = SEL_B and SEL_W /= "0000" else
           DATA_IN when REG_CNT = "100" and SEL_W = SEL_B and SEL_W /= "0000" else
           HI_IN   when REG_CNT = "110" and SEL_W = SEL_B and SEL_W /= "0000" else
           LO_IN   when REG_CNT = "111" and SEL_W = SEL_B and SEL_W /= "0000" else
           REG_DATA(TO_INTEGER(UNSIGNED(SEL_B)));

  PROCESS(CK, RST)
    variable idx : integer;
  BEGIN

    IF RST = '1' THEN

      FOR I IN 0 TO REGBNK_SIZE-1 LOOP
        REG_DATA(I) <= (OTHERS => '0');
      END LOOP;

    ELSIF RISING_EDGE(CK) THEN

      idx := TO_INTEGER(UNSIGNED(SEL_W));

      --JAL writes to hardcoded R15 regardless of SEL_W
      --(SEL_W contains jump offset bits for JAL, not a register index)
      IF REG_CNT = "101" THEN
        REG_DATA(15) <= PC_IN;
      END IF;

      --register 0 is read-only (hardwired to zero)
      IF idx /= 0 THEN

        CASE REG_CNT IS

          WHEN "100" => --MEM -> A
            REG_DATA(idx) <= DATA_IN;

          WHEN "010" => --BYTE -> HI(A) (LIU)
            REG_DATA(idx)(DATA_W-1 DOWNTO W) <= BYTE_IN;

          WHEN "011" => --BYTE -> LOW(A) (LIL)
            REG_DATA(idx)(W-1 DOWNTO 0) <= BYTE_IN;

          WHEN "001" => --ALU -> A
            REG_DATA(idx) <= ALU_IN;

          WHEN "110" => --HI -> A (MFHI)
            REG_DATA(idx) <= HI_IN;

          WHEN "111" => --LO -> A (MFLO)
            REG_DATA(idx) <= LO_IN;

          WHEN OTHERS => NULL;

        END CASE;

      END IF;

    END IF;

  END PROCESS;

END ARCHITECTURE;
