---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       MAC
--
--                  Bruno Morais
--              brunosmmm@gmail.com
---------------------------------------------------------
---------------------------------------------------------

--Data ult. mod.	:	06/06/2011
--Changelog:
---------------------------------------------------------
--@30/05/2011	:	Primeira revisao

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY MAC IS

    GENERIC(REG_SIZE : INTEGER := 16; --TAMANHO DOS REGISTRADORES
            ACC_SIZE: INTEGER := 32; --TAMANHO DO ACUMULADOR
            MEM_END_SIZE: INTEGER := 16; --TAMANHO DO VETOR DE ENDEREAMENTO DE MEMORIA
            CONFIG_MAC_ADDR : STD_LOGIC_VECTOR := x"FFD4"; --ENDERECO CONFIGURADO PARA O REGISTRADOR CONFIG_MAC
            A_SU_ADDR : STD_LOGIC_VECTOR := x"FFD5"; --ENDERECO CONFIGURADO PARA OS REGISTRADORES A / SU
            B_SL_ADDR : STD_LOGIC_VECTOR := x"FFD6"; --ENDERECO CONFIGURADO PARA OS REGISTRADORES B / SL
            
            --MASCARA DE ACESSO DE ESCRITA PARA O REGISTRADOR CONFIG_MAC:
            --SE O BIT TIVER VALOR 1, O ACESSO AO BIT NO REGISTRADOR  LEITURA/ESCRITA
            --SE O BIT TIVER VALOR 0, O ACESSO AO BIT NO REGISTRADOR E SOMENTE LEITURA
            CONFIG_MAC_ACCESS_MASK : STD_LOGIC_VECTOR := "1010111100000111";
            
            --VALORES PADRAO DO REGISTRADOR DE CONFIGURACAO
            CONFIG_MAC_DEFAULT_VAL : STD_LOGIC_VECTOR := "0101000000000000"
            );
    
    PORT(
        DADOS : INOUT STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
        ENDE: IN STD_LOGIC_VECTOR(MEM_END_SIZE-1 DOWNTO 0);
        W : IN STD_LOGIC;
        EN : IN STD_LOGIC;
        CK : IN STD_LOGIC;
        RST: IN STD_LOGIC;
        
        INT : OUT STD_LOGIC --SINAL DE INTERRUPCAO
        );
    
    
END ENTITY;


ARCHITECTURE MultAcc OF MAC IS

SIGNAL WEN : STD_LOGIC := '0'; --WRITE ENABLE
SIGNAL REN : STD_LOGIC := '0'; --READ ENABLE

SIGNAL CONFIG_MAC_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := CONFIG_MAC_DEFAULT_VAL;
SIGNAL CONFIG_MAC_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := CONFIG_MAC_DEFAULT_VAL;
SIGNAL A_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
SIGNAL B_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

SIGNAL SU_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
SIGNAL SL_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

SIGNAL SU_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL SL_IN : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

SIGNAL DADOS_OUT : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);

--REGISTRADORES SELECIONAVEIS PARA ESCRITA:
--SEL_REG_A_SU : REGISTRADOR A / SU
--SEL_REG_B_SL : REGISTRADOR B / SL
--SEL_REG_CONFIG_MAC : REGISTRADOR CONFIG_MAC
--SEL_REG_NONE: NENHUM REGISTRADOR SELECIONADO

TYPE REG_SEL IS (SEL_REG_A_SU, SEL_REG_B_SL, SEL_REG_CONFIG_MAC, SEL_REG_NONE); 

--REGISTRADOR SELECIONADO ATUALMENTE
SIGNAL MAC_REG_SEL : REG_SEL := SEL_REG_NONE;

--SINAIS DE WRITE ENABLE DOS REGISTRADORES DE ENTRADA INTERNOS
SIGNAL CONFIG_MAC_WEN : STD_LOGIC := '0';
SIGNAL A_WEN : STD_LOGIC := '0';
SIGNAL B_WEN : STD_LOGIC := '0';

--SINAIS DO ACUMULADOR
SIGNAL ACC_OUT : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL ACC_IN : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL OP_ACC : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS=>'0');

SIGNAL ACC_RDY : STD_LOGIC := '0'; --ACUMULACAO PRONTA OU NAO
SIGNAL ACC_OVR : STD_LOGIC := '0'; --OVERFLOW
SIGNAL ACC_COUT : STD_LOGIC := '0'; --CARRY OUT
SIGNAL ACC_ZERO : STD_LOGIC := '0'; --ZERO

SIGNAL ACC_RST : STD_LOGIC := '0'; --RESET DO ACUMULADOR
SIGNAL ACC_MAC_RST : STD_LOGIC := '0'; --SINAL INTERNO DO MAC PARA RESETAR O ACUMULADOR

