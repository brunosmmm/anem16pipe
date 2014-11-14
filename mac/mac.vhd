---------------------------------------------------------
--! @file mac.vhd
--! @brief  Multiply-accumulate peripheral
--! @author Bruno Morais <brunosmmm@gmail.com>
---------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY MAC IS

  GENERIC(REG_SIZE : INTEGER := 16; --! Operand size
          ACC_SIZE: INTEGER := 32;  --! Accumulator size
          MEM_ADDR_SIZE: INTEGER := 16; --! Memory address size
          CONFIG_MAC_ADDR : STD_LOGIC_VECTOR := x"FFD4"; --! CONFIG_MAC address
          A_SU_ADDR : STD_LOGIC_VECTOR := x"FFD5"; --! A / SU address
          B_SL_ADDR : STD_LOGIC_VECTOR := x"FFD6"; --! B / SL address
          
          --1 is r/w
          --0 is read-only
          CONFIG_MAC_ACCESS_MASK : STD_LOGIC_VECTOR := "1010111100000111"; --! Write-access mask for CONFIG_MAC
          
          CONFIG_MAC_DEFAULT_VAL : STD_LOGIC_VECTOR := "0101000000000000" --! default configuration state
          );
  
  PORT(
    DATA : INOUT STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);  --! data in/out
    ADDR: IN STD_LOGIC_VECTOR(MEM_ADDR_SIZE-1 DOWNTO 0); --! memory mapped address
    W : IN STD_LOGIC; --! read/write
    EN : IN STD_LOGIC; --! enable
    CK : IN STD_LOGIC;
    RST: IN STD_LOGIC;
    
    INT : OUT STD_LOGIC --! interrupt output
    );
  
  
END ENTITY;


ARCHITECTURE MultAcc OF MAC IS

  SIGNAL WEN : STD_LOGIC := '0'; --! WRITE ENABLE
  SIGNAL REN : STD_LOGIC := '0'; --! READ ENABLE

  SIGNAL CONFIG_MAC_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := CONFIG_MAC_DEFAULT_VAL;
  SIGNAL CONFIG_MAC_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := CONFIG_MAC_DEFAULT_VAL;
  SIGNAL A_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
  SIGNAL B_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

  SIGNAL SU_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
  SIGNAL SL_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

  SIGNAL SU_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL SL_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

  SIGNAL DATA_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

--writable registers:
--SEL_REG_A_SU : A / SU
--SEL_REG_B_SL : B / SL
--SEL_REG_CONFIG_MAC : CONFIG_MAC
--SEL_REG_NONE: No selection
  TYPE REG_SEL IS (SEL_REG_A_SU, SEL_REG_B_SL, SEL_REG_CONFIG_MAC, SEL_REG_NONE); 

--currently selected register
  SIGNAL MAC_REG_SEL : REG_SEL := SEL_REG_NONE;

--internal register enable logic
  SIGNAL CONFIG_MAC_WEN : STD_LOGIC := '0';
  SIGNAL A_WEN : STD_LOGIC := '0';
  SIGNAL B_WEN : STD_LOGIC := '0';

--accumulator signals
  SIGNAL ACC_OUT : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL ACC_IN : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL OP_ACC : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS=>'0');

  SIGNAL ACC_RDY : STD_LOGIC := '0'; --! ready/not ready
  SIGNAL ACC_OVR : STD_LOGIC := '0'; --! overflow detected
  SIGNAL ACC_COUT : STD_LOGIC := '0'; --! carry out
  SIGNAL ACC_ZERO : STD_LOGIC := '0'; --! zero flag

  SIGNAL ACC_RST : STD_LOGIC := '0'; --! acc reset
  SIGNAL ACC_MAC_RST : STD_LOGIC := '0'; --! internal acc rst by mac

--multiplier signals
  SIGNAL MULT_A : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL MULT_B : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL OP_MULT : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL MULT_OUT : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

  SIGNAL MULT_RDY : STD_LOGIC := '0';


--! Converts boolean to std_logic
  FUNCTION BOOL_TO_STDLOGIC(INP : BOOLEAN) return STD_LOGIC is
  BEGIN
    
    IF INP THEN
      RETURN '1';
    ELSE
      RETURN '0';
    END IF;
    
  END FUNCTION BOOL_TO_STDLOGIC;

--mac states
--MAC_WAIT : initial, load or write data
--MAC_MULT : multiplication going on
--MAC_ACC : accumulating

  TYPE ESTADOS_MAC IS (MAC_WAIT, MAC_MULT, MAC_ACC);

