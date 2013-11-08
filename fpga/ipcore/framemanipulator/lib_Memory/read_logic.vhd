-- **********************************************************************
-- *                          read_logic V1.3                           *
-- **********************************************************************
-- *                                                                    *
-- * A small read logic for Memories. Reads new data every              *
-- *                                                                    *
-- * gAddrWidth   Address width                                         *
-- * gPrescaler   Prescaler for clock =1=> no Prescaler                 *
-- *                                                                    *
-- * in:  iSync       Syncronization for the Start <=1=synchron reset   *
-- *      iEn         Enable                                            *
-- *      iStartAddr  Start Address after Clear                         *
-- * out: oRdEn       Read Enable                                       *
-- *      oAddr       Address output                                    *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 08.05.12 V1.0 created read_logic   by Sebastian Muelhausen         *
-- * 15.05.12 V1.1 added Prescaler      by Sebastian Muelhausen         *
-- * 30.05.12 V1.2 added Start Address  by Sebastian Muelhausen         *
-- * 11.06.12 V1.3 added Read Enable    by Sebastian Muelhausen         *
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity read_logic is
    generic(
        gPrescaler:natural:=4;
        gAddrWidth: natural:=11);
    port(
        clk, reset: in std_logic;
        iEn:        in std_logic;
        iSync:      in std_logic;
        iStartAddr: in std_logic_vector(gAddrWidth-1 downto 0);
        oRdEn:      out std_logic;
        oAddr:      out  std_logic_vector(gAddrWidth-1 downto 0)
     );
end read_logic;

architecture Behave of read_logic is

    function log2c(n:natural) return natural is
        variable m, p: natural;
    begin
        m:=0;
        p:=1;
        while p<n loop
            m:=m+1;
            p:=p*2;
        end loop;
        return m;
    end log2c;

    --counter for prescaler
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
          clk, reset:   in std_logic;
          iClear:       in std_logic;
          iEn   :       in std_logic;
          iStartValue:  in std_logic_vector(gCntWidth-1 downto 0);
          iEndValue:    in std_logic_vector(gCntWidth-1 downto 0);
          oQ:           out std_logic_vector(gCntWidth-1 downto 0);
          oOv:          out std_logic
        );
    end component;

    signal cnt: std_logic_vector(log2c(gPrescaler)-1 downto 0):=(others=>'0');
    signal difpre:std_logic;

    signal Addr:        std_logic_vector(oAddr'range):=(others=>'0');
    signal Addr_next:   std_logic_vector(oAddr'range);

begin

    process(clk)
    begin
        if clk'event and clk='1' then
            Addr_next<=Addr;
        end if;
    end process;

    Prescale:
    if gPrescaler>1 generate

        difpre_clk : Basic_Cnter
        generic map (gCntWidth => log2c(gPrescaler))
        port map (
                clk=>clk, reset=>reset,
                iClear=>iSync,iEn => iEn, iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
                oQ => cnt, oOv => open
                );
    end generate;

    difpre<='1' when cnt=(cnt'range=>'0') and iEn='1' else '0';

    buffer_clk : Basic_Cnter
    generic map (gCntWidth => gAddrWidth)
    port map (
            clk=>clk, reset=>reset,
            iClear=>iSync,iEn => difpre, iStartValue=>iStartAddr,iEndValue=>(others=>'1'),
            oQ => Addr, oOv => open
            );

    oAddr<=Addr;
    oRdEn<='1' when Addr/=Addr_next else '0';   --edge detection

end Behave;