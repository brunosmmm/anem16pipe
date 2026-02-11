------------------------------------------
--! @file ANEM.vhd
--! @brief ANEM main
------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.INSTRSET.ALL;

ENTITY ANEM IS
    
    GENERIC(DATA_SIZE : INTEGER := 16; --! data width
            OPCODE_SIZE : INTEGER := 4; --! opcode size in bits
            REGBNK_SIZE : INTEGER := 16; --! number of registers in bank
            ALUOP_SIZE  : INTEGER := 3; --! alu control signal width
            RINDEX_SIZE : INTEGER := 4; --! register bank indexing signal width
            ALUSHAMT_SIZE : INTEGER := 4; --! SHAMT field width
            ALUFUNC_SIZE : INTEGER := 4); --! FUNC field width

    PORT(CK,RST: IN STD_LOGIC;
        TEST: IN STD_LOGIC;                              --! TEST MODE ENABLE
        INST: IN STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); --! INSTRUCTION INPUT
        S_IN: IN STD_LOGIC;                              --! TEST MODE DATA IN
        S_OUT: OUT STD_LOGIC;                            --! TEST MODE DATA OUT
        MEM_W: OUT STD_LOGIC;                            --! DATA MEM WRITE FLAG
        MEM_EN: OUT STD_LOGIC;                           --! DATA MEM ENABLE FLAG
        MEM_ADDR: OUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); --! DATA MEM ADDRESS
        DATA : INOUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); --! DATA BUS
        INST_ADDR: OUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); --! INSTRUCTION FETCH ADDRESS
        INT: IN STD_LOGIC);                              --! EXTERNAL INTERRUPT
                                                              
END ANEM;

ARCHITECTURE TEST OF ANEM  IS
SIGNAL S_OUT_REG: STD_LOGIC;

SIGNAL TO_MEM: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL DATA_IN: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

signal next_inst_addr : std_logic_vector(15 downto 0);

--pipeline IF/ID
signal p_if_id_aneminst_0 : std_logic_vector(15 downto 0);
signal p_if_id_instaddr_0 : std_logic_vector(15 downto 0);

--pipeline signals originating from instruction decode
signal p_id_mem_alua_0      : std_logic_vector(data_size-1 downto 0);
signal p_id_alu_alub_0      : std_logic_vector(data_size-1 downto 0);
signal p_id_alu_aluctl_0   : std_logic_vector(aluop_size-1 downto 0);
signal p_id_alu_alushamt_0        : std_logic_vector(alushamt_size-1 downto 0);
signal p_id_alu_alufunc_0         : std_logic_vector(alufunc_size-1 downto 0);
signal p_id_wb_regctl_0          : std_logic_vector(2 downto 0);
signal p_id_wb_regsela_0         : std_logic_vector(rindex_size-1 downto 0);
signal p_id_alu_regselb_0          : std_logic_vector(rindex_size-1 downto 0);
signal p_id_x_jflag               : std_logic;
signal p_id_x_jrflag              : std_logic;
signal p_id_x_jdest               : std_logic_vector(15 downto 0);
signal p_id_wb_limm_0            : std_logic_vector(7 downto 0);
signal p_id_alu_bzflag_0        : std_logic;
signal p_id_alu_bzoff_0         : std_logic_vector(11 downto 0);
signal p_id_mem_memen_0           : std_logic;
signal p_id_mem_memw_0            : std_logic;

signal p_id_wb_iaddr_0     : std_logic_vector(15 downto 0);
signal p_id_alu_bhleqflag_0 : std_logic_vector(0 downto 0);

--special registers
signal p_id_wb_hictl_0 : std_logic_vector(2 downto 0);
signal p_id_wb_loctl_0 : std_logic_vector(2 downto 0);
signal p_id_wb_hiout_0 : std_logic_vector(15 downto 0);
signal p_id_wb_loout_0 : std_logic_vector(15 downto 0);
--HI/LO write-through bypass: when WB writes HI/LO at same edge ID reads
signal p_id_wb_hiout_0_mux : std_logic_vector(15 downto 0);
signal p_id_wb_loout_0_mux : std_logic_vector(15 downto 0);
signal p_id_wb_hiloen_0  : std_logic_vector(1 downto 0);
signal p_id_wb_himux_0 : std_logic_vector(1 downto 0);
signal p_id_wb_lomux_0 : std_logic_vector(1 downto 0);

--pipeline path after ID (ID->ALU)
signal p_id_wb_regsela_1 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_alu_regselb_1 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_1   : std_logic_vector(2 downto 0);
signal p_id_alu_aluctl_1   : std_logic_vector(aluop_size-1 downto 0);
signal p_id_alu_alushamt_1 : std_logic_vector(alushamt_size-1 downto 0);
signal p_id_alu_alufunc_1  : std_logic_vector(alufunc_size-1 downto 0);
signal p_id_wb_limm_1      : std_logic_vector(7 downto 0);
signal p_id_alu_bzflag_1  : std_logic;
signal p_id_alu_bzoff_1   : std_logic_vector(11 downto 0);
signal p_id_mem_memen_1     : std_logic;
signal p_id_mem_memw_1      : std_logic;
signal p_id_mem_alua_1       : std_logic_vector(15 downto 0);
signal p_id_alu_alub_1       : std_logic_vector(15 downto 0);
signal p_id_wb_iaddr_1   : std_logic_vector(15 downto 0);

signal p_id_wb_hictl_1 : std_logic_vector(2 downto 0);
signal p_id_wb_loctl_1 : std_logic_vector(2 downto 0);
signal p_id_wb_hiout_1 : std_logic_vector(15 downto 0);
signal p_id_wb_loout_1 : std_logic_vector(15 downto 0);
signal p_id_wb_hiloen_1  : std_logic_vector(1 downto 0);
signal p_id_wb_himux_1 : std_logic_vector(1 downto 0);
signal p_id_wb_lomux_1 : std_logic_vector(1 downto 0);
signal p_id_alu_bhleqflag_1 :std_logic_vector(0 downto 0);


