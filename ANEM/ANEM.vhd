LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ANEM IS
    
    GENERIC(DATA_SIZE : INTEGER := 16;
            OPCODE_SIZE : INTEGER := 4;
            REGBNK_SIZE : INTEGER := 16;
            ALUOP_SIZE  : INTEGER := 3;
            RINDEX_SIZE : INTEGER := 4;
            ALUSHAMT_SIZE : INTEGER := 4;
            ALUFUNC_SIZE : INTEGER := 4);

    PORT(CK,RST: IN STD_LOGIC;            
        TEST: IN STD_LOGIC;                              -- RECEBE BIT DE TESTE
        INST: IN STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); -- RECEBE INSTRUCAO A SER REALIZADA
        S_IN: IN STD_LOGIC;                              -- RECEBE INSTRUCAO SERIAL DE TESTE
        --DATA_IN: IN STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0);       -- DADO LIDO DA MD
        S_OUT: OUT STD_LOGIC;                            -- ENVIA INSTRUCAO SERIAL DE TESTE
        MEM_W: OUT STD_LOGIC;                            -- INFORMACAO CONTROLE/MD
        MEM_EN: OUT STD_LOGIC;                           -- INFORMACAO CONTROLE/MD
        MEM_END: OUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0);
        --TO_MEM: OUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0);
        
        DADOS : INOUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); --BARRAMENTO DE DADOS
        
        INST_END: OUT STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0));    -- ENVIA PROXIMA INSTRUCAO
END ANEM;

ARCHITECTURE TESTE OF ANEM  IS
---------------------------------SAIDAS INTERNAS----------------------------- 
--SIGNAL REG_CONT: STD_LOGIC_VECTOR(2 DOWNTO 0);       -- INFORMACAO CONTROLE/REGISTRADOR
--SIGNAL PC_CONT: STD_LOGIC_VECTOR(2 DOWNTO 0);        -- INFORMACAO CONTROLE/PC
--SIGNAL ULA_CONT: STD_LOGIC_VECTOR(2 DOWNTO 0);       -- INFORMACAO CONTROLE/ULA
--SIGNAL A_OUT, B_OUT: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0);  -- SAIDAS DO REGISTRADOR
--SIGNAL ULA_OUT: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0);       -- SAIDA DA ULA
--SIGNAL Z: STD_LOGIC;                                 -- SAIDA DA ULA
SIGNAL S_OUT_REG: STD_LOGIC;                         -- SAIDA SERIAL DE TESTE DO REGISTRADOR P PC

--SIGNAL RI_EN : STD_LOGIC := '0'; --SINAL DE ENABLE PARA O REGISTRADOR DE INSTRUCAO
--SIGNAL ANEM_INST : STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0'); --INSTRUCAO

--SIGNAL RU_EN : STD_LOGIC := '0'; --SINAL DE ENABLE PARA O REGISTRADOR DA ULA
--SIGNAL RU_OUT : STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0'); --SAIDA DO REGISTRADOR DA ULA

--OPCODE DA INSTRUCAO
--ALIAS ANEM_OPCODE : STD_LOGIC_VECTOR(OPCODE_SIZE-1 DOWNTO 0) IS ANEM_INST(DATA_SIZE-1 DOWNTO DATA_SIZE-OPCODE_SIZE);
--ALIAS ANEM_REG_A : STD_LOGIC_VECTOR(RINDEX_SIZE-1 DOWNTO 0) IS ANEM_INST(11 DOWNTO 8);
--ALIAS ANEM_SHAMT : STD_LOGIC_VECTOR(ALUSHAMT_SIZE-1 DOWNTO 0) IS ANEM_INST(7 DOWNTO 4);
--ALIAS ANEM_FUNC : STD_LOGIC_VECTOR(ALUFUNC_SIZE-1 DOWNTO 0) IS ANEM_INST(3 DOWNTO 0);

