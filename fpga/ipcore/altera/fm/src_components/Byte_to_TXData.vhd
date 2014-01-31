-- ****************************************************************
-- *                       Byte_to_TXData                         *
-- ****************************************************************
-- *                                                              *
-- * Convertes an 1Byte Stream to the Ethernet TXData             *
-- *                                                              *
-- * in:  iData[7..0] 1Byte input Data                            *
-- * out: oTxD[1..0]  Output Data                                 *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 27.04.12 V1.0 created Byte_to_TXData  by Sebastian Muelhausen*
-- *                                                              *
-- ****************************************************************

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

entity Byte_to_TXData is
    port(
        clk, reset: in std_logic;
        iData: in std_logic_vector(cByteLength-1 downto 0);
        oTXD:  out std_logic_vector(1 downto 0)
    );
end Byte_to_TXData;

architecture two_seg_arch of Byte_to_TXData is

    --Counter, which controlls the DMux
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

    --Demultiplexer for selecting
    component Mux2D
    generic(gWordsWidth: natural:=8;
            gWordsNo:   natural:=8;
            gWidthSel:  natural:=3);
    port(
        iData:  in std_logic_vector(gWordsWidth*gWordsNo-1 downto 0);
        iSel:   in std_logic_vector(gWidthSel-1 downto 0);
        oWord:  out std_logic_vector(gWordsWidth-1 downto 0)
        );
    end component;


    component sync_newData
        generic(WIDTH: natural:=8);
        port(
            clk, reset: in std_logic;
            iData: in std_logic_vector(WIDTH-1 downto 0);
            oData: out std_logic_vector(WIDTH-1 downto 0);
            oSync: out std_logic
        );
    end component;

    signal sync:    std_logic;                          --Synchronise Reset
    signal cnt:     std_logic_vector(1 downto 0);
    signal data:    std_logic_vector(cByteLength-1 downto 0);
    signal TXD_Reg: std_logic_vector(1 downto 0);
begin

    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                oTXD <= (others => '0');
            else
                oTXD<=TXD_Reg;
            end if;
        end if;
    end process;

    syncronizer : sync_newData
    generic map (WIDTH => cByteLength)
    port map (clk=>clk, reset=>reset, iData => iData, oData => data, oSync => sync);

    cnt_2bit : Basic_Cnter      --Counter, which controlls the DMux
    generic map (gCntWidth => 2)
    port map (
            clk=>clk, reset=>reset,
            iClear=>sync,iEn => '1', iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ => cnt, oOv => open);


    DMux8to2:Mux2D
    generic map(gWordsWidth=>2,gWordsNo=>4,gWidthSel=>2)
    port map(iData=>data,iSel=>cnt,
            oWord=>TXD_Reg);



end two_seg_arch;