--pipeline signals originating from ALU
signal p_alu_wb_aluout_1 : std_logic_vector(data_size-1 downto 0);
signal p_alu_mem_z_1     : std_logic;
signal p_alu_mem_z_2     : std_logic;
signal p_alu_mem_hieqlo_1 : std_logic_vector(0 downto 0);

--pipeline path after ALU (ALU->MEM)
signal p_alu_wb_aluout_2 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_limm_2    : std_logic_vector(7 downto 0);
signal p_id_mem_memen_2   : std_logic;
signal p_id_mem_memw_2    : std_logic;
signal p_id_mem_alua_2    : std_logic_vector(15 downto 0);
signal p_id_wb_regsela_2  : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_2   : std_logic_vector(2 downto 0);
signal p_id_wb_iaddr_2    : std_logic_vector(15 downto 0);

signal p_id_wb_hictl_2 : std_logic_vector(2 downto 0);
signal p_id_wb_loctl_2 : std_logic_vector(2 downto 0);
signal p_id_wb_hiout_2 : std_logic_vector(15 downto 0);
signal p_id_wb_loout_2 : std_logic_vector(15 downto 0);
signal p_id_wb_hiloen_2  : std_logic_vector(1 downto 0);
signal p_id_wb_himux_2 : std_logic_vector(1 downto 0);
signal p_id_wb_lomux_2 : std_logic_vector(1 downto 0);

signal p_alu_mem_hieqlo_2 : std_logic_vector(0 downto 0);

--pipeline signals originating from MEM
signal p_mem_wb_memout_2 : std_logic_vector(data_size-1 downto 0);

--pipeline path after MEM (MEM->WB)
signal p_alu_wb_aluout_3 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_limm_3    : std_logic_vector(7 downto 0);
signal p_mem_wb_memout_3 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_regsela_3 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_3  : std_logic_vector(2 downto 0);
signal p_id_wb_iaddr_3   : std_logic_vector(15 downto 0);
signal p_id_wb_alua_3    : std_logic_vector(15 downto 0);

signal p_id_wb_hictl_3 : std_logic_vector(2 downto 0);
signal p_id_wb_loctl_3 : std_logic_vector(2 downto 0);
signal p_id_wb_hiout_3 : std_logic_vector(15 downto 0);
signal p_id_wb_loout_3 : std_logic_vector(15 downto 0);
signal p_id_wb_hiloen_3  : std_logic_vector(1 downto 0);
signal p_id_wb_himux_3 : std_logic_vector(1 downto 0);
signal p_id_wb_lomux_3 : std_logic_vector(1 downto 0);

--pipeline stalling
signal p_stall_if_n  : std_logic;
signal p_stall_id_n  : std_logic;
signal p_stall_alu_n : std_logic;
signal p_stall_mem_n : std_logic;

signal p_s_alu_aluctl_mux : std_logic_vector(aluop_size-1 downto 0);
signal p_s_wb_regctl_mux  : std_logic_vector(2 downto 0);
signal p_s_alu_memenw_mux : std_logic_vector(1 downto 0);

--pipeline data forwarding
signal p_f_alu_alua_mux : std_logic_vector(data_size-1 downto 0);
signal p_f_alu_alub_mux : std_logic_vector(data_size-1 downto 0);

signal p_f_alu_alu_a : std_logic;
signal p_f_alu_alu_b : std_logic;
signal p_f_mem_alu_a : std_logic;
signal p_f_mem_alu_b : std_logic;
signal p_f_mem_mem   : std_logic;

signal p_f_regbnk_w_mem  : std_logic;
signal p_f_regbnk_w_wb   : std_logic;
signal p_f_wb_fwd_data   : std_logic_vector(data_size-1 downto 0);

--Z flag gating
signal p_z_en : std_logic;

--misc pipeline signals
signal p_bztrue     : std_logic;
signal p_alu_x_bzout : std_logic_vector(12 downto 0);
signal p_id_alu_bz_0 : std_logic_vector(12 downto 0);
signal p_alu_x_memop   : std_logic_vector(1 downto 0);
signal p_mem_x_memop   : std_logic_vector(1 downto 0);
signal p_id_wb1_regsela_4 : std_logic_vector(3 downto 0);

--flush
signal p_if_x_aneminst_mux : std_logic_vector(15 downto 0);
signal p_flush : std_logic;

--dummy signals
signal p_alu_mem_z_1_v : std_logic_vector(0 downto 0);
signal p_alu_mem_z_2_v : std_logic_vector(0 downto 0);

--special register muxes
signal hi_mux_data : std_logic_vector(15 downto 0);
signal lo_mux_data : std_logic_vector(15 downto 0);

--calculate immediate add values for HI/LO
signal ais_calculate_wb : std_logic_vector(31 downto 0);
signal ail_calculate_wb : std_logic_vector(15 downto 0);
signal aih_calculate_wb: std_logic_vector(15 downto 0);

--detect HI = LO asynchronously -- to decide BHLEQ on id phase
signal hi_equals_lo : std_logic;

--BHLEQ
signal p_bhleqtrue : std_logic;

--Stack Pointer signals
signal sp_reg_out      : std_logic_vector(15 downto 0); --SP register output
signal sp_forwarded    : std_logic_vector(15 downto 0); --SP after forwarding chain

--sp_ctl pipeline: "001"=PUSH, "010"=POP, "011"=SPRD, "100"=SPWR, "000"=none
signal p_id_wb_spctl_0    : std_logic_vector(2 downto 0);
signal p_id_wb_spctl_1    : std_logic_vector(2 downto 0);
signal p_id_wb_spctl_2    : std_logic_vector(2 downto 0);
signal p_id_wb_spctl_3    : std_logic_vector(2 downto 0);
signal p_s_wb_spctl_mux   : std_logic_vector(2 downto 0); --flush mux

--sp_val: SP value read at ID, pipelined to ALU
signal p_id_alu_spval_0   : std_logic_vector(15 downto 0);
signal p_id_alu_spval_1   : std_logic_vector(15 downto 0);

--sp_new: computed SP (ALU stage), pipelined to MEM and WB
signal p_sp_new_1         : std_logic_vector(15 downto 0);
signal p_sp_new_2         : std_logic_vector(15 downto 0);
signal p_sp_new_3         : std_logic_vector(15 downto 0);

