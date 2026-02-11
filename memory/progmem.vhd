---------------------------------
--! @file progmem.vhd
--! @brief instruction memory emulation
--! @date 2011
--! @todo properly document and restructure
---------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_unsigned.all;

entity progmem is
  generic (addr_w        : integer := 16; --! address width
           instr_w      : integer := 16); --! data width
  port(ck,en         : in std_logic;
       address       : in std_logic_vector(addr_w-1 downto 0); --! address
       instr      : out std_logic_vector(15 downto 0) --! instruction
       );
end progmem;

architecture rom  of progmem is
  type rom_array is array (((2**addr_w)-1) downto 0) of std_logic_vector(instr_w-1 downto 0);
  signal rom: rom_array;

begin
  
  process
    
    file contents : text open read_mode is "contents.txt";
    variable iline : line;

    variable addr, inst : bit_vector (instr_w-1 downto 0); 
    
  begin
    
    while not endfile(contents) loop
      
      readline(contents, iline);
      read(iline, addr);
      
      read(iline, inst);
      
      rom(conv_integer(to_stdlogicvector(addr))) <= to_stdlogicvector(inst);  
      
    end loop;      
    
    wait;
    
  end process;
  
  process(address) 
  begin
    
    if (en = '1') then
      instr <= rom(conv_integer(address));
    else instr <= (others => 'Z');
         
    end if; 
    
  end process;
  
  
end architecture; 
