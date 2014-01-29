-- **********************************************************************
-- *                      From_To_Cnt_Filter                            *
-- **********************************************************************
-- *                                                                    *
-- * A filter for a counter                                             *
-- *                                                                    *
-- *      gFrom   lower limit                                           *
-- *      gTo     upper limit                                           *
-- *                                                                    *
-- * in:  iCnt    input data for the filter                             *
-- * out: oCnt    output data                                           *
-- *      oEnd    input Data beyond the limits                          *
-- *      oEn     input data is between the limits                      *
-- *                                                                    *
-- * e.g.: gFrom=12 gTo =15                                             *
-- *      iCnt || oCnt | oEn | oEnd                                     *
-- *     --------------------------                                     *
-- *       10  ||   0  |  0  |  0                                       *
-- *       11  ||   0  |  0  |  0                                       *
-- *       12  ||   0  |  1  |  0                                       *
-- *       13  ||   1  |  1  |  0                                       *
-- *       14  ||   2  |  1  |  0                                       *
-- *       15  ||   3  |  1  |  0                                       *
-- *       16  ||   0  |  0  |  1                                       *
-- *       17  ||   0  |  0  |  1                                       *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 02.05.12 V1.0 From_To_Cnt_Filter       by Sebastian Muelhausen     *
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity From_To_Cnt_Filter is
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
end From_To_Cnt_Filter;

architecture two_seg_arch of From_To_Cnt_Filter is


    signal cnt:     natural;
    signal cntout:  natural;
    signal En:      std_logic;
    signal Endo:    std_logic;
begin


    cnt <=to_integer(unsigned(iCnt));

    Endo <= '1' when cnt > gTo   else '0';
    En  <= '1' when (cnt > (gFrom-1))and (Endo = '0')  else '0';

    cntout <= cnt-gFrom when En='1' else 0;

    oCnt <= std_logic_vector(to_unsigned(cntout,gWidthOut));
    oEnd <= Endo;
    oEn  <= En;

end two_seg_arch;