--sp_addr: memory address for PUSH/POP (ALU stage), pipelined to MEM
signal p_sp_addr_1        : std_logic_vector(15 downto 0);
signal p_sp_addr_2        : std_logic_vector(15 downto 0);

--SP write enables per stage (for forwarding chain)
signal sp_writes_1        : std_logic;
signal sp_writes_2        : std_logic;
signal sp_writes_3        : std_logic;

--ADDI immediate select pipeline
signal p_id_alu_immsel_0  : std_logic_vector(0 downto 0);
signal p_id_alu_immsel_1  : std_logic_vector(0 downto 0);

--ALU input overrides
signal alu_a_final        : std_logic_vector(data_size-1 downto 0);
signal alu_b_final        : std_logic_vector(data_size-1 downto 0);

--MEM_ADDR mux
signal mem_addr_final     : std_logic_vector(data_size-1 downto 0);

--Interrupt/Exception signals
signal epc_reg            : std_logic_vector(15 downto 0); --EPC register
signal eca_reg            : std_logic_vector(15 downto 0); --ECA register
signal ien_reg            : std_logic;                     --IEN (interrupt enable)
signal epc_bypass         : std_logic_vector(15 downto 0); --EPC with write-through bypass

--Decoder output flags
signal p_id_x_syscall_flag : std_logic;
signal p_id_x_reti_flag    : std_logic;
signal p_id_x_ei_flag      : std_logic;
signal p_id_x_di_flag      : std_logic;
signal p_id_wb_excctl_0    : std_logic_vector(2 downto 0); --exc_ctl from decoder

--exc_ctl pipeline: ID->ALU->MEM->WB
signal p_id_wb_excctl_1    : std_logic_vector(2 downto 0);
signal p_id_wb_excctl_2    : std_logic_vector(2 downto 0);
signal p_id_wb_excctl_3    : std_logic_vector(2 downto 0);
signal p_s_wb_excctl_mux   : std_logic_vector(2 downto 0); --flush mux

--epcwr pipeline: tracks MTEPC through pipeline for write at WB
signal p_id_wb_epcwr_0     : std_logic_vector(0 downto 0);
signal p_id_wb_epcwr_1     : std_logic_vector(0 downto 0);
signal p_id_wb_epcwr_2     : std_logic_vector(0 downto 0);
signal p_id_wb_epcwr_3     : std_logic_vector(0 downto 0);
signal p_s_wb_epcwr_mux    : std_logic_vector(0 downto 0); --flush mux

--External interrupt logic
signal ext_int_take        : std_logic;
signal p_exc_flag          : std_logic;
signal p_flush_no_int      : std_logic;
signal syscall_flag_gated  : std_logic;
signal p_flush_if          : std_logic;  -- IF/ID flush (ALU-stage branches + interrupts only)
signal p_in_delay_slot     : std_logic;  -- registered: delay slot is currently in ID

