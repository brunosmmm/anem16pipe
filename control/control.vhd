-----------------------------------------------------
--      UNIVERSIDADE FEDERAL DE PERNAMBUCO         --
--     DEPARTAMENTO DE ELETRNICA E SISTEMAS        --
--                                                 --
-- Aluno: Pedro Vitor Macedo Vieira / Bruno Morais --
-- Disciplina: PLDP                                --
-- Projeto: Unidade de Controle do Anem 1 ciclo    --
-----------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY UNIDADE_DE_CONTROLE IS
  PORT(CK           : IN STD_LOGIC;
       OPCODE       : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
       RST          : IN STD_LOGIC;
       CONTROL_REG  : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
       CONTROL_ULA  : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
       CONTROL_PC   : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
       W_DADOS      : OUT STD_LOGIC;
       EN_DADOS     : OUT STD_LOGIC;
       RI_EN        : BUFFER STD_LOGIC;
       RU_EN        : OUT STD_LOGIC;
       will_wb      : out STD_LOGIC);
END UNIDADE_DE_CONTROLE;

ARCHITECTURE TESTE OF UNIDADE_DE_CONTROLE IS

--ESTADOS DO CONTROLE MULTI-CICLO
TYPE CONTROLE_ESTADOS IS (ECONTROL_FETCH, ECONTROL_DECODE, ECONTROL_ULA, ECONTROL_CAL_END, ECONTROL_BEQ);

--MAQUINA DE ESTADOS
SIGNAL ECONTROL : CONTROLE_ESTADOS := ECONTROL_FETCH;

