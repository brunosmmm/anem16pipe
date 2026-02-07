-------------------------------
--! @file hazunit.vhd
--! @brief pipeline hazards unit
--! @author Bruno Morais <brunosmmm@gmail.com>
--! @date 2014
-------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity anem16_hazunit is

  port(mrst      : in std_logic;
       mclk      : in std_logic;
       bztrue    : in std_logic;
       bhleqtrue : in std_logic;

       p_stall_if_n   : out std_logic;
       p_stall_id_n   : out std_logic;
       p_stall_alu_n  : out std_logic;
       p_stall_mem_n  : out std_logic;

       --LW hazard detection (ALU stage)
       mem_en_alu       : in std_logic;
       mem_w_alu        : in std_logic;
       reg_sela_alu     : in std_logic_vector(3 downto 0);

       --ID stage (dependent instruction)
       reg_sela_id      : in std_logic_vector(3 downto 0);
       reg_selb_id      : in std_logic_vector(3 downto 0);
       mem_en_id        : in std_logic;
       mem_w_id         : in std_logic;
       next_instruction : in std_logic_vector(15 downto 0);

       --producer write-back info per stage
       regctl_alu       : in std_logic_vector(2 downto 0);
       reg_sela_mem     : in std_logic_vector(3 downto 0);
       regctl_mem       : in std_logic_vector(2 downto 0);
       reg_sela_wb      : in std_logic_vector(3 downto 0);
       regctl_wb        : in std_logic_vector(2 downto 0);

       --EPC write tracking (for MTEPC → RETI/MFEPC stall)
       epcwr_alu        : in std_logic;
       epcwr_mem        : in std_logic

       );

end entity;

architecture pipe of anem16_hazunit is
--deny-list: instructions in ID that do NOT read registers
signal id_reads_regs    : std_logic;
signal lw_hazard_detect : std_logic;
signal sw_data_hazard   : std_logic;
signal nfw_data_hazard  : std_logic;
signal sw_stall_if_n    : std_logic;
signal lw_stall_if_n    : std_logic;
signal nfw_stall_if_n   : std_logic;
signal jr_stall_if_n    : std_logic;
signal jr_data_hazard   : std_logic;
signal epc_stall_if_n   : std_logic;
signal epc_read_hazard  : std_logic;