--! current state
  SIGNAL EMAC : ESTADOS_MAC := MAC_WAIT;

--ALIASES
  ALIAS CONFIG_MAC_MOK   : STD_LOGIC IS CONFIG_MAC_OUT(6); --! FLAG MOK -- multiplication OK
  ALIAS CONFIG_MAC_INT   : STD_LOGIC IS CONFIG_MAC_OUT(7); --! FLAG INT -- interrupt occurred
  ALIAS CONFIG_MAC_IE    : STD_LOGIC IS CONFIG_MAC_OUT(11); --! FLAG IE -- interrupt enable
  ALIAS CONFIG_MAC_OVR   : STD_LOGIC IS CONFIG_MAC_OUT(5); --! FLAG OVR -- multiplication overflow
  ALIAS CONFIG_MAC_COUT  : STD_LOGIC IS CONFIG_MAC_OUT(3); --! FLAG COUT -- multiplication carry out
  ALIAS CONFIG_MAC_Z     : STD_LOGIC IS CONFIG_MAC_OUT(4); --! FLAG ZERO -- zero flag
  ALIAS CONFIG_MAC_ACR   : STD_LOGIC IS CONFIG_MAC_OUT(10); --! ACCUMULATOR RESET -- resets accumulator
  ALIAS CONFIG_MAC_OPACC : STD_LOGIC_VECTOR(1 DOWNTO 0) IS CONFIG_MAC_OUT(15 DOWNTO 14); --OP_ACC
  ALIAS CONFIG_MAC_OPMULT: STD_LOGIC_VECTOR(1 DOWNTO 0) IS CONFIG_MAC_OUT(13 DOWNTO 12); --OP_MULT

