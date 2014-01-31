-- ****************************************************************
-- *                       SoC_Cnter V1.2                         *
-- ****************************************************************
-- *                                                              *
-- * A Counter for Ethernet POWERLINK Cycles with recoginizing the*
-- * SoC Frames                                                   *
-- *                                                              *
-- *   Generics:                                                  *
-- *   gCnterWidth: Width of output dataline of the counter       *
-- *                                                              *
-- * in:  iTestSync   sync. Reset Signal => oSocCnt=>0            *
-- *      iFrameSync  sync. signal for the Start of the Stream    *
-- *      iEn         Enable signal                               *
-- *      iData       Framedata (Size=1Byte)                      *
-- * out: oSocCnt     Output Cyclenumber                          *
-- *      oFrameIsSoc =1 when Frame is SoC                        *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 22.05.12 V1.0 created SoC_Cnter    by Sebastian Muelhausen   *
-- * 29.05.12 V1.1 added iEn            by Sebastian Muelhausen   *
-- * 01.06.12 V1.2 added oFrameIsSoc    by Sebastian Muelhausen   *
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.global.all;

entity SoC_Cnter is
    generic(gCnterWidth:natural:=8);
    port(
        clk, reset:     in std_logic;
        iTestSync:      in std_logic;                                   --sync for counter reset
        iFrameSync:     in std_logic;                                   --sync for new incoming frame
        iEn:            in std_logic;                                   --counter enable
        iData:          in std_logic_vector(cByteLength-1 downto 0);    --frame-data
        oFrameIsSoc:    out std_logic;                                  --current frame is a SoC
        oSocCnt  :      out std_logic_vector(cByteLength-1 downto 0)    --number of received SoCs
    );
end SoC_Cnter;



architecture two_seg_arch of SoC_Cnter is

    --counter for the received SoCs => current POWERLINK-cycle number
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

    --Collector for the Messagetype value
    component Frame_collector
        generic(
            gFrom:natural:=13;
            gTo : natural:=22
        );
        port(
            clk, reset:         in std_logic;
            iData:              in std_logic_vector(cByteLength-1 downto 0);
            iSync:              in std_logic;
            oFrameData :        out std_logic_vector((gTo-gFrom+1)*cByteLength-1 downto 0);
            oCollectorFinished: out std_logic
        );
    end component;

    signal cntEn:               std_logic;                      --Counter Enable
    signal CollectorFinished:   std_logic;                      --Messagetype has received
    signal MessageType:         std_logic_vector(cByteLength-1 downto 0);   --value of Messagetype

    --Edge Detection
    signal Next_FrameFit:       std_logic;  --Messagetype fit / frame is Soc
    signal Reg_FrameFit:        std_logic;
begin

    --register storage
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                Reg_FrameFit <= '0';
            else
                Reg_FrameFit <=Next_FrameFit;
            end if;
        end if;
    end process;



    --Collector for POWERLINK SoC
    MessageType_Collector : Frame_collector
    generic map(gFrom=>15,gTo=>15)     --POWERLINK MessageType=Byte 15
    port map(
            clk=>clk,reset=>reset,
            iData=>iData,iSync=>iFrameSync,
            oFrameData=>MessageType,oCollectorFinished=>CollectorFinished);

    --Frame is SoC, when Messagetype=SoC and data is valid
    Next_FrameFit<=CollectorFinished when MessageType=X"01" else '0';

    --Edge Detection for Counter
    cntEn<='1' when iEn='1' and Next_FrameFit='1' and Reg_FrameFit='0' else '0';


    --Cycle Counter
    Cnter:Basic_Cnter
    generic map(gCntWidth=>gCnterWidth)
    port map(
            clk=>clk, reset=>reset,
            iClear=>iTestSync,iEn=>cntEn,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ=>oSocCnt,oOv=>open);

    --current frame is Soc output
    oFrameIsSoc<=Reg_FrameFit;

end two_seg_arch;