signal bz_stall_if_n    : std_logic;
signal bz_stall_counter : std_logic_vector(1 downto 0);
begin

  p_stall_id_n <= '1';
  p_stall_alu_n <= '1';
  p_stall_mem_n <= '1';

  --instructions that do NOT read registers cannot cause data hazards
  id_reads_regs <= '0' when next_instruction(15 downto 12) = "0100" else  --LIU
                   '0' when next_instruction(15 downto 12) = "0101" else  --LIL
                   '0' when next_instruction(15 downto 12) = "1111" else  --J
                   '0' when next_instruction(15 downto 12) = "1101" else  --JAL
                   '0' when next_instruction(15 downto 12) = "1000" else  --BZ_X
                   '0' when next_instruction(15 downto 12) = "1001" else  --BZ_T
                   '0' when next_instruction(15 downto 12) = "1010" else  --BZ_N
                   '0' when next_instruction(15 downto 12) = "0110" else  --BHLEQ
                   '0' when next_instruction(15 downto 12) = "0111" and
                            next_instruction(3 downto 0) = "0001" else    --POP (reads SP not GPR)
                   '0' when next_instruction(15 downto 12) = "0111" and
                            next_instruction(3 downto 0) = "0010" else    --SPRD (reads SP not GPR)
                   '0' when next_instruction(15 downto 12) = "1110" and
                            next_instruction(11 downto 8) = "1011" else   --SYSCALL (no GPR read)
                   '0' when next_instruction(15 downto 12) = "1110" and
                            next_instruction(11 downto 8) = "1100" and
                            next_instruction(7 downto 4) /= "0101" else   --M4 except MTEPC
                   '1';

  --LW destination matches either source register of dependent instruction
  lw_hazard_detect <= '1' when reg_sela_alu = reg_sela_id and reg_sela_alu /= "0000" else
                      '1' when reg_sela_alu = reg_selb_id and reg_sela_alu /= "0000" else
                      '0';

  --LW stall: combinational, 1 cycle (WB forwarding provides LW data on the next cycle)
  lw_stall_if_n <= '0' when mem_en_alu = '1' and mem_w_alu = '0' and
                             lw_hazard_detect = '1' and id_reads_regs = '1' else
                   '1';

  --SW data register hazard: SW in ID, producer writing same register in ALU/MEM/WB
  sw_data_hazard <= '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_alu and regctl_alu /= "000" else
                    '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_mem and regctl_mem /= "000" else
                    '1' when mem_en_id = '1' and mem_w_id = '1' and reg_sela_id /= "0000" and
                             reg_sela_id = reg_sela_wb and regctl_wb /= "000" else
                    '0';

  sw_stall_if_n <= not sw_data_hazard;

  --NFW (non-forwardable write) stall: LIL/LIU/JAL/MFHI/MFLO in ALU/MEM/WB, dependent reads same reg
  --regctl "010"=LIU, "011"=LIL, "101"=JAL, "110"=MFHI, "111"=MFLO
  --these write registers but data is NOT on ALU path
  --combinational across 3 stages; auto-sustains as producer advances through pipeline
  nfw_data_hazard <=
    '1' when id_reads_regs = '1' and
             (regctl_alu = "010" or regctl_alu = "011" or regctl_alu = "101" or regctl_alu = "110" or regctl_alu = "111") and
             reg_sela_alu /= "0000" and
             (reg_sela_alu = reg_sela_id or reg_sela_alu = reg_selb_id) else
    '1' when id_reads_regs = '1' and
             (regctl_mem = "010" or regctl_mem = "011" or regctl_mem = "101" or regctl_mem = "110" or regctl_mem = "111") and
             reg_sela_mem /= "0000" and
             (reg_sela_mem = reg_sela_id or reg_sela_mem = reg_selb_id) else
    '1' when id_reads_regs = '1' and
             (regctl_wb = "010" or regctl_wb = "011" or regctl_wb = "101" or regctl_wb = "110" or regctl_wb = "111") and
             reg_sela_wb /= "0000" and
             (reg_sela_wb = reg_sela_id or reg_sela_wb = reg_selb_id) else
    '0';

  nfw_stall_if_n <= not nfw_data_hazard;

  --JR stall: JR reads register at ID stage (for jump destination), not at ALU.
  --No forwarding can fix this — must stall until the producer exits the pipeline.
  --Check ALU and MEM stages; WB is handled by register bank write-through bypass.
  --JR opcode = "1100"
  jr_data_hazard <=
    '1' when next_instruction(15 downto 12) = "1100" and
             regctl_alu /= "000" and reg_sela_alu /= "0000" and
             reg_sela_alu = reg_sela_id else
    '1' when next_instruction(15 downto 12) = "1100" and
             regctl_mem /= "000" and reg_sela_mem /= "0000" and
             reg_sela_mem = reg_sela_id else
    '0';

  jr_stall_if_n <= not jr_data_hazard;

  --EPC read stall: RETI or MFEPC in ID, MTEPC in ALU or MEM (WB handled by bypass)
  --RETI = M1 "1100" sub "0000", MFEPC = M1 "1100" sub "0011"
  epc_read_hazard <=
    '1' when next_instruction(15 downto 12) = "1110" and
             next_instruction(11 downto 8) = "1100" and
             (next_instruction(7 downto 4) = "0000" or next_instruction(7 downto 4) = "0011") and
             (epcwr_alu = '1' or epcwr_mem = '1') else
    '0';

  epc_stall_if_n <= not epc_read_hazard;

  p_stall_if_n <= lw_stall_if_n and sw_stall_if_n and bz_stall_if_n and nfw_stall_if_n and jr_stall_if_n and epc_stall_if_n;

--clocked process for BZ/BHLEQ stall only
process(mclk,mrst)
begin

  if mrst = '1' then

    bz_stall_if_n <= '1';
    bz_stall_counter <= "00";

  elsif rising_edge(mclk) then

    --bz/bhleq stalls
    if bz_stall_counter /= "00"then

      bz_stall_counter <= std_logic_vector(unsigned(bz_stall_counter) - 1);

    elsif bztrue = '1' or bhleqtrue = '1' then

      --hold until resolution
      bz_stall_if_n <= '0';
      bz_stall_counter <= "01";

    else

      --release
      bz_stall_if_n <= '1';

    end if;

  end if;

end process;

end architecture;