BEGIN

  --two ways to reset accumulator
  ACC_RST <= ACC_MAC_RST OR RST;
  
  --interrupt
  INT <= CONFIG_MAC_INT;
  
  --CONFIG_MAC write logic
  CONFIG_MAC_IN <= (DATA AND CONFIG_MAC_ACCESS_MASK) OR (CONFIG_MAC_IN AND (NOT CONFIG_MAC_ACCESS_MASK));
  
  WEN <= W AND EN; --WRITE ENABLE
  REN <= (NOT W) AND EN; --READ ENABLE
  
  --data in/out
  DATA <= DATA_OUT WHEN REN = '1' ELSE
          (OTHERS=>'Z');
  
  
  --MUX / DEMUX
  
  
  MAC_REG_SEL <= SEL_REG_CONFIG_MAC WHEN ADDR = CONFIG_MAC_ADDR ELSE
                 SEL_REG_A_SU WHEN ADDR = A_SU_ADDR ELSE
                 SEL_REG_B_SL WHEN ADDR = B_SL_ADDR ELSE
                 SEL_REG_NONE;  
  
  DATA_OUT <= CONFIG_MAC_OUT  WHEN MAC_REG_SEL = SEL_REG_CONFIG_MAC ELSE
               SU_OUT WHEN MAC_REG_SEL = SEL_REG_A_SU ELSE
               SL_OUT WHEN MAC_REG_SEL = SEL_REG_B_SL ELSE
               (OTHERS=>'0');
  
  --write enable signals 
  
  --write conditions:
  --1. write enabled
  --2. address match
  --3. MAC state is MAC_WAIT
  
  CONFIG_MAC_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_CONFIG_MAC) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
  A_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_A_SU) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
  B_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_B_SL) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
  
  --Internal registers

  REG_A : ENTITY WORK.RegANEM(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>A_OUT, EN=>A_WEN, PARALLEL_IN=>DATA, CK=>CK, RST=>RST);
  REG_B : ENTITY WORK.RegANEM(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>B_OUT, EN=>B_WEN, PARALLEL_IN=>DATA, CK=>CK, RST=>RST);
  
  REG_SU: ENTITY WORK.RegANEM(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>SU_OUT, EN=>'1', PARALLEL_IN=>SU_IN, CK=>CK, RST=>RST);
  REG_SL: ENTITY WORK.RegANEM(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>SL_OUT, EN=>'1', PARALLEL_IN=>SL_IN, CK=>CK, RST=>RST);
  
  --accumulator
  
  ACC: ENTITY WORK.AcumuladorMAC(ACC) GENERIC MAP(ACC_SIZE) PORT MAP(DATA_OUT=>ACC_OUT, DATA_IN=>ACC_IN, OP_ACC=>OP_ACC, CK=>CK, ACC_RDY=>ACC_RDY, RST=>ACC_RST, C=>ACC_COUT, OVR=>ACC_OVR, Z=>ACC_ZERO);
  
  --accumulator signals
  
  SU_IN <= ACC_OUT(ACC_SIZE-1 DOWNTO REG_SIZE);
  SL_IN <= ACC_OUT(REG_SIZE-1 DOWNTO 0);
  
  ACC_IN <= MULT_OUT;
  
  --multiplier
  
  MULT: ENTITY WORK.MultiplicadorMAC(MULT) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>MULT_OUT, A_IN=>MULT_A, B_IN=>MULT_B, OP_MULT=>OP_MULT, CK=>CK, MULT_RDY=>MULT_RDY);
  
  MULT_A <= A_OUT;
  MULT_B <= B_OUT;
  
  --mac state machine
  
  PROCESS(CK, RST)
    
  BEGIN
    
    IF RST = '1' THEN
      
      CONFIG_MAC_OUT <= CONFIG_MAC_DEFAULT_VAL;
      EMAC <= MAC_WAIT;
      
    ELSIF RISING_EDGE(CK) THEN
      
      --accumulator reset lift
      
      IF ACC_MAC_RST = '1' THEN
        ACC_MAC_RST <= '0';
      END IF;
      
      IF CONFIG_MAC_WEN = '1' THEN
        
        CONFIG_MAC_OUT <= CONFIG_MAC_IN;
        
      END IF;
      
      CASE EMAC IS
        
        
        WHEN MAC_MULT =>
          
          IF MULT_RDY = '1' THEN
            
            --multiplication ended
            OP_ACC <= CONFIG_MAC_OPACC; --acc enable
            EMAC <= MAC_ACC;
            
            --disable mult
            OP_MULT <= "00";
            
          ELSE
            
            --wait
            EMAC <= MAC_MULT;
            
          END IF;
          
        WHEN MAC_ACC =>
          
          IF ACC_RDY = '1' THEN
            
            --acc finished
            
            EMAC <= MAC_WAIT;
            
            --interrupt logic below
            
            --forward overflow flag
            CONFIG_MAC_OVR <= ACC_OVR;
            
            IF ACC_OVR = '0' THEN
              
              --no overflow, MOK = 1
              
              CONFIG_MAC_MOK <= '1';
              
            ELSE
              
              --overflow, MOK = 0
              
              CONFIG_MAC_MOK <= '0';
              
            END IF;
            
            --forward flags
            CONFIG_MAC_COUT <= ACC_COUT;
            CONFIG_MAC_Z <= ACC_ZERO;
            
            --Interrupts  : always generated when the operation ends
            --              must read configuration registers and analyze flags to determine interrupt source
            
            IF CONFIG_MAC_IE = '1' THEN
              
              CONFIG_MAC_INT <= '1';
              
            END IF;
            
            OP_ACC <= "00";
            
          ELSE

            --waiting on acc
            
            EMAC <= MAC_ACC;
            
          END IF;
          
          
        WHEN MAC_WAIT =>
          
          
          --polls accumulator reset bit
          IF CONFIG_MAC_ACR = '1' THEN
            
            ACC_MAC_RST <= '1';
            
            CONFIG_MAC_ACR <= '0';
            
          END IF;
          
          
          IF EN='1' AND MAC_REG_SEL /= SEL_REG_NONE THEN
            
            --address match, enabled
            
            IF W='1' THEN
              
              --write access
              
              --if operand is written on register B, multiplication starts automatically
              
              IF MAC_REG_SEL = SEL_REG_B_SL THEN
                
                --enable mult
                OP_MULT <= CONFIG_MAC_OPMULT;
                
                EMAC <= MAC_MULT;
                
              ELSIF MAC_REG_SEL = SEL_REG_CONFIG_MAC THEN
                
                --empty

              END IF;
              
              
            ELSE 
              
              --read access
              
              IF MAC_REG_SEL = SEL_REG_CONFIG_MAC THEN
                
                --CONFIG_MAC read clears flags
                
                CONFIG_MAC_INT <= '0';
                CONFIG_MAC_MOK <= '0';
                CONFIG_MAC_OVR <= '0';
                CONFIG_MAC_COUT <= '0';
                CONFIG_MAC_Z <= '0';
                
              END IF;
              
              
            END IF;
            
          ELSE
            
            EMAC <= MAC_WAIT; --no change
            
          END IF;
          
      END CASE;
      
    END IF;
    
  END PROCESS;
  
END ARCHITECTURE;
