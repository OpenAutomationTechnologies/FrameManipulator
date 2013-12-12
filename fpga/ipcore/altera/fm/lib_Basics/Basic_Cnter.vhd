-- ***************************************************************************
-- *                       Basic_Cnter V1.4                                  *
-- ***************************************************************************
-- *                                                                         *
-- * A little mod 2^x counter                                                *
-- *                                                                         *
-- * V1.4                                                                    *
-- *                                                                         *
-- * in :iClear         reset signal                                         *
-- *     iEn            Enable signal                                        *
-- *     iStartValue    Value after Clear                                    *
-- *     iEndValue      Maximal value => Overflow                            *
-- * out:oQ             current number                                       *
-- *     oOv            overflow signal                                      *
-- *                                                                         *
-- *-------------------------------------------------------------------------*
-- *                                                                         *
-- * 27.04.12 V1.0 created Basic_Cnter              by Sebastian Muelhausen  *
-- * 02.05.12 V1.1 Enable added                     by Sebastian Muelhausen  *
-- * 30.05.12 V1.2 Start Value added                by Sebastian Muelhausen  *
-- * 06.08.12 V1.3 End Value added                  by Sebastian Muelhausen  *
-- * 10.12.13 V1.4 Added startvalue in process list by Sebastian Muelhausen  *
-- *                                                                         *
-- ***************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Basic_Cnter is
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
end Basic_Cnter;

architecture two_seg_arch of Basic_Cnter is
    signal r_next: unsigned(gCntWidth-1 downto 0);
    signal r_q:    unsigned(gCntWidth-1 downto 0);
begin

    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                r_q <= unsigned(iStartValue);
            else
                r_q <= r_next;
            end if;
        end if;
    end process;



    process(iClear, iEn, iStartValue, iEndValue,r_q)
    begin
        r_next<=r_q;
        oOv<='0';

        if iClear='1' then
            r_next<=unsigned(iStartValue);

        elsif iEn='1' then
            r_next<=r_q+1;

            if r_q=unsigned(iEndValue) then
                r_next <= (others=>'0');
                oOv<='1';
            end if;

        end if;

    end process;

     oQ <= std_logic_vector(r_q);

end two_seg_arch;