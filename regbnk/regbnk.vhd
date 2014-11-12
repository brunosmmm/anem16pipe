---------------------------------------------------------
--Register bank control
---------------------------------------------------------
--REG_CNT selects operation
---------------------------------------------------------
--REG_CNT              Operação
--001                  Loads ALU output (ALU_IN) in selected register (A)
--010                  Loads BYTE_IN in upper half of selected register (A)
--011                  Loads BYTE_IN in lower half of selected register (A)
--100                  Loads data from memory in selected register (A)
--000, 1XX             No operation
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY regbnk IS
  
  GENERIC (W            : INTEGER := 8;  
           DATA_W       : INTEGER := 16;   
           REGBNK_ADDR  : INTEGER := 4;    
           REGBNK_SIZE  : INTEGER := 16);
  
  PORT(S_IN             : IN STD_LOGIC;                       
       TEST             : IN STD_LOGIC;                             
       ALU_IN           : IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);   
       BYTE_IN          : IN STD_LOGIC_VECTOR(W-1 DOWNTO 0);      
       SEL_A            : IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0);  
       SEL_B            : IN STD_LOGIC_VECTOR(REGBNK_ADDR-1 DOWNTO 0); 
       DATA_IN  : IN STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);           
       CK               : IN STD_LOGIC;                          
       RST              : IN STD_LOGIC;                           
       REG_CNT          : IN STD_LOGIC_VECTOR(2 DOWNTO 0);         
       SEL_W            : in std_logic_vector(regbnk_addr-1 downto 0);
       A_OUT            : OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);    
       B_OUT            : OUT STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);    
       S_OUT            : OUT STD_LOGIC);                           
  
END ENTITY;


ARCHITECTURE ANEM OF regbnk IS
  

  TYPE REGDATA IS ARRAY(REGBNK_SIZE-1 DOWNTO 0) OF STD_LOGIC_VECTOR(DATA_W-1 DOWNTO 0);
  

  SIGNAL SERIAL_TEST : STD_LOGIC_VECTOR(REGBNK_SIZE-1 DOWNTO 0);


  SIGNAL REG_DATA    : REGDATA;
  SIGNAL REG_IN_DATA : REGDATA;

--delayed clock
  SIGNAL SUBCK : STD_LOGIC := '0';
  
BEGIN
  
  --test mode output
  
  S_OUT <= SERIAL_TEST(REGBNK_SIZE-1);
  
  --test mode input
  
  SERIAL_TEST(0) <= S_IN;
  
  --asynchronous data out
  
  A_OUT <= REG_DATA(TO_INTEGER(UNSIGNED(SEL_A)));
  B_OUT <= REG_DATA(TO_INTEGER(UNSIGNED(SEL_B)));
  
  --generates register bank
  
  --REGISTER 0
  --IS READ ONLY, ALWAYS READS 0x00
  
  REG0 : ENTITY WORK.RegSp(shift)
    GENERIC MAP(DATA_W)
    PORT MAP(
      SERIAL_OUT=>OPEN,
      CK=>'0',
      TEST=>'0',
      DATA_OUT=>REG_DATA(0),
      SERIAL_IN=>'0',
      PARALLEL_IN=>(OTHERS=>'0'),
      RST=>RST);
  
  --OTHER REGISTERS
  
  GEN_REG : FOR I IN 1 TO REGBNK_SIZE-1 GENERATE
    
    REGX : ENTITY WORK.RegSp(shift)
      GENERIC MAP(DATA_W)
      PORT MAP(
        SERIAL_OUT=>SERIAL_TEST(I),
        CK=>SUBCK,
        TEST=>TEST,
        DATA_OUT=>REG_DATA(I),
        SERIAL_IN=>SERIAL_TEST(I-1),
        PARALLEL_IN=>REG_IN_DATA(I),
        RST=>RST);
    
  END GENERATE;
  
  
  PROCESS(CK, RST, TEST)
    
  BEGIN
    
    IF RST = '1' THEN
      
      FOR I IN 0 TO REGBNK_SIZE-1 LOOP
        
        REG_IN_DATA(I) <= (OTHERS => '0');    
        
      END LOOP;

    ELSIF TEST = '0' THEN
      
      IF RISING_EDGE(CK) THEN
        
        --load registers; only A is verified because B has no data to be written
        
        CASE REG_CNT IS
          
          WHEN "100" => --MEM -> A
            
            REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W))) <= DATA_IN;
            
          WHEN "010" => --BYTE -> HI(A)

            REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W)))(DATA_W-1 DOWNTO W) <= BYTE_IN;

          WHEN "011" => --BYTE -> LOW(A)
            
            REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W)))(W-1 DOWNTO 0) <= BYTE_IN;
            
          WHEN "001" => --ALU -> A
            
            REG_IN_DATA(TO_INTEGER(UNSIGNED(SEL_W))) <= ALU_IN;
            
          WHEN OTHERS => NULL;
                         
        END CASE;
        
      END IF;

    END IF;
    
    --delayed clock for registers              
    SUBCK <= CK;
    
  END PROCESS;
  
END ARCHITECTURE;
