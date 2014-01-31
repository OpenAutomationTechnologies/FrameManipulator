-- ****************************************************************
-- *                       RXData_to_Byte                         *
-- ****************************************************************
-- *                                                              *
-- * Converter for Ethernet Rx-Data from a PHY to 1Byte           *
-- *                                                              *
-- * in:  iRXDV       Rx-Data valid                               *
-- *      iRXD[1..0]  Rx-Data                                     *
-- * out: oData[7..0] Output Data                                 *
-- *      oEn         Enable for other Components                 *
-- *      oSync       Reset for every Frame                       *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 27.04.12 V1.0 created RXData_to_Byte  by Sebastian Muelhausen*
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;

library work;
--! use global library
use work.global.all;


entity RXData_to_Byte is
    port(
        clk, reset: in std_logic;
            iRXDV: in std_logic;
            iRXD:  in std_logic_vector(1 downto 0);
            oData: out std_logic_vector(cByteLength-1 downto 0);
            oEn:   out std_logic;
            oSync: out std_logic
    );
end RXData_to_Byte;

architecture two_seg_arch of RXData_to_Byte is
    --adder to combine the Data from RxD 0 and 1
    component adder_2121
          generic(WIDTH_IN: natural := 4);
          port(
            clk, reset: in std_logic;
            iD1: in std_logic_vector(WIDTH_IN-1 downto 0);
            iD2: in std_logic_vector(WIDTH_IN-1 downto 0);
            iEn: in std_logic;
            oQ: out std_logic_vector((WIDTH_IN*2)-1 downto 0)
        );
    end component;
    --counter to enable the data every 4th clock (Data is ready in the Shift register)
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
    --two 4Bit shift register to sum up the data
    component shift_right_register
        generic(gWidth: natural:=8);
        port(
            clk, reset: in std_logic;
            iD: in std_logic;
            oQ: out std_logic_vector(gWidth-1 downto 0)
        );
    end component;
    --Synchronizer for a reset every frame
    component sync_RxFrame
        port(
            clk, reset: in std_logic;
            iRXDV: in std_logic;
            iRXD1: in std_logic;
            oSync: out std_logic
        );
    end component;

    signal data1: std_logic_vector(3 downto 0);     --data from shift register 1
    signal data2: std_logic_vector(3 downto 0);     --data from shift register 2
    signal div4_clk: std_logic;                     --enable Signal every 4th clock
    signal sync: std_logic;                         --Synchronise Reset
begin

    shift1_4bit : shift_right_register  --first shift register for RxD0
    generic map (gWidth => 4)
    port map (clk=>clk, reset=>reset, iD => iRXD(0), oQ => data1);

    shift2_4bit : shift_right_register  --second shift register for RxD1
    generic map (gWidth => 4)
    port map (clk=>clk, reset=>reset, iD => iRXD(1), oQ => data2);

    synchronizer : sync_RxFrame         --Synchronizer for the counter
    port map (clk=>clk, reset=>reset, iRXDV => iRXDV, iRXD1 => iRXD(1), oSync => sync);

    cnt_2bit : Basic_Cnter      --Counter for an enable every 4th clock(Data is ready in the Shift register)
    generic map (gCntWidth => 2)
    port map (
            clk=>clk, reset=>reset,
            iClear=>sync,iEn =>'1',iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ => open, oOv => div4_clk);

    adder : adder_2121                  --Adder, which generates the Byte from the two shift registers after every enable
    generic map (WIDTH_IN => 4)
    port map (clk=>clk, reset=>reset, iD1 => data1, iD2 => data2, iEn => div4_clk, oQ => oData);

    oSync <= sync;
    oEn <= div4_clk;

end two_seg_arch;