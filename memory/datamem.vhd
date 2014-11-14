-------------------------------
--! @file datamem.vhd
--! @brief data memory emulation
--! @date 2011
--! @todo properly document and restructure
-------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity datamem is
  generic(
          addr_w     : integer := 16; --! address width
          data_w     : integer := 16; --!data width
          
          --! data memory boundary / peripheral virtual memory start
          MEM_BOUND : INTEGER := CONV_INTEGER(x"FFCF"));
          
          
  port(ck, en, w : in std_logic;
       address   : in std_logic_vector (addr_w-1 downto 0);
       
       data : INOUT STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0));
       
end datamem;

architecture ram of datamem is

type memory_array is array (MEM_BOUND downto 0) of std_logic_vector(data_w-1 downto 0);

signal ram: memory_array; --! memory array

SIGNAL D_OUT : STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL D_IN : STD_LOGIC_VECTOR(N_DADOS-1 DOWNTO 0) := (OTHERS=>'0');

begin

    --! bidirectional data bus
    data <= D_IN WHEN (EN='1' AND W='0' AND (address <= MEM_BOUND)) ELSE
             (OTHERS=>'Z');
             
    D_OUT <= data;


process (ck)
  begin
    if rising_edge(ck) then
      if(en = '1') then
        if(w = '1') then
            IF (address <= MEM_BOUND) THEN
                ram(conv_integer(address)) <= d_out;     
            END IF;
        end if;
      end if;
    end if;
end process;



 d_in <= ram(conv_integer(address)) when (en = '1' AND (address <= MEM_BOUND)) else
         (others => '0');
    
end ram;