--ALIAS ANEM_REG_B : STD_LOGIC_VECTOR(RINDEX_SIZE-1 DOWNTO 0) IS ANEM_INST(7 DOWNTO 4);
--ALIAS ANEM_OFFSET : STD_LOGIC_VECTOR(3 DOWNTO 0) IS ANEM_INST(3 DOWNTO 0);

--ALIAS ANEM_BYTE : STD_LOGIC_VECTOR(7 DOWNTO 0) IS ANEM_INST(7 DOWNTO 0);

--ALIAS ANEM_ENDE : STD_LOGIC_VECTOR(11 DOWNTO 0) IS ANEM_INST(11 DOWNTO 0);

--COMPATIBILIZACAO COM SINAIS ANTIGOS
SIGNAL TO_MEM: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL DATA_IN: STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

--ROTEAMENTO INTERNO DE SINAIS DE CONTROLE DA MEMORIA
--SIGNAL ANEM_MEM_EN : STD_LOGIC := '0';
--SIGNAL ANEM_MEM_W : STD_LOGIC := '0';

signal next_inst_addr : std_logic_vector(15 downto 0);

--pipeline IF/ID
signal p_if_id_aneminst_0 : std_logic_vector(15 downto 0);

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
signal p_id_alu_beqflag_0        : std_logic;
signal p_id_alu_beqoff_0         : std_logic_vector(3 downto 0);
signal p_id_mem_memen_0           : std_logic;
signal p_id_mem_memw_0            : std_logic;

--pipeline path after ID (ID->ALU)
signal p_id_wb_regsela_1 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_alu_regselb_1 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_1   : std_logic_vector(2 downto 0);
signal p_id_alu_aluctl_1   : std_logic_vector(aluop_size-1 downto 0);
signal p_id_alu_alushamt_1 : std_logic_vector(alushamt_size-1 downto 0);
signal p_id_alu_alufunc_1  : std_logic_vector(alufunc_size-1 downto 0);
signal p_id_wb_limm_1      : std_logic_vector(7 downto 0);
signal p_id_alu_beqflag_1  : std_logic;
signal p_id_alu_beqoff_1   : std_logic_vector(3 downto 0);
signal p_id_mem_memen_1     : std_logic;
signal p_id_mem_memw_1      : std_logic;
signal p_id_mem_alua_1       : std_logic_vector(15 downto 0);
signal p_id_alu_alub_1       : std_logic_vector(15 downto 0);

--pipeline signals originating from ALU
signal p_alu_wb_aluout_1 : std_logic_vector(data_size-1 downto 0);
signal p_alu_x_z          : std_logic;

--pipeline path after ALU (ALU->MEM)
signal p_alu_wb_aluout_2 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_limm_2    : std_logic_vector(7 downto 0);
signal p_id_mem_memen_2   : std_logic;
signal p_id_mem_memw_2    : std_logic;
signal p_id_mem_alua_2    : std_logic_vector(15 downto 0);
signal p_id_wb_regsela_2  : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_2   : std_logic_vector(2 downto 0);

--pipeline signals originating from MEM
signal p_mem_wb_memout_2 : std_logic_vector(data_size-1 downto 0);

--pipeline path after MEM (MEM->WB)
signal p_alu_wb_aluout_3 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_limm_3    : std_logic_vector(7 downto 0);
signal p_mem_wb_memout_3 : std_logic_vector(data_size-1 downto 0);
signal p_id_wb_regsela_3 : std_logic_vector(rindex_size-1 downto 0);
signal p_id_wb_regctl_3  : std_logic_vector(2 downto 0);

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

signal p_f_regbnk_w  : std_logic;

--misc pipeline signals
signal p_beqtrue     : std_logic;
signal p_alu_x_beqout : std_logic_vector(4 downto 0);
signal p_id_alu_beq_0 : std_logic_vector(4 downto 0);
signal p_alu_x_memop   : std_logic_vector(1 downto 0);
signal p_mem_x_memop   : std_logic_vector(1 downto 0);
signal p_id_wb1_regsela_4 : std_logic_vector(3 downto 0);

--flush
signal p_if_x_aneminst_mux : std_logic_vector(15 downto 0);
signal p_flush : std_logic;

