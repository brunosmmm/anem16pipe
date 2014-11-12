---------------------------------------------------------
--                      PLDP
--                     A N E M
--
--                       MAC
--                   Test Bench
--                  Bruno Morais
--              brunosmmm@gmail.com
---------------------------------------------------------
---------------------------------------------------------

--Data ult. mod.	:	30/05/2011
--Changelog:
---------------------------------------------------------
--@30/05/2011	:	Primeira revisao
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY MACTB IS

    GENERIC (REG_SIZE : INTEGER := 16);

END ENTITY;

ARCHITECTURE TB OF MACTB IS

SIGNAL CK : STD_LOGIC := '0';

SIGNAL W : STD_LOGIC := '0';
SIGNAL EN : STD_LOGIC := '0';
SIGNAL DADOS : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'Z');
SIGNAL ENDE : STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0) := (OTHERS=>'0');
SIGNAL INT : STD_LOGIC := '0';
SIGNAL RST : STD_LOGIC := '0';

BEGIN

    MAC : ENTITY WORK.MAC(MultAcc) PORT MAP(W=>W, EN=>EN, DADOS=>DADOS, ENDE=>ENDE, CK=>CK, INT=>INT, RST=>RST);

    TB: PROCESS

    BEGIN
      
        --RESET
        REPORT("RESET");
        
        RST <= '1';
        WAIT FOR 10ns;
        RST <= '0';
        WAIT FOR 10ns;

        --LE REGISTRADOR DE CONFIGURACAO
        REPORT("LENDO CONFIG_MAC");
        
        ENDE <= x"FFD4";
        W <= '0';
        EN <= '1';
        
        WAIT FOR 10ns;
        CK<= NOT CK;
        
        WAIT FOR 10ns;
        CK<= NOT CK;
        
        
        --ESCREVE CONFIG_MAC
        
        REPORT("ESCREVENDO CONFIG_MAC");
        
        DADOS <= "0000100000000000";
        ENDE <= x"FFD4";
        W <= '1';
        EN <= '1';

        
        WAIT FOR 10ns;
        CK <= NOT CK;
        
        WAIT FOR 10ns;
        CK <= NOT CK;
        
        EN <= '0';
        W <= '0';

        --LE SU E SL INICIAIS
        ENDE <= x"FFD5";
        
        WAIT FOR 10ns;
        
        ENDE <= x"FFD6";
        
        WAIT FOR 10ns;
        
        EN <= '0';
        
        --REALIZA MULTIPLICACAO DE TESTE
        
        --ESCREVE OPERANDO 1 EM A
        
        DADOS <= "0000000000000010";
        ENDE <= x"FFD5";
        W <= '1';
        EN <= '1';
      
      WAIT FOR 10ns;
      CK <= NOT CK;
      WAIT FOR 10ns;
      CK <= NOT CK;
      
      DADOS <= (OTHERS=>'Z');
      EN <= '0';
      
      DADOS <= "0000000000000011";
    ENDE <= x"FFD6";
    EN <= '1';
    
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    DADOS <= (OTHERS=>'Z');
    
    W <= '0';
    EN <= '0';
    
    --CLOCKS ATE O FIM
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    WAIT FOR 10ns;
    CK <= NOT CK;
    WAIT FOR 10ns;
    CK <= NOT CK;
    
    --LEITURA DO RESULTADO
    ENDE <= x"FFD5";
    W <= '0';
    EN <= '1';
    
    WAIT FOR 10ns;
    
    EN <= '0';
    
    WAIT FOR 10ns;
    
    ENDE <= x"FFD6";
    W <= '0';
    EN <= '1';
    
    WAIT FOR 10ns;

    END PROCESS;

END ARCHITECTURE;