BEGIN 
  PROCESS(CK, RST)
    BEGIN
      
        IF RST = '1' THEN
      
        --RESET
        ECONTROL <= ECONTROL_FETCH;
		  
		  RI_EN <= '0';
        will_wb <= '0';
        
        ELSIF RISING_EDGE(CK) THEN
        
            CASE ECONTROL IS
            
                WHEN ECONTROL_FETCH =>
                
                    --DESABILITA REGISTRADOR DA ULA
                    RU_EN <= '0';
                    
                    --NAO OPERA NENHUM BLOCO DO ANEM
                    CONTROL_ULA <= "000";
                    CONTROL_REG <= "000";
                    CONTROL_PC <= "000";
                    W_DADOS <= '0';
                    EN_DADOS <= '0';
                
                    --HABILITA O REGISTRADOR DE INSTRUCAO PARA SALVAR A INSTRUCAO ATUAL
                
                    IF RI_EN = '0' THEN
                        RI_EN <= '1';
                    
                        --PERMANECE EM CONTROL_FETCH
                        ECONTROL <= ECONTROL_FETCH;
                        
                    ELSE
                        
                        --O REGISTRADOR JA ESTAVA HABILITADO;
                        --A INSTRUCAO FOI SALVA
                    
                        RI_EN <= '0'; --DESABILITA
                        
                        --INCREMENTA PC
                        CONTROL_PC <= "100";
                        
                        --PASSA AO ESTADO CONTROL_DECODE
                        ECONTROL <= ECONTROL_DECODE;
                        
                    END IF;
                
                
                WHEN ECONTROL_DECODE =>
                
                    --PC NAO REALIZA OPERACAO
                    CONTROL_PC <= "000";
                
                    CASE OPCODE IS
                        WHEN "0000" => -- OPERAO TIPO R
                            
                            --CONTROLA ULA - OPERACAO R
                            CONTROL_ULA <= "001";
                            
                            --HABILITA REGISTRADOR DA ULA
                            RU_EN <= '1';
                            
                            --NO PROXIMO CLOCK, O RESULTADO ENTRA NO REGISTRADOR DA ULA
                            ECONTROL <= ECONTROL_ULA;
                            
                        WHEN "0001" => -- OPERAO TIPO S
                            
                            --ULA: OPERACAO S
                           CONTROL_ULA <= "010";
                            
                            RU_EN <= '1';
                            
                            ECONTROL <= ECONTROL_ULA;

                        WHEN "1000" => -- OPERAO TIPO J
                            
                            CONTROL_PC  <= "101"; -- PC RECEBE PC(15 DOWNTO 12)|ENDEREO
                            
                            --O SALTO E IMEDIATO NO PROXIMO CLOCK, JA RETORNA PARA FETCH
                            ECONTROL <= ECONTROL_FETCH;

                        WHEN "0110" => -- OPERAO TIPO BEQ
                            
                            CONTROL_ULA <= "011"; -- ULA REALIZA BEQ
                            
                            RU_EN <= '1';
                            
                            ECONTROL <= ECONTROL_BEQ;

                        WHEN "0111" => -- OPERAO TIPO JR
                            
                            CONTROL_PC  <= "111"; -- PC RECEBE A_OUT
                            
                            --O SALTO TAMBEM E IMEDIATO NO PROXIMO CLOCK, JA RETORNA PARA FETCH
                            ECONTROL <= ECONTROL_FETCH;

                        WHEN "0100" => -- OPERAO TIPO SW

                            CONTROL_ULA <= "100"; -- ULA SOMA OFFSET+(CONTEDO DE REGISTRADOR)
                            
                            RU_EN <= '1';
                            
                            --CALCULA ENDERECO
                            ECONTROL <= ECONTROL_CAL_END;

                        WHEN "0101" => -- OPERAO TIPO LW

                            CONTROL_ULA <= "100"; -- ULA SOMA OFFSET+(CONTEDO DE REGISTRADOR)
                            
                            RU_EN <= '1';
                            
                            ECONTROL <= ECONTROL_CAL_END;
                            
                        WHEN "1100" => -- OPERAO TIPO LIU
                            
                            CONTROL_REG <= "010"; -- REG_FILE RECEBE BYTE SUPERIOR
                            
                            --CARREGAMENTO IMEDIATO
                            ECONTROL <= ECONTROL_FETCH;

                        WHEN "1101" => -- OPERAO TIPO LIL
                            
                            CONTROL_REG <= "011"; -- REG_FILE RECEBE BYTE INFERIOR
                            
                            --CARREGAMENTO IMEDIATO
                            ECONTROL <= ECONTROL_FETCH;
                        
                        WHEN OTHERS => -- OUTROS: EQUIVALENTE A NOP
                            
                            CONTROL_REG <= "000"; -- NAO REALIZA OP
                            CONTROL_ULA <= "000"; -- NAO REALIZA OP
                            CONTROL_PC  <= "000"; -- NAO REALIZA OP
                            W_DADOS <= '0'; -- NAO REALIZA OP
                            EN_DADOS <= '0'; -- NAO REALIZA OP
                            
                            ECONTROL <= ECONTROL_FETCH;
                            
                    END CASE;
                
                WHEN ECONTROL_ULA =>
                
                    --ULA REALIZANDO OPERACAO R
                    
                    --AQUI O REGISTRADOR DA ULA JA FOI CARREGADO, PORTANTO E DESABILITADO
                    RU_EN <= '0';
                    
                    --CARREGA SAIDA DA ULA NO REGISTRADOR A
                    CONTROL_REG <= "001";
                    
                    --TERMINA NO PROXIMO CLOCK, JA RETORNA PARA CONTROL_FETCH
                    ECONTROL <= ECONTROL_FETCH;
                    
                WHEN ECONTROL_BEQ =>
                
                    RU_EN <= '0';
                    
                    CONTROL_PC  <= "111"; -- PC RECEBE PC+OFFSET SE Z=1 (LOGICA INTERNA NO PC)
                    
                    --SALTO IMEDIATO
                    ECONTROL <= ECONTROL_FETCH;
                    
                
                WHEN ECONTROL_CAL_END =>
                
                    RU_EN <= '0';
                    
                    --HABILITA MEMORIA PARA ESCRITA
                    
                    EN_DADOS <= '1';
                    
                    IF OPCODE = "0100" THEN --SW
                
                        W_DADOS <= '1';
                        
                        --A ESCRITA E IMEDIATA NO PROXIMO CLOCK, RETORNA PARA FETCH
                        ECONTROL <= ECONTROL_FETCH;
                    
                    ELSE
                    
                        W_DADOS <= '0'; --LW
                        
                        --CARREGA NO BANCO DE REGISTRADORES
                        CONTROL_REG <= "100";
                        
                        --O CARREGAMENTO E IMEDIATO NO PROXIMO CLOCK, RETORNA PARA FETCH
                        ECONTROL <= ECONTROL_FETCH;
                    
                    END IF;
                
                
                WHEN OTHERS => NULL;
                
            END CASE;

            
        END IF;

  END PROCESS;
END TESTE;
