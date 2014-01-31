-- **********************************************************************
-- *                         write_logic V1.2                           *
-- **********************************************************************
-- *                                                                    *
-- * Logic to write Ethernet frames into a DPRam                        *
-- *                                                                    *
-- * gAddrWidth   Address width                                         *
-- * gPrescaler   Prescaler for clock =1=> no Prescaler                 *
-- *                                                                    *
-- * in:  iSync       Syncronization for the Start <=1=synchron reset   *
-- *      iEn         Enable                                            *
-- *      iStartAddr  Start Address after Clear                         *
-- * out: oAddr       Address signal                                    *
-- *      oWrEn       Write enable                                      *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 08.05.12 V1.0 created write_logic  by Sebastian Muelhausen         *
-- * 15.05.12 V1.1 added Prescaler      by Sebastian Muelhausen         *
-- * 30.05.12 V1.2 added Start Address  by Sebastian Muelhausen         *
-- *                                                                    *
-- **********************************************************************


--! Use standard ieee library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric functions
use ieee.numeric_std.all;

--! Use work library
library work;
--! use global library
use work.global.all;


entity write_logic is
    generic(
        gPrescaler:natural:=4;
        gAddrWidth: natural:=11);
    port(
        clk, reset: in std_logic;
        iSync:      in std_logic;
        iEn:        in std_logic;
        iStartAddr: in std_logic_vector(gAddrWidth-1 downto 0);
        oAddr:      out std_logic_vector(gAddrWidth-1 downto 0);
        oWrEn:      out std_logic
    );
end write_logic;

architecture Behave of write_logic is

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

    signal difpre: std_logic_vector(LogDualis(gPrescaler)-1 downto 0):=(others=>'0');
    signal add_en: std_logic;
begin

    Prescale:
    if gPrescaler>1 generate

        difpre_clk : Basic_Cnter
        generic map (gCntWidth => LogDualis(gPrescaler))
        port map (
                clk=>clk, reset=>reset,
                iClear=>iSync,iEn => iEn,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
                oQ => difpre, oOv => open
                );
    end generate;


    add_en <= '1' when difpre=(difpre'range=>'0')and iEn='1' else '0';
    oWrEn  <= '1' when difpre=(difpre'range=>'0')and iEn='1' else '0';

    addr_cnt : Basic_Cnter
    generic map (gCntWidth => gAddrWidth)
    port map (
            clk=>clk, reset=>reset,
            iClear=>iSync,iEn => add_en, iStartValue=>iStartAddr,iEndValue=>(others=>'1'),
            oQ => oAddr, oOv => open
            );


end Behave;