--SINAIS DO MULTIPLICADOR
SIGNAL MULT_A : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL MULT_B : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL OP_MULT : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL MULT_OUT : STD_LOGIC_VECTOR(ACC_SIZE-1 DOWNTO 0) := (OTHERS=>'0');

SIGNAL MULT_RDY : STD_LOGIC := '0'; --MULTIPLICACAO PRONTA OU NAO


--FUNCAO DE CONVERSAO BOOL -> STD_LOGIC

    FUNCTION BOOL_TO_STDLOGIC(INP : BOOLEAN) return STD_LOGIC is
    BEGIN
        
        IF INP THEN
            RETURN '1';
        ELSE
            RETURN '0';
        END IF;
    
    END FUNCTION BOOL_TO_STDLOGIC;

--ESTADOS DO MAC
--MAC_WAIT : ESTADO INICIAL, CARREGANDO OU LENDO DADOS
--MAC_MULT : DADOS CARREGADOS, MULTIPLICANDO
--MAC_ACC : MULTIPLICACAO PRONTA, ACUMULANDO

TYPE ESTADOS_MAC IS (MAC_WAIT, MAC_MULT, MAC_ACC);

--ESTADO ATUAL DO MAC
SIGNAL EMAC : ESTADOS_MAC := MAC_WAIT;

--ALIASES
ALIAS CONFIG_MAC_MOK   : STD_LOGIC IS CONFIG_MAC_OUT(6); --FLAG MOK -- MULTIPLICACAO OK
ALIAS CONFIG_MAC_INT   : STD_LOGIC IS CONFIG_MAC_OUT(7); --FLAG INT -- HOUVE INTERRUPCAO
ALIAS CONFIG_MAC_IE    : STD_LOGIC IS CONFIG_MAC_OUT(11); --FLAG IE -- INTERRUPT ENABLE
ALIAS CONFIG_MAC_OVR   : STD_LOGIC IS CONFIG_MAC_OUT(5); --FLAG OVR -- OVERFLOW NA ACUMULACAO
ALIAS CONFIG_MAC_COUT  : STD_LOGIC IS CONFIG_MAC_OUT(3); --FLAG COUT -- CARRY OUT NA ACUMULACAO
ALIAS CONFIG_MAC_Z     : STD_LOGIC IS CONFIG_MAC_OUT(4); --FLAG ZERO -- ZERO NA ACUMULACAO
ALIAS CONFIG_MAC_ACR   : STD_LOGIC IS CONFIG_MAC_OUT(10); --ACCUMULATOR RESET -- RESETA ACUMULADOR
ALIAS CONFIG_MAC_OPACC : STD_LOGIC_VECTOR(1 DOWNTO 0) IS CONFIG_MAC_OUT(15 DOWNTO 14); --OP_ACC
ALIAS CONFIG_MAC_OPMULT: STD_LOGIC_VECTOR(1 DOWNTO 0) IS CONFIG_MAC_OUT(13 DOWNTO 12); --OP_MULT

BEGIN

