-------------------------------
--! @file fwunit.vhd
--! @brief pipeline instruction fetcher unit
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2014
-------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity anem16_ifetch is
  port(mclk       : in std_logic;
       mrst       : in std_logic;

       jflag     : in std_logic;
       jrflag    : in std_logic;
       jdest     : in std_logic_vector(15 downto 0);
       bzflag    : in std_logic;
       bzoff     : in std_logic_vector(11 downto 0);

       stall_n    : in std_logic; --! stall fetch
       
       nexti     : out std_logic_vector(15 downto 0) --! next address
       );
  
end entity;

architecture pipe of anem16_ifetch is
signal i_addr : std_logic_vector(15 downto 0);
signal initializing : std_logic;
begin

  nexti <= i_addr;
  
process(mclk,mrst)
begin

  if mrst = '1' then

    i_addr <= (others=>'0');
    initializing <= '0';

  elsif rising_edge(mclk) and stall_n = '1' then

    if initializing = '1' then
      initializing <= '0';
    else
    
    if jflag = '1' then

      --relative jump
      i_addr <= std_logic_vector(unsigned(unsigned(i_addr) + resize(signed(j_dest(11 downto 0)),16))));

    elsif jrflag = '1' then
      
      --unconditional jump from register!
      i_addr <= jdest;

    elsif bzflag = '1' then

      i_addr <= std_logic_vector(unsigned(signed(resize(signed(bzoff),16)) + unsigned(i_addr)));
      
    else

      --fetch from next address
      i_addr <= std_logic_vector(unsigned(i_addr) + 1);
      
    end if;

  end if;

  end if;

end process;


end architecture;