BEGIN

    --BARRAMENTO DE DADOS BIDIRECIONAL

    --cannot have simultaneous read/write of register! selector is only one
    --have to detect if writeback is going on and stall instruction decode /
    --register read

    inst_end <= next_inst_addr;
    p_beqtrue <= p_id_alu_beqflag_1 and p_alu_x_z;
    --instruction fetch
    pfetch : entity work.anem16_ifetch(pipe)
      port map(mclk=>ck,
               mrst=>rst,
               jflag=>p_id_x_jflag,
               jdest=>p_id_x_jdest,
               jrflag=>p_id_x_jrflag,
               nexti=>next_inst_addr,
               stall_n=>p_stall_if_n,
               beqflag=>p_beqtrue,
               beqoff=>p_id_alu_beqoff_1
               );
               
    
    --Instruction decode
    pdecode: entity work.anem16_idecode(pipe)
      port map(mclk=>ck,
               mrst=>rst,
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
               beq_flag=>p_id_alu_beqflag_0,
               beq_off=>p_id_alu_beqoff_0,
               mem_en=>p_id_mem_memen_0,
               mem_w=>p_id_mem_memw_0,
               limmval=>p_id_wb_limm_0
               );
    
    
    --UNIDADE DE CONTROLE
    --CONT: ENTITY WORK.unidade_de_controle(teste) PORT MAP(OPCODE=>ANEM_OPCODE, CONTROL_REG=>REG_CONT, CONTROL_ULA=>ULA_CONT, 
    --                                                        CONTROL_PC=>PC_CONT, W_DADOS=>ANEM_MEM_W, EN_DADOS=>ANEM_MEM_EN,
    --                                                        CK=>CK, RST=>RST, RI_EN=>RI_EN, RU_EN=>RU_EN, will_wb=>i_wb);
    
    --BANCO DE REGISTRADORES
    BANCOREG: ENTITY WORK.BancoReg(ANEM)
      PORT MAP(S_IN=>S_IN,
               TEST=>TEST,
               ULA_IN=>p_alu_wb_aluout_3,
               BYTE_IN=>p_id_wb_limm_3,
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

    --forwarding muxes
    p_f_alu_alua_mux <= p_alu_wb_aluout_3 when p_f_mem_alu_a = '1' else
                        p_alu_wb_aluout_2 when p_f_alu_alu_a = '1' else
                        p_id_mem_alua_1;
    
    p_f_alu_alub_mux <= p_alu_wb_aluout_3 when p_f_mem_alu_b = '1' else
                        p_alu_wb_aluout_2 when p_f_alu_alu_b = '1' else
                        p_id_alu_alub_1;
  
    --ALU
    ULA: ENTITY WORK.Ula(behavior)
      GENERIC MAP(N=>DATA_SIZE)
      PORT MAP(ULA_A=>p_f_alu_alua_mux,
               ULA_B=>p_f_alu_alub_mux,
               SHAMT=>p_id_alu_alushamt_1,
               ULA_OP=>p_id_alu_aluctl_1, 
               FUNC=>p_id_alu_alufunc_1,
               Z=>p_alu_x_z,
               ULA_OUT=>p_alu_wb_aluout_1);
    
    --PIPELINE ID/ALU
    PALU_A: entity WORK.RegistradorANEM(Load)
      generic MAP(DATA_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_id_mem_alua_0,
               DATA_OUT=>p_id_mem_alua_1);
    
    PALU_B: entity WORK.RegistradorANEM(Load)
      generic MAP(DATA_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_id_alu_alub_0,
               DATA_OUT=>p_id_alu_alub_1);


    --stall multiplexer
    p_s_alu_aluctl_mux <= p_id_alu_aluctl_0 when p_stall_if_n = '1' else
                          "000";
    PALU_OP: entity WORK.RegistradorANEM(Load)
      generic MAP(ALUOP_SIZE)
      port MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_id_n,
               PARALLEL_IN=>p_s_alu_aluctl_mux,
               DATA_OUT=>p_id_alu_aluctl_1);

    PALU_SHAMT : entity WORK.RegistradorANEM(Load)
      generic MAP(alushamt_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_alushamt_0,
               data_out=>p_id_alu_alushamt_1);
    
    PALU_func : entity WORK.RegistradorANEM(Load)
      generic MAP(alufunc_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_alufunc_0,
               data_out=>p_id_alu_alufunc_1);

    p_s_wb_regctl_mux <= p_id_wb_regctl_0 when p_stall_if_n = '1' else
                         "000";
    PREG_cnt_0  : entity WORK.RegistradorANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_s_wb_regctl_mux,
               data_out=>p_id_wb_regctl_1);
    
    PREG_sel_a_0  : entity WORK.RegistradorANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_regsela_0,
               data_out=>p_id_wb_regsela_1);
    
    PREG_sel_b_0  : entity WORK.RegistradorANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_regselb_0,
               data_out=>p_id_alu_regselb_1);
    
    preg_imm_0 : entity work.RegistradorANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_wb_limm_0,
               data_out=>p_id_wb_limm_1);

    p_id_alu_beqflag_1 <= p_alu_x_beqout(4);
    p_id_alu_beqoff_1  <= p_alu_x_beqout(3 downto 0);
    p_id_alu_beq_0 <= p_id_alu_beqflag_0 & p_id_alu_beqoff_0;
    preg_beq_0 : entity work.RegistradorANEM(Load)
      generic map(5)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_id_alu_beq_0,
               data_out=>p_alu_x_beqout);

    p_s_alu_memenw_mux <= p_id_mem_memen_0 & p_id_mem_memw_0 when p_stall_if_n = '1' else
                          "00";
    p_id_mem_memw_1 <= p_alu_x_memop(0);
    p_id_mem_memen_1 <= p_alu_x_memop(1);
    preg_memop_0 : entity work.RegistradorANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_s_alu_memenw_mux,
               data_out=>p_alu_x_memop);

    --PIPELINE ALU/MEM
    PREG_ctl_1  : entity WORK.RegistradorANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regctl_1,
               data_out=>p_id_wb_regctl_2);
    
    PREG_sela_1  : entity WORK.RegistradorANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regsela_1,
               data_out=>p_id_wb_regsela_2);

    preg_imm_1: entity work.RegistradorANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_limm_1,
               data_out=>p_id_wb_limm_2);

    preg_alua_1: entity work.RegistradorANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_mem_alua_1,
               data_out=>p_id_mem_alua_2);
                                                                                 
    preg_aluout_0: ENTITY WORK.RegistradorANEM(Load)
      GENERIC MAP(DATA_SIZE)
      PORT MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_alu_n,
               PARALLEL_IN=>p_alu_wb_aluout_1,
               DATA_OUT=>p_alu_wb_aluout_2);

    p_id_mem_memw_2 <= p_mem_x_memop(0);
    p_id_mem_memen_2 <= p_mem_x_memop(1);
    preg_memop_1 : entity work.RegistradorANEM(Load)
      generic map(2)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_id_n,
               parallel_in=>p_alu_x_memop,
               data_out=>p_mem_x_memop);

    MEM_END <= p_alu_wb_aluout_2;
    TO_MEM  <= p_id_mem_alua_2;
    MEM_EN  <= p_id_mem_memen_2;
    MEM_W   <= p_id_mem_memw_2;
    p_mem_wb_memout_2 <= DADOS;

    DADOS <= TO_MEM WHEN (p_id_mem_memen_2='1' AND p_id_mem_memw_2='1') ELSE
             (OTHERS=>'Z');
    
    --PIPELINE MEM/WB
    preg_memout: entity work.RegistradorANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_mem_wb_memout_2,
               data_out=>p_mem_wb_memout_3);

    preg_aluout_1: entity work.RegistradorANEM(Load)
      generic map(data_size)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_mem_n,
               parallel_in=>p_alu_wb_aluout_2,
               data_out=>p_alu_wb_aluout_3);

    PREG_ctl_2  : entity WORK.RegistradorANEM(Load)
      generic MAP(3)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regctl_2,
               data_out=>p_id_wb_regctl_3);
    
    PREG_sela_2  : entity WORK.RegistradorANEM(Load)
      generic MAP(RINDEX_SIZE)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_regsela_2,
               data_out=>p_id_wb_regsela_3);

    preg_imm_2: entity work.RegistradorANEM(Load)
      generic map(8)
      port map(ck=>ck,
               rst=>rst,
               en=>p_stall_alu_n,
               parallel_in=>p_id_wb_limm_2,
               data_out=>p_id_wb_limm_3);
    
    --PC
    --PC: ENTITY WORK.PC(behavior)
    --PORT MAP(TEST=>TEST,
    --         S_IN_PC=>S_OUT_REG,
    --         A_OUT=>A_OUT,
    --         OFFSET=>ANEM_OFFSET,
    --         ENDERECO=>ANEM_ENDE, 
    --         Z=>Z,
    --         PC_CONT=>PC_CONT,
    --         CLK=>CK,
    --         RST=>RST,
    --         S_OUT_PC=>S_OUT,
    --         PC_OUT=>INST_END);
    
    --REGISTRADOR DE INSTRUCAO

    --flush mux
    p_if_x_aneminst_mux <= inst when p_flush = '0' else
                           (others='0');
    
    RINST: ENTITY WORK.RegistradorANEM(Load)
      GENERIC MAP(DATA_SIZE)
      PORT MAP(CK=>CK,
               RST=>RST,
               EN=>p_stall_if_n,
               PARALLEL_IN=>p_if_x_aneminst_mux,
               DATA_OUT=>p_if_id_aneminst_0);


    --forwarding test
    p_regsela_plus: entity work.RegistradorANEM(Load)
      generic map(4)
      port map(ck=>ck,
               rst=>rst,
               en=>'1',
               parallel_in=>p_id_wb_regsela_3,
               data_out=>p_id_wb1_regsela_4
               );

    
    p_f_regbnk_w <= '0' when p_id_wb_regctl_1 = "000" else
                    '1';
    
    --forwarding unit
    pfw: entity work.anem16_fwunit(pipe)
      port map(reg_sela_wb=>p_id_wb_regsela_3,
               reg_sela_mem=>p_id_wb_regsela_2,
               reg_sela_alu=>p_id_wb_regsela_1,
               reg_selb_alu=>p_id_alu_regselb_1,

               regbnk_write=>p_f_regbnk_w,
               mem_enable=>p_id_mem_memen_1,
               aluctl=>p_id_alu_aluctl_1,
               f_alu_alu_a=>p_f_alu_alu_a,
               f_alu_alu_b=>p_f_alu_alu_b,
               f_mem_alu_a=>p_f_mem_alu_a,
               f_mem_alu_b=>p_f_mem_alu_b
               
               );

    p_flush <= p_beq
    --hazard unit
    phaz: entity work.anem16_hazunit(pipe)
      port map(mrst=>rst,
               mclk=>ck,
               beqtrue=>p_beqtrue,
               
               p_stall_if_n=>p_stall_if_n,
               p_stall_id_n=>p_stall_id_n,
               p_stall_alu_n=>p_stall_alu_n,
               p_stall_mem_n=>p_stall_mem_n,

               mem_en_alu=>p_id_mem_memen_1,
               mem_w_alu=>p_id_mem_memw_1,
               reg_sela_alu=>p_id_wb_regsela_1,
               reg_selb_alu=>p_id_alu_regselb_1,

               reg_sela_wb=>p_id_wb_regsela_3,

               reg_sela_id=>p_id_wb_regsela_0,
               reg_selb_id=>p_id_alu_regselb_0,
               mem_en_id=>p_id_mem_memen_0,
               mem_w_id=>p_id_mem_memw_0,
               
               next_instruction=>p_if_id_aneminst_0
               );
               


END TESTE;