--LOGICA COMBINACIONAL

    --RESET DO ACUMULADOR INICIALMENTE LIGADO AO RESET PRINCIPAL
    ACC_RST <= ACC_MAC_RST OR RST;
    
    --SINAL DE INTERRUPCAO
    INT <= CONFIG_MAC_INT;
    
    --SINAL DE ESCRITA NO CONFIG_MAC (IGNORA ESCRITA EM BITS SOMENTE LEITURA)
    CONFIG_MAC_IN <= (DADOS AND CONFIG_MAC_ACCESS_MASK) OR (CONFIG_MAC_IN AND (NOT CONFIG_MAC_ACCESS_MASK));
    
    WEN <= W AND EN; --WRITE ENABLE
    REN <= (NOT W) AND EN; --READ ENABLE
    
    --SAIDA/ENTRADA
    DADOS <= DADOS_OUT WHEN REN = '1' ELSE --LEITURA
             (OTHERS=>'Z');
    
    
    --MUX / DEMUX
    
    --DECODIFICADOR (DEMUX): INDICA QUAL REGISTRADOR ESTA SELECIONADO
    
    MAC_REG_SEL <= SEL_REG_CONFIG_MAC WHEN ENDE = CONFIG_MAC_ADDR ELSE
                  SEL_REG_A_SU WHEN ENDE = A_SU_ADDR ELSE
                  SEL_REG_B_SL WHEN ENDE = B_SL_ADDR ELSE
                  SEL_REG_NONE;  
    
    --SAIDAS (LEITURA)
    DADOS_OUT <= CONFIG_MAC_OUT  WHEN MAC_REG_SEL = SEL_REG_CONFIG_MAC ELSE
                 SU_OUT WHEN MAC_REG_SEL = SEL_REG_A_SU ELSE
                 SL_OUT WHEN MAC_REG_SEL = SEL_REG_B_SL ELSE
                 (OTHERS=>'0');
                  
    --CONECTA SINAIS DE HABILITACAO DE ESCRITA NOS REGISTRADORES (VHDL = EXCESSO DE SINAIS)  
    
    --CONDICAO PARA ESCRITA NOS REGISTRADORES DE ENTRADA INTERNOS:
    --1. WEN VERDADEIRO: PERIFERICO HABILITADO E EM MODO DE ESCRITA
    --2. ENDERECO CORRETO: O ENDERECO COLOCADO EM ENDE SELECIONA ALGUM REGISTRADOR
    --3. MAC NO ESTADO MAC_WAIT: O MAC NAO ESTA FAZENDO NADA E PODE ACEITAR UMA NOVA OPERACAO
    
    CONFIG_MAC_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_CONFIG_MAC) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
    A_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_A_SU) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
    B_WEN <= WEN AND BOOL_TO_STDLOGIC(MAC_REG_SEL = SEL_REG_B_SL) AND BOOL_TO_STDLOGIC(EMAC = MAC_WAIT);
        
    --REGISTRADORES INTERNOS

    REG_A : ENTITY WORK.RegistradorMAC(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>A_OUT, EN=>A_WEN, PARALLEL_IN=>DADOS, CK=>CK, RST=>RST);
    REG_B : ENTITY WORK.RegistradorMAC(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>B_OUT, EN=>B_WEN, PARALLEL_IN=>DADOS, CK=>CK, RST=>RST);
    
    REG_SU: ENTITY WORK.RegistradorMAC(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>SU_OUT, EN=>'1', PARALLEL_IN=>SU_IN, CK=>CK, RST=>RST);
    REG_SL: ENTITY WORK.RegistradorMAC(Load) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>SL_OUT, EN=>'1', PARALLEL_IN=>SL_IN, CK=>CK, RST=>RST);
      
    --ACUMULADOR
    
    ACC: ENTITY WORK.AcumuladorMAC(ACC) GENERIC MAP(ACC_SIZE) PORT MAP(DATA_OUT=>ACC_OUT, DATA_IN=>ACC_IN, OP_ACC=>OP_ACC, CK=>CK, ACC_RDY=>ACC_RDY, RST=>ACC_RST, C=>ACC_COUT, OVR=>ACC_OVR, Z=>ACC_ZERO);
      
    --CONECTA SINAIS DO ACUMULADOR
    
    SU_IN <= ACC_OUT(ACC_SIZE-1 DOWNTO REG_SIZE);
    SL_IN <= ACC_OUT(REG_SIZE-1 DOWNTO 0);
    
    ACC_IN <= MULT_OUT;
       
    --CONECTA SINAIS DO MULTIPLICADOR
    
    MULT: ENTITY WORK.MultiplicadorMAC(MULT) GENERIC MAP(REG_SIZE) PORT MAP(DATA_OUT=>MULT_OUT, A_IN=>MULT_A, B_IN=>MULT_B, OP_MULT=>OP_MULT, CK=>CK, MULT_RDY=>MULT_RDY);
    
    MULT_A <= A_OUT;
    MULT_B <= B_OUT;
     
    --MAQUINA DE ESTADOS - CONTROLA OPERACAO INTERNA DO MAC
    
    PROCESS(CK, RST)
    
    BEGIN
    
        --RESET ASSNCRONO
        IF RST = '1' THEN
        
            CONFIG_MAC_OUT <= CONFIG_MAC_DEFAULT_VAL;
            EMAC <= MAC_WAIT;
    
        ELSIF RISING_EDGE(CK) THEN
        
            --LIBERA O RESET DO ACUMULADOR
            
            IF ACC_MAC_RST = '1' THEN
                ACC_MAC_RST <= '0';
            END IF;
        
            --REGISTRADOR DE CONFIGURACAO
            
            IF CONFIG_MAC_WEN = '1' THEN
        
                CONFIG_MAC_OUT <= CONFIG_MAC_IN;
            
            END IF;
        
            --MAQUINA DE ESTADOS
    
            CASE EMAC IS
                
                
                WHEN MAC_MULT =>
                
                    IF MULT_RDY = '1' THEN
                    
                        --MULTIPLICACAO TERMINADA, ACUMULA
                        OP_ACC <= CONFIG_MAC_OPACC; --HABILITA ACUMULADOR
                        EMAC <= MAC_ACC;
                        
                        --DESABILITA MULTIPLICADOR
                        OP_MULT <= "00";
                        
                    ELSE
                    
                        --MULTIPLICACAO NAO TERMINOU
                        EMAC <= MAC_MULT;
                    
                    END IF;
                
                WHEN MAC_ACC =>
                
                    IF ACC_RDY = '1' THEN
                    
                        --ACUMULACAO TERMINADA
                        
                        --ESPERA
                        EMAC <= MAC_WAIT;
                        
                        --OPERACOES CONCLUIDAS, VERIFICA SE SERA GERADA INTERRUPCAO OU NAO
                        
                        --FLAG DE OVERFLOW
                        CONFIG_MAC_OVR <= ACC_OVR;
                        
                        --VERIFICA SE HOUVE OVERFLOW
                        
                        IF ACC_OVR = '0' THEN
                        
                            --ATIVA FLAG MOK - MULTIPLICACAO OK NO REGISTRADOR CONFIG_MAC
                       
                            CONFIG_MAC_MOK <= '1';
                            
                        ELSE
                        
                            --HOUVE OVERFLOW, NAO ATIVA MOK
                        
                            CONFIG_MAC_MOK <= '0';
                            
                        END IF;
                        
                        --FLAG DE CARRY OUT
                        CONFIG_MAC_COUT <= ACC_COUT;
                        
                        --FLAG DE ZERO
                        CONFIG_MAC_Z <= ACC_ZERO;
                        
                        --INTERRUPCOES: O TERMINO DE UMA MULTIPLICACAO SEMPRE GERA UMA INTERRUPCAO
                        --              O USUARIO DEVE LER O REGISTRADOR DE CONFIGURACAO PARA SABER
                        --              O QUE CAUSOU A INTERRUPCAO, ATRAVES DOS FLAGS DISPONIVEIS
                        
                        IF CONFIG_MAC_IE = '1' THEN
                        
                            --INTERRUPCAO HABILITADA, GERA INTERRUPCAO
                            CONFIG_MAC_INT <= '1';
                            
                        END IF;
                        
                        --DESABILITA ACUMULADOR
                        OP_ACC <= "00";
                    
                    ELSE
                    
                    --ACUMULACAO NAO TERMINOU
                    
                        EMAC <= MAC_ACC;
                        
                    END IF;
                    
                
                WHEN MAC_WAIT =>
                  
                  
                    --VERIFICA SE O BIT DE RESET DO ACUMULADOR FOI ESCRITO
                    --NAO DEPENDE DE ENABLE POR QUE SO PODE SER VERIFICADO NO PROXIMO CLOCK
                    IF CONFIG_MAC_ACR = '1' THEN
                  
                      --RESETA ACUMULADOR
                      ACC_MAC_RST <= '1';
                      
                      CONFIG_MAC_ACR <= '0'; --ZERA O BIT (PADRAO)
                  
                    END IF;
                
                
                    IF EN='1' AND MAC_REG_SEL /= SEL_REG_NONE THEN
                    
                    --OS PERIFERICOS ESTAO HABILITADOS E UM DOS ENDERECOS MAPEADOS PARA O MAC ESTA SELECIONADO
                    
                        IF W='1' THEN
                        
                            --MODO DE ESCRITA: O ANEM ESTA ESCREVENDO NO MAC
                            
                            --SE O ANEM ESCREVEU NO REGISTRADOR B, ENTAO INICIA-SE A MULTIPLICACAO
                            
                            IF MAC_REG_SEL = SEL_REG_B_SL THEN
                            
                                --HABILITA MULTIPLICADOR
                                OP_MULT <= CONFIG_MAC_OPMULT;
                                
                                EMAC <= MAC_MULT;
                                
                            ELSIF MAC_REG_SEL = SEL_REG_CONFIG_MAC THEN
                            
                                --O ANEM ESCREVEU NO REGISTRADOR DE CONFIGURACAO;

                            END IF;
                            
                
                        ELSE 
                        
                            --MODO DE LEITURA: O ANEM ESTA LENDO DO MAC
                            
                            IF MAC_REG_SEL = SEL_REG_CONFIG_MAC THEN
                            
                                --SE OCORREU LEITURA DO REGISTRADOR CONFIG_MAC, LIMPA FLAGS DE INTERRUPCAO, ETC.
                                
                                CONFIG_MAC_INT <= '0';
                                CONFIG_MAC_MOK <= '0';
                                CONFIG_MAC_OVR <= '0';
                                CONFIG_MAC_COUT <= '0';
                                CONFIG_MAC_Z <= '0';
                                
                            END IF;
                            
                        
                        END IF;
                        
                    ELSE
                    
                        EMAC <= MAC_WAIT; --NAO FAZ NADA, SO PARA MELHOR VISUALIZACAO DO FUNCIONAMENTO
                    
                    END IF;
                
            END CASE;
            
         END IF;
    
    END PROCESS;
    
END ARCHITECTURE;
