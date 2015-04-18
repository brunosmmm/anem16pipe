-----------------------------
--! @file test_bench.vhd
--! @brief ANEM test bench
--! @date 2011,2014
-----------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY TEST_BENCH IS 
  GENERIC( N: NATURAL := 256);
END TEST_BENCH;

ARCHITECTURE TESTE OF TEST_BENCH IS

  SIGNAL CK, RST: STD_LOGIC := '0';
  SIGNAL INST: STD_LOGIC_VECTOR(15 DOWNTO 0);  --! next instruction 
  SIGNAL INST_ADDR: STD_LOGIC_VECTOR(15 DOWNTO 0):= (OTHERS => '0'); --! next instruction address
  SIGNAL TEST: STD_LOGIC := '0';  --! test mode enable
  SIGNAL MEM_W: STD_LOGIC;     --! memory write enable
  SIGNAL MEM_EN: STD_LOGIC;    --! memory enable

  SIGNAL DATA : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS=>'Z'); --! bidirectional data bus

  SIGNAL MEM_ADDR: STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL BIT_INST_OUT: STD_LOGIC;

  --gpio bus
  signal port_0 : std_logic_vector(15 downto 0);
  signal port_1 : std_logic_vector(15 downto 0);
  signal port_2 : std_logic_vector(15 downto 0);

BEGIN
  
  cpu:  entity work.ANEM(test)
    PORT MAP(CK=>CK,
             RST=>RST,
             TEST=>TEST,
             INST=>INST,
             S_IN=>'0',
             S_OUT=>BIT_INST_OUT,
             MEM_W=>MEM_W,
             MEM_EN=>MEM_EN,
             MEM_ADDR=>MEM_ADDR,
             DATA=>DATA,
             INST_ADDR=>INST_ADDR
             );

  imem: entity work.progmem(rom)
    PORT MAP(ck=>CK,
             en=>'1',
             address=>INST_ADDR(7 downto 0),
             instr=>INST
             );
  
  dmem: entity work.datamem(ram)
    PORT MAP(ck=>CK,
             en=>MEM_EN,
             w=>MEM_W,
             address=>MEM_ADDR,
             data=>DATA);

--MAC peripheral
  MAC: ENTITY WORK.MAC(MultAcc)
    PORT MAP(DATA=>DATA,
             CK=>CK,
             RST=>RST,
             ADDR=>MEM_ADDR,
             W=>MEM_W,
             EN=>MEM_EN,
             INT=>OPEN);

  --gpio
  gpio: entity work.anem_port_mux2(Behavioral)
  port map(mem_data=>data,
           mem_addr=>mem_addr,
           mem_w=>mem_w,
           mem_en=>mem_en,
           ck=>ck,
           rst=>rst,
           port_out=>port_0,
           port_in_1=>port_1,
           port_in_0=>port_2
           );

  PROCESS

  begin
    
    RST <=  '1';
    WAIT FOR 30NS;
    RST <=  '0';
    
    FOR I IN 0 TO 2048 LOOP                -- clk
      CK <= NOT CK;
      WAIT FOR 10 NS;
    END LOOP;
  END PROCESS;
END TESTE;