BEGIN

    --BIDIRECTIONAL DATA BUS

    --cannot have simultaneous read/write of register! selector is only one
    --have to detect if writeback is going on and stall instruction decode /
    --register read

    inst_addr <= next_inst_addr;
    p_id_wb_iaddr_0 <= std_logic_vector(unsigned(next_inst_addr) + 1);

    --generate BZ flag from decoded instruction and old Z flag
    p_bztrue <= p_id_alu_bzflag_1 and p_alu_mem_z_2;
    --generate BHLEQ flag from instruction and HI = LO flag
    p_bhleqtrue <= '1' when p_id_alu_bhleqflag_1(0) = '1' and p_alu_mem_hieqlo_2(0) = '1' else
                   '0';
    --! instruction fetcher
    pfetch : entity work.anem16_ifetch(pipe)
      port map(mclk=>ck,
               mrst=>rst,
               jflag=>p_id_x_jflag and not p_in_delay_slot,
               jdest=>p_id_x_jdest,
               jrflag=>(p_id_x_jrflag or p_id_x_reti_flag) and not p_in_delay_slot,
               nexti=>next_inst_addr,
               stall_n=>p_stall_if_n,
               bzflag=>p_bztrue,
               bzoff=>p_id_alu_bzoff_1,
               bhleqflag=>p_bhleqtrue,
               exc_flag=>p_exc_flag,
               exc_vector=>ANEM_EXC_VECTOR
               );
               
    
    --! Instruction decoder
    pdecode: entity work.anem16_idecode(pipe)
      port map(mclk=>ck,
               mrst=>rst,
               instr_addr=>p_if_id_instaddr_0,
               instruction=>p_if_id_aneminst_0,
               regbnk_ctl=>p_id_wb_regctl_0,
               regbnk_sela=>p_id_wb_regsela_0,
               regbnk_aout=>p_id_mem_alua_0,
               regbnk_selb=>p_id_alu_regselb_0,
               alu_ctl=>p_id_alu_aluctl_0,
               alu_func=>p_id_alu_alufunc_0,
               alu_shamt=>p_id_alu_alushamt_0,
               j_flag=>p_id_x_jflag,
               j_dest=>p_id_x_jdest,
               jr_flag=>p_id_x_jrflag,
               bz_flag=>p_id_alu_bzflag_0,
               bz_off=>p_id_alu_bzoff_0,
               mem_en=>p_id_mem_memen_0,
               mem_w=>p_id_mem_memw_0,
               limmval=>p_id_wb_limm_0,
               hi_en=>p_id_wb_hiloen_0(0),
               lo_en=>p_id_wb_hiloen_0(1),
               hi_ctl=>p_id_wb_hictl_0,
               lo_ctl=>p_id_wb_loctl_0,
               hi_mux=>p_id_wb_himux_0,
               lo_mux=>p_id_wb_lomux_0,
               bhleq_flag=>p_id_alu_bhleqflag_0(0),
               sp_ctl=>p_id_wb_spctl_0,
               alu_imm_sel=>p_id_alu_immsel_0(0),
               epc_in=>epc_bypass,
               syscall_flag=>p_id_x_syscall_flag,
               reti_flag=>p_id_x_reti_flag,
               ei_flag=>p_id_x_ei_flag,
               di_flag=>p_id_x_di_flag,
               exc_ctl=>p_id_wb_excctl_0
               );
    
    --! @todo adjust control to account for HI/LO Inputs. Also adjust inside idecode
    --! Register bank
    regbnk: ENTITY WORK.regbnk(ANEM)
      PORT MAP(S_IN=>S_IN,
               TEST=>TEST,
               ALU_IN=>p_alu_wb_aluout_3,
               BYTE_IN=>p_id_wb_limm_3,
               PC_IN=>p_id_wb_iaddr_3,
               HI_IN=>p_id_wb_hiout_3,
               LO_IN=>p_id_wb_loout_3,
               SEL_A=>p_id_wb_regsela_0, 
               SEL_B=>p_id_alu_regselb_0,
               DATA_IN=>p_mem_wb_memout_3,
               CK=>CK,
               RST=>RST,
               REG_CNT=>p_id_wb_regctl_3,
               A_OUT=>p_id_mem_alua_0,
               B_OUT=>p_id_alu_alub_0,
               S_OUT=>S_OUT_REG,
               SEL_W=>p_id_wb_regsela_3);

    --special registers

    --calculate AIS/AIL/AIH
    ais_calculate_wb <= std_logic_vector(signed(p_id_wb_hiout_3&p_id_wb_loout_3) +
                                         resize(signed(p_id_wb_limm_3),32));
    ail_calculate_wb <= std_logic_vector(signed(p_id_wb_loout_3) +
                                         resize(signed(p_id_wb_limm_3),16));
    aih_calculate_wb <= std_logic_vector(signed(p_id_wb_hiout_3) +
                                         resize(signed(p_id_wb_limm_3),16));

    --! @todo: change signal p_id_mem_alua to go up to wb
    
    hi_mux_data <= p_id_wb_alua_3 when p_id_wb_himux_3 = "10" else
                   aih_calculate_wb when p_id_wb_himux_3 = "01" else
                   ais_calculate_wb(31 downto 16) when p_id_wb_himux_3 = "00" else
                   (others=>'0');

    lo_mux_data <= p_id_wb_alua_3 when p_id_wb_lomux_3 = "10" else
                   ail_calculate_wb when p_id_wb_lomux_3 = "01" else
                   ais_calculate_wb(15 downto 0) when p_id_wb_lomux_3 = "00" else
                   (others=>'0');

    --detect HI = LO at ALU stage
    p_alu_mem_hieqlo_1(0) <= '1' when p_id_wb_hiout_1 = p_id_wb_loout_1 else
                                '0';
    
    --! HI register skeleton
    reghi: entity work.RegANEMB(shift)
    port map(ck=>ck,
               rst=>rst,
               en=>p_id_wb_hiloen_3(0), --pipelined, to write on WB
               parallel_in=>hi_mux_data, --pipelined
               data_out=>p_id_wb_hiout_0, --pipelined, saved on decode
               byte_in=>p_id_wb_limm_3, --pipelined, written on WB
               control=>p_id_wb_hictl_3); --pipelined, to write on WB

    --! LO register skeleton
    reglo: entity work.RegANEMB(shift)
    port map(ck=>ck,
               rst=>rst,
               en=>p_id_wb_hiloen_3(1), --pipelined, to write on WB
               parallel_in=>lo_mux_data, --pipelined
               data_out=>p_id_wb_loout_0, --pipelined, saved on decode
               byte_in=>p_id_wb_limm_3, --pipelined, written on WB
               control=>p_id_wb_loctl_3); --pipelined, to write on WB

    --WB forwarding data mux: select ALU result or LW memory data
    p_f_wb_fwd_data <= p_mem_wb_memout_3 when p_id_wb_regctl_3 = "100" else
                       p_alu_wb_aluout_3;

    --forwarding muxes (ALU stage = newer value has priority over MEM stage)
    p_f_alu_alua_mux <= p_alu_wb_aluout_2 when p_f_alu_alu_a = '1' else
                        p_f_wb_fwd_data   when p_f_mem_alu_a = '1' else
                        p_id_mem_alua_1;

    p_f_alu_alub_mux <= p_alu_wb_aluout_2 when p_f_alu_alu_b = '1' else
                        p_f_wb_fwd_data   when p_f_mem_alu_b = '1' else
                        p_id_alu_alub_1;

    --ALU_A override: SPRD uses SP, MFEPC uses EPC, MFECA uses ECA
    alu_a_final <= p_id_alu_spval_1 when p_id_wb_spctl_1 = "011" else  --SPRD
                   epc_bypass       when p_id_wb_excctl_1 = "001" else  --MFEPC: ALU_A=EPC
                   eca_reg          when p_id_wb_excctl_1 = "010" else  --MFECA: ALU_A=ECA
                   p_f_alu_alua_mux;

    --ALU_B override: ADDI uses sign-extended 8-bit immediate; SPRD/MFEPC/MFECA/MTEPC use zero
    alu_b_final <= (15 downto 8 => p_id_wb_limm_1(7)) & p_id_wb_limm_1
                     when p_id_alu_immsel_1(0) = '1' else   --ADDI: sign-extend imm8
                   (others => '0') when p_id_wb_spctl_1 = "011" else  --SPRD: B=0, compute SP+0
                   (others => '0') when p_id_wb_excctl_1 /= "000" else  --MFEPC/MFECA/MTEPC: B=0
                   p_f_alu_alub_mux;

    --! ALU
    alu: ENTITY WORK.ALU(behavior)
      GENERIC MAP(N=>DATA_SIZE)
      PORT MAP(ALU_A=>alu_a_final,
               ALU_B=>alu_b_final,
               SHAMT=>p_id_alu_alushamt_1,
               ALU_OP=>p_id_alu_aluctl_1,
               FUNC=>p_id_alu_alufunc_1,
               Z=>p_alu_mem_z_1,
               ALU_OUT=>p_alu_wb_aluout_1);
    
    --PIPELINE ID/ALU
    PALU_A: entity WORK.RegANEM(Load)
      generic MAP(DATA_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_id_mem_alua_0,
               DATA_OUT=>p_id_mem_alua_1);
    
    PALU_B: entity WORK.RegANEM(Load)
      generic MAP(DATA_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_id_alu_alub_0,
               DATA_OUT=>p_id_alu_alub_1);


    --! stall/flush multiplexer
    p_s_alu_aluctl_mux <= p_id_alu_aluctl_0 when p_stall_if_n = '1' else
                          "000";
    PALU_OP: entity WORK.RegANEM(Load)
      generic MAP(ALUOP_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_s_alu_aluctl_mux,
               DATA_OUT=>p_id_alu_aluctl_1);

    PALU_SHAMT : entity WORK.RegANEM(Load)
      generic MAP(alushamt_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_alushamt_0,
               data_out=>p_id_alu_alushamt_1);
    
    PALU_func : entity WORK.RegANEM(Load)
      generic MAP(alufunc_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_alufunc_0,
               data_out=>p_id_alu_alufunc_1);

    p_s_wb_regctl_mux <= p_id_wb_regctl_0 when p_stall_if_n = '1' else
                         "000";
    PREG_cnt_0  : entity WORK.RegANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_s_wb_regctl_mux,
               data_out=>p_id_wb_regctl_1);
    
    PREG_sel_a_0  : entity WORK.RegANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_regsela_0,
               data_out=>p_id_wb_regsela_1);
    
    PREG_sel_b_0  : entity WORK.RegANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_regselb_0,
               data_out=>p_id_alu_regselb_1);
    
    preg_imm_0 : entity work.RegANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_limm_0,
               data_out=>p_id_wb_limm_1);

    p_id_alu_bzflag_1 <= p_alu_x_bzout(12);
    p_id_alu_bzoff_1  <= p_alu_x_bzout(11 downto 0);
    p_id_alu_bz_0 <= p_id_alu_bzflag_0 & p_id_alu_bzoff_0;
    preg_bz_0 : entity work.RegANEM(Load)
      generic map(13)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_bz_0,
               data_out=>p_alu_x_bzout);

    preg_bhleq_0 : entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_bhleqflag_0,
               data_out=>p_id_alu_bhleqflag_1);

    p_s_alu_memenw_mux <= p_id_mem_memen_0 & p_id_mem_memw_0 when p_stall_if_n = '1' else
                          "00";
    p_id_mem_memw_1 <= p_alu_x_memop(0);
    p_id_mem_memen_1 <= p_alu_x_memop(1);
    preg_memop_0 : entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_s_alu_memenw_mux,
               data_out=>p_alu_x_memop);

    preg_iaddr_0: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_iaddr_0,
               data_out=>p_id_wb_iaddr_1);

    preg_hictl_0: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_hictl_0,
               data_out=>p_id_wb_hictl_1);

    preg_loctl_0: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_loctl_0,
               data_out=>p_id_wb_loctl_1);

    --HI/LO write-through bypass muxes: when WB writes HI/LO at the same
    --rising_edge that ID reads them, the RegANEMB output has the stale value.
    --Compute the post-write value and feed it to the pipeline register.
    p_id_wb_hiout_0_mux <=
      p_id_wb_limm_3 & p_id_wb_hiout_0(7 downto 0)
        when p_id_wb_hiloen_3(0) = '1' and p_id_wb_hictl_3 = "010" else  --LHH: upper byte new
      p_id_wb_hiout_0(15 downto 8) & p_id_wb_limm_3
        when p_id_wb_hiloen_3(0) = '1' and p_id_wb_hictl_3 = "011" else  --LHL: lower byte new
      hi_mux_data
        when p_id_wb_hiloen_3(0) = '1' and (p_id_wb_hictl_3 = "100" or p_id_wb_hictl_3 = "001") else
      p_id_wb_hiout_0;

    p_id_wb_loout_0_mux <=
      p_id_wb_limm_3 & p_id_wb_loout_0(7 downto 0)
        when p_id_wb_hiloen_3(1) = '1' and p_id_wb_loctl_3 = "010" else  --LLH: upper byte new
      p_id_wb_loout_0(15 downto 8) & p_id_wb_limm_3
        when p_id_wb_hiloen_3(1) = '1' and p_id_wb_loctl_3 = "011" else  --LLL: lower byte new
      lo_mux_data
        when p_id_wb_hiloen_3(1) = '1' and (p_id_wb_loctl_3 = "100" or p_id_wb_loctl_3 = "001") else
      p_id_wb_loout_0;

    preg_hiout_0: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_hiout_0_mux,
               data_out=>p_id_wb_hiout_1);

    preg_loout_0: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_loout_0_mux,
               data_out=>p_id_wb_loout_1);

    preg_hiloen_0: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_hiloen_0,
               data_out=>p_id_wb_hiloen_1);

    preg_himux_0: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_himux_0,
               data_out=>p_id_wb_himux_1);

    preg_lomux_0: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_lomux_0,
               data_out=>p_id_wb_lomux_1);

    --SP register (process-based for non-zero reset to 0xFFCF)
    sp_reg: process(ck, rst)
    begin
      if rst = '1' then
        sp_reg_out <= x"FFCF";
      elsif rising_edge(ck) then
        if sp_writes_3 = '1' then
          sp_reg_out <= p_sp_new_3;
        end if;
      end if;
    end process;

    --SP write enables per stage (PUSH, POP, SPWR all write SP)
    sp_writes_1 <= '1' when p_id_wb_spctl_1 = "001" or p_id_wb_spctl_1 = "010" or p_id_wb_spctl_1 = "100" else '0';
    sp_writes_2 <= '1' when p_id_wb_spctl_2 = "001" or p_id_wb_spctl_2 = "010" or p_id_wb_spctl_2 = "100" else '0';
    sp_writes_3 <= '1' when p_id_wb_spctl_3 = "001" or p_id_wb_spctl_3 = "010" or p_id_wb_spctl_3 = "100" else '0';

    --SP forwarding chain (combinational at ID stage, newest wins)
    sp_forwarded <= p_sp_new_1  when sp_writes_1 = '1' else  --ALU (newest)
                    p_sp_new_2  when sp_writes_2 = '1' else  --MEM
                    p_sp_new_3  when sp_writes_3 = '1' else  --WB
                    sp_reg_out;                               --register

    --SP value captured at ID stage (forwarded)
    p_id_alu_spval_0 <= sp_forwarded;

    --SP adder (at ALU stage, parallel to main ALU)
    --PUSH: sp_new = SP-1, sp_addr = SP-1 (pre-decrement, write to new SP)
    --POP:  sp_new = SP+1, sp_addr = SP   (post-increment, read from old SP)
    --SPWR: sp_new = forwarded register value (from ALU_A path)
    p_sp_new_1 <= std_logic_vector(unsigned(p_id_alu_spval_1) - 1) when p_id_wb_spctl_1 = "001" else  --PUSH
                  std_logic_vector(unsigned(p_id_alu_spval_1) + 1) when p_id_wb_spctl_1 = "010" else  --POP
                  p_f_alu_alua_mux                                 when p_id_wb_spctl_1 = "100" else  --SPWR
                  p_id_alu_spval_1;

    p_sp_addr_1 <= std_logic_vector(unsigned(p_id_alu_spval_1) - 1) when p_id_wb_spctl_1 = "001" else  --PUSH: write to SP-1
                   p_id_alu_spval_1                                 when p_id_wb_spctl_1 = "010" else  --POP: read from SP
                   (others => '0');

    --sp_ctl flush mux (zero on flush/stall, same condition as regctl)
    p_s_wb_spctl_mux <= p_id_wb_spctl_0 when p_stall_if_n = '1' else
                        "000";

    --Pipeline ID/ALU: sp_ctl
    preg_spctl_0: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_id_n,
               parallel_in=>p_s_wb_spctl_mux,
               data_out=>p_id_wb_spctl_1);

    --Pipeline ID/ALU: sp_val (forwarded SP)
    preg_spval_0: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck, rst=>rst, en=>p_stall_id_n,
               parallel_in=>p_id_alu_spval_0,
               data_out=>p_id_alu_spval_1);

    --Pipeline ID/ALU: alu_imm_sel
    preg_immsel_0: entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck, rst=>rst, en=>p_stall_id_n,
               parallel_in=>p_id_alu_immsel_0,
               data_out=>p_id_alu_immsel_1);

    --Pipeline ID/ALU: exc_ctl (with flush mux)
    p_s_wb_excctl_mux <= p_id_wb_excctl_0 when p_stall_if_n = '1' else
                         "000";
    preg_excctl_0: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_id_n,
               parallel_in=>p_s_wb_excctl_mux,
               data_out=>p_id_wb_excctl_1);

    --Pipeline ID/ALU: epcwr (MTEPC marker, with flush mux)
    p_id_wb_epcwr_0(0) <= '1' when p_id_wb_excctl_0 = "011" else '0';
    p_s_wb_epcwr_mux(0) <= p_id_wb_epcwr_0(0) when p_stall_if_n = '1' else
                            '0';
    preg_epcwr_0: entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck, rst=>rst, en=>p_stall_id_n,
               parallel_in=>p_s_wb_epcwr_mux,
               data_out=>p_id_wb_epcwr_1);

    --EPC register (process-based, written by SYSCALL, ext_int, MTEPC at WB)
    epc_proc: process(ck, rst)
    begin
      if rst = '1' then
        epc_reg <= x"0000";
      elsif rising_edge(ck) then
        if syscall_flag_gated = '1' then
          --SYSCALL: save return address (next_inst_addr + 1 = SYSCALL_addr + 2)
          epc_reg <= p_id_wb_iaddr_0;
        elsif ext_int_take = '1' then
          --External interrupt: save flushed instruction address (re-execute after RETI)
          epc_reg <= next_inst_addr;
        elsif p_id_wb_epcwr_3(0) = '1' then
          --MTEPC at WB: write from ALU output
          epc_reg <= p_alu_wb_aluout_3;
        end if;
      end if;
    end process;

    --ECA register (process-based, written by SYSCALL and ext_int)
    eca_proc: process(ck, rst)
    begin
      if rst = '1' then
        eca_reg <= x"0000";
      elsif rising_edge(ck) then
        if syscall_flag_gated = '1' then
          --SYSCALL: bit 8 = 1 for software trap, bits 7:0 = service number
          eca_reg <= "0000000" & '1' & p_if_id_aneminst_0(7 downto 0);
        elsif ext_int_take = '1' then
          --External interrupt: bit 8 = 0, bits 7:0 = 0xFF
          eca_reg <= x"00FF";
        end if;
      end if;
    end process;

    --IEN register (process-based, interrupt enable)
    ien_proc: process(ck, rst)
    begin
      if rst = '1' then
        ien_reg <= '0';
      elsif rising_edge(ck) then
        if syscall_flag_gated = '1' or ext_int_take = '1' then
          --Exception entry: disable interrupts
          ien_reg <= '0';
        elsif p_id_x_ei_flag = '1' and p_stall_if_n = '1' and p_in_delay_slot = '0' then
          --EI: enable interrupts
          ien_reg <= '1';
        elsif p_id_x_di_flag = '1' and p_stall_if_n = '1' and p_in_delay_slot = '0' then
          --DI: disable interrupts
          ien_reg <= '0';
        elsif p_id_x_reti_flag = '1' and p_stall_if_n = '1' and p_in_delay_slot = '0' then
          --RETI: re-enable interrupts
          ien_reg <= '1';
        end if;
      end if;
    end process;

    --Delay slot tracking: set when any branch/jump/exception fires, cleared next unstalled cycle
    delay_slot_track: process(ck, rst)
    begin
      if rst = '1' then
        p_in_delay_slot <= '0';
      elsif rising_edge(ck) then
        if p_stall_if_n = '1' then
          p_in_delay_slot <= p_id_x_jflag or p_id_x_jrflag or p_id_x_reti_flag
                             or syscall_flag_gated or p_bztrue or p_bhleqtrue;
        end if;
      end if;
    end process;

    --EPC write-through bypass: when MTEPC writes at WB and RETI/MFEPC reads at ID
    epc_bypass <= p_alu_wb_aluout_3 when p_id_wb_epcwr_3(0) = '1' else
                  epc_reg;


    --PIPELINE ALU/MEM
    PREG_ctl_1  : entity WORK.RegANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regctl_1,
               data_out=>p_id_wb_regctl_2);
    
    PREG_sela_1  : entity WORK.RegANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regsela_1,
               data_out=>p_id_wb_regsela_2);

    preg_imm_1: entity work.RegANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_limm_1,
               data_out=>p_id_wb_limm_2);

    preg_alua_1: entity work.RegANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_mem_alua_1,
               data_out=>p_id_mem_alua_2);
                                                                                 
    preg_aluout_0: ENTITY WORK.RegANEM(Load)
      GENERIC MAP(DATA_SIZE)
      PORT MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_alu_n,
               PARALLEL_IN=>p_alu_wb_aluout_1,
               DATA_OUT=>p_alu_wb_aluout_2);

    preg_iaddr_1: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_iaddr_1,
               data_out=>p_id_wb_iaddr_2);

    preg_hictl_1: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_hictl_1,
               data_out=>p_id_wb_hictl_2);

    preg_loctl_1: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_loctl_1,
               data_out=>p_id_wb_loctl_2);

    preg_hiout_1: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_hiout_1,
               data_out=>p_id_wb_hiout_2);

    preg_loout_1: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_loout_1,
               data_out=>p_id_wb_loout_2);

    preg_hiloen_1: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_hiloen_1,
               data_out=>p_id_wb_hiloen_2);


    preg_himux_1: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_himux_1,
               data_out=>p_id_wb_himux_2);

    preg_lomux_1: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_lomux_1,
               data_out=>p_id_wb_lomux_2);

    --Pipeline ALU/MEM: sp_ctl
    preg_spctl_1: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_alu_n,
               parallel_in=>p_id_wb_spctl_1,
               data_out=>p_id_wb_spctl_2);

    --Pipeline ALU/MEM: sp_new
    preg_spnew_1: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck, rst=>rst, en=>p_stall_alu_n,
               parallel_in=>p_sp_new_1,
               data_out=>p_sp_new_2);

    --Pipeline ALU/MEM: sp_addr (memory address for PUSH/POP)
    preg_spaddr_1: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck, rst=>rst, en=>p_stall_alu_n,
               parallel_in=>p_sp_addr_1,
               data_out=>p_sp_addr_2);

    --Pipeline ALU/MEM: exc_ctl
    preg_excctl_1: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_alu_n,
               parallel_in=>p_id_wb_excctl_1,
               data_out=>p_id_wb_excctl_2);

    --Pipeline ALU/MEM: epcwr
    preg_epcwr_1: entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck, rst=>rst, en=>p_stall_alu_n,
               parallel_in=>p_id_wb_epcwr_1,
               data_out=>p_id_wb_epcwr_2);

    --ALU Flag register (only update Z for R-type and S-type ALU operations)
    --dummy vectors
    p_alu_mem_z_1_v(0) <= p_alu_mem_z_1;
    p_alu_mem_z_2 <= p_alu_mem_z_2_v(0);
    p_z_en <= '1' when p_stall_alu_n = '1' and
                        (p_id_alu_aluctl_1 = "001" or p_id_alu_aluctl_1 = "010") else
              '0';
    PALU_Z: entity WORK.RegANEM(Load)
      generic map(1)
      port map(CK=>CK,
               RST=>RST,
               EN=>p_z_en,
               PARALLEL_IN=>p_alu_mem_z_1_v,
               DATA_OUT=>p_alu_mem_z_2_v);

    p_id_mem_memw_2 <= p_mem_x_memop(0);
    p_id_mem_memen_2 <= p_mem_x_memop(1);
    preg_memop_1 : entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_alu_x_memop,
               data_out=>p_mem_x_memop);

    --MEM_ADDR mux: use SP address for PUSH/POP, else ALU output (LW/SW)
    mem_addr_final <= p_sp_addr_2 when p_id_wb_spctl_2 = "001" or p_id_wb_spctl_2 = "010" else
                      p_alu_wb_aluout_2;
    MEM_ADDR <= mem_addr_final;
    TO_MEM  <= p_id_mem_alua_2;
    MEM_EN  <= p_id_mem_memen_2;
    MEM_W   <= p_id_mem_memw_2;
    p_mem_wb_memout_2 <= DATA;

    DATA <= TO_MEM WHEN (p_id_mem_memen_2='1' AND p_id_mem_memw_2='1') ELSE
             (OTHERS=>'Z');


    --HI = LO flag
    preg_hieqlo_1: entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_alu_mem_hieqlo_1,
               data_out=>p_alu_mem_hieqlo_2);
    
    --PIPELINE MEM/WB
    preg_memout: entity work.RegANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_mem_wb_memout_2,
               data_out=>p_mem_wb_memout_3);

    preg_aluout_1: entity work.RegANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_alu_wb_aluout_2,
               data_out=>p_alu_wb_aluout_3);

    PREG_ctl_2  : entity WORK.RegANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_regctl_2,
               data_out=>p_id_wb_regctl_3);
    
    PREG_sela_2  : entity WORK.RegANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_regsela_2,
               data_out=>p_id_wb_regsela_3);

    preg_imm_2: entity work.RegANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_limm_2,
               data_out=>p_id_wb_limm_3);

    preg_iaddr_2: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_iaddr_2,
               data_out=>p_id_wb_iaddr_3);

    preg_hictl_2: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_hictl_2,
               data_out=>p_id_wb_hictl_3);

    preg_loctl_2: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_loctl_2,
               data_out=>p_id_wb_loctl_3);

    preg_hiout_2: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_hiout_2,
               data_out=>p_id_wb_hiout_3);

    preg_loout_2: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_loout_2,
               data_out=>p_id_wb_loout_3);

    preg_hiloen_2: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_hiloen_2,
               data_out=>p_id_wb_hiloen_3);

    preg_himux_2: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_himux_2,
               data_out=>p_id_wb_himux_3);

    preg_lomux_2: entity work.RegANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_id_wb_lomux_2,
               data_out=>p_id_wb_lomux_3);

    --Pipeline MEM/WB: sp_ctl
    preg_spctl_2: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_mem_n,
               parallel_in=>p_id_wb_spctl_2,
               data_out=>p_id_wb_spctl_3);

    --Pipeline MEM/WB: sp_new
    preg_spnew_2: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck, rst=>rst, en=>p_stall_mem_n,
               parallel_in=>p_sp_new_2,
               data_out=>p_sp_new_3);

    --Pipeline MEM/WB: exc_ctl
    preg_excctl_2: entity work.RegANEM(Load)
      generic map(3)
      port map(ck=>ck, rst=>rst, en=>p_stall_mem_n,
               parallel_in=>p_id_wb_excctl_2,
               data_out=>p_id_wb_excctl_3);

    --Pipeline MEM/WB: epcwr
    preg_epcwr_2: entity work.RegANEM(Load)
      generic map(1)
      port map(ck=>ck, rst=>rst, en=>p_stall_mem_n,
               parallel_in=>p_id_wb_epcwr_2,
               data_out=>p_id_wb_epcwr_3);

    palu_a_3: entity WORK.RegANEM(Load)
      generic MAP(DATA_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_mem_n,
               PARALLEL_IN=>p_id_mem_alua_2,
               DATA_OUT=>p_id_wb_alua_3);
    
    --! flush mux (only flush for ALU-stage branches and interrupts; ID-stage delay slots pass through)
    p_flush_if <= p_bztrue or p_bhleqtrue or ext_int_take;
    p_if_x_aneminst_mux <= inst when p_flush_if = '0' else
                           (others=>'0');
    
    RINST: ENTITY WORK.RegANEM(Load)
      GENERIC MAP(DATA_SIZE)
      PORT MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_if_n,
               PARALLEL_IN=>p_if_x_aneminst_mux,
               DATA_OUT=>p_if_id_aneminst_0);

    raddr: entity work.RegANEM(Load)
      generic map(16)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_if_n,
               parallel_in=>next_inst_addr,
               data_out=>p_if_id_instaddr_0);


    p_regsela_plus: entity work.RegANEM(Load)
      generic map(4)
      port map(ck=>ck,
               rst=>rst,
               en=>'1',
               parallel_in=>p_id_wb_regsela_3,
               data_out=>p_id_wb1_regsela_4
               );

    
    --forwarding enables: only forward when data is available on the forwarding path
    --MEM stage: only R/S-type ALU results (regctl "001")
    p_f_regbnk_w_mem <= '1' when p_id_wb_regctl_2 = "001" else
                        '0';
    --WB stage: R/S-type ALU results ("001") or LW memory data ("100")
    p_f_regbnk_w_wb  <= '1' when p_id_wb_regctl_3 = "001" or p_id_wb_regctl_3 = "100" else
                        '0';
    
    --! forwarding unit
    pfw: entity work.anem16_fwunit(pipe)
      port map(reg_sela_wb=>p_id_wb_regsela_3,
               reg_sela_mem=>p_id_wb_regsela_2,
               reg_sela_alu=>p_id_wb_regsela_1,
               reg_selb_alu=>p_id_alu_regselb_1,

               regbnk_write_mem=>p_f_regbnk_w_mem,
               regbnk_write_wb=>p_f_regbnk_w_wb,
               mem_enable=>p_id_mem_memen_1,
               aluctl=>p_id_alu_aluctl_1,
               f_alu_alu_a=>p_f_alu_alu_a,
               f_alu_alu_b=>p_f_alu_alu_b,
               f_mem_alu_a=>p_f_mem_alu_a,
               f_mem_alu_b=>p_f_mem_alu_b

               );

    --SYSCALL gating: suppress during flush/stall/delay slot
    syscall_flag_gated <= p_id_x_syscall_flag when p_stall_if_n = '1'
        and p_bztrue = '0' and p_bhleqtrue = '0' and p_in_delay_slot = '0' else '0';

    --flush pipeline on taken branches/jumps/exceptions (gate ID-stage flags during delay slot)
    p_flush_no_int <= (p_id_x_jflag and not p_in_delay_slot)
                  or (p_id_x_jrflag and not p_in_delay_slot)
                  or (p_id_x_reti_flag and not p_in_delay_slot)
                  or p_bztrue or p_bhleqtrue or syscall_flag_gated;

    --External interrupt detection (combinational, "quiet cycle", blocked during delay slot)
    ext_int_take <= INT and ien_reg and (not p_flush_no_int) and (not p_in_delay_slot) and p_stall_if_n;

    --Exception flag: drives ifetch to exception vector
    p_exc_flag <= syscall_flag_gated or ext_int_take;

    --Combined flush
    p_flush <= p_flush_no_int or ext_int_take;

    --! hazard unit
    phaz: entity work.anem16_hazunit(pipe)
      port map(mrst=>rst,
               mclk=>ck,

               p_stall_if_n=>p_stall_if_n,
               p_stall_id_n=>p_stall_id_n,
               p_stall_alu_n=>p_stall_alu_n,
               p_stall_mem_n=>p_stall_mem_n,

               mem_en_alu=>p_id_mem_memen_1,
               mem_w_alu=>p_id_mem_memw_1,
               reg_sela_alu=>p_id_wb_regsela_1,

               reg_sela_id=>p_id_wb_regsela_0,
               reg_selb_id=>p_id_alu_regselb_0,
               mem_en_id=>p_id_mem_memen_0,
               mem_w_id=>p_id_mem_memw_0,

               next_instruction=>p_if_id_aneminst_0,

               regctl_alu=>p_id_wb_regctl_1,
               reg_sela_mem=>p_id_wb_regsela_2,
               regctl_mem=>p_id_wb_regctl_2,
               reg_sela_wb=>p_id_wb_regsela_3,
               regctl_wb=>p_id_wb_regctl_3,

               epcwr_alu=>p_id_wb_epcwr_1(0),
               epcwr_mem=>p_id_wb_epcwr_2(0)
               );
               


END TEST;
