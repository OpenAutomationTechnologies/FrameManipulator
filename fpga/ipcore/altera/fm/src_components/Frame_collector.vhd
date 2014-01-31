-- ****************************************************************
-- *                      Frame_collector                         *
-- ****************************************************************
-- *                                                              *
-- * A Component to collect the data of Ethernet Frames and stores*
-- * it at oFrameData                                             *
-- *                                                              *
-- *   Generics:                                                  *
-- *   gFrom: Number of the first Byte of the Datastream          *
-- *   gTo:   Number of the last Byte                             *
-- *                                                              *
-- * in:  iData          input of the data stream                 *
-- *      iSync          sync. signal for the Start of the stream *
-- * out: oFrameData     Collected Bytes   Width=no. of Bytes x 8 *
-- *      oFrameFinished Signal after checking the last Byte      *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 22.05.12 V1.0 created Frame_collector by Sebastian Muelhausen*
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--! use global library
use work.global.all;

entity Frame_collector is
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
end Frame_collector;

architecture two_seg_arch of Frame_collector is

    --Counter
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

    --Logic to select the bytes, which should be compared
    component From_To_Cnt_Filter
        generic(
            gFrom:    natural:=13;
            gTo:      natural:=16;
            gWidthIn: natural:=5;
            gWidthOut:natural:=2
            );
        port(
            iCnt:  in std_logic_vector(gWidthIn-1 downto 0);
            oCnt: out std_logic_vector(gWidthOut-1 downto 0);
            oEn : out std_logic;
            oEnd: out   std_logic
        );
    end component;

    constant cWidth_ByteCnt:natural :=LogDualis(gTo-gFrom+1)+1;

    signal div4:    std_logic;                                      --Prescaler
    signal cnt:     std_logic_vector(LogDualis(gTo+2)-1 downto 0);      --Number of Current Byte
    signal cntout:  std_logic_vector(cWidth_ByteCnt-1 downto 0);    --Number of Current Byte - gFrom

    signal filter_end:  std_logic;                                  --Reached the last Byte (gTo)
    signal cnt_stop:    std_logic;                                  --Clear Signal after filter_end and iSync
    signal MemEn:       std_logic;                                  --Enable to store the data

    signal reg_q:   std_logic_vector((gTo-gFrom+1)*cByteLength-1 downto 0);   --Register for output data
    signal reg_next:std_logic_vector((gTo-gFrom+1)*cByteLength-1 downto 0);   --Register for output data
begin


    --Counting current Byte------------------------------------------------------------------------------------
    cnt_4 : Basic_Cnter         --Prescaler
    generic map (gCntWidth => 2)
    port map (
            clk=>clk, reset=>reset,
            iClear=>cnt_stop,iEn => '1', iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ => open, oOv => div4
            );

    cnt_5bit : Basic_Cnter  --Counter, which counts the Bytes
    generic map (gCntWidth => LogDualis(gTo+2))
    port map (
            clk=>clk, reset=>reset,
            iClear=>iSync,iEn => div4, iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ => cnt, oOv => open
            );


    --Selecting the important Bytes----------------------------------------------------------------------------
    cnt_f_t : From_To_Cnt_Filter    --Logic to select the wanted Bytes
    generic map (gFrom => gFrom, gTo => gTo, gWidthIn => LogDualis(gTo+2), gWidthOUT => cWidth_ByteCnt)
    port map (
            iCnt => cnt,
            oCnt => cntout, oEn => MemEn, oEnd => filter_end
            );


    cnt_stop <= filter_end or iSync;--reset at every new Frame and stop after reaching the last Byte


    --Regiser to Save the new Data-----------------------------------------------------------------------------
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                reg_q <= (others=>'0');
            else
                reg_q <=reg_next;
            end if;
        end if;
    end process;

    process(iData, reg_q, cntout,MemEn,filter_end)
    begin

        reg_next<=reg_q;

        if (MemEn='0' and filter_end='0') then --deleting the last Ethertype
            reg_next<=(others=>'0');

        elsif (MemEn='1' and filter_end='0') then --TODO alias
            reg_next((gTo-gFrom-to_integer(unsigned(cntout))+1)*cByteLength-1 downto (gTo-gFrom-to_integer(unsigned(cntout)))*cByteLength)<=iData(cByteLength-1 downto 0);
--  e.g.    reg_next(    (10    -                      3    +1)*cByteLength-1 downto (    10    -                       3   )*cByteLength)<=iData(7 downto 0);
--  =       reg_next(8*8-1 downto 7*8) =reg_next(63 downto 56)<=iData(7 downto 0);

        end if;

    end process;

    --Output
    oFrameData<=reg_q;
    oCollectorFinished <= filter_end;

end two_seg_arch;