-- ****************************************************************
-- *                          adder_2121                          *
-- ****************************************************************
-- *                                                              *
-- * Logic to add two xBit data Inputs to one (2x)Bit in the order*
-- * 2121...                                                      *
-- *                                                              *
-- * in:  iD1[WIDTH_IN-1..0]    for Data in 1                     *
-- *      iD2[WIDTH_IN-1..0]    for Data in 2                     *
-- *      iEn                   for enable                        *
-- * out: oQ[(WIDTH_IN*2)-1..0] for Data out                      *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 27.04.12 V1.0 created adder_2121  by Sebastian Muelhausen    *
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;

entity adder_2121 is
    generic(WIDTH_IN: natural := 4);
    port(
        clk, reset: in std_logic;
        iD1: in std_logic_vector(WIDTH_IN-1 downto 0);
        iD2: in std_logic_vector(WIDTH_IN-1 downto 0);
        iEn: in std_logic;
        oQ: out std_logic_vector((WIDTH_IN*2)-1 downto 0)
    );
end adder_2121;

architecture two_seg_arch of adder_2121 is
    signal r_q: std_logic_vector((WIDTH_IN*2)-1 downto 0);         --current value
    signal r_next: std_logic_vector((WIDTH_IN*2)-1 downto 0);      --next value
    signal r_calculated: std_logic_vector((WIDTH_IN*2)-1 downto 0);--calculated new value
begin

    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                r_q <= (others=>'0');
            else
                r_q <= r_next;
            end if;
        end if;
    end process;

    process(iD1,iD2)
    begin

        for i in 0 to (WIDTH_IN)-1 loop
              r_calculated(i*2)<=iD1(i);
              r_calculated(i*2+1)<=iD2(i);
        end loop;
    end process;


    r_next <= r_calculated when iEn='1' else r_q;

    oQ <= r_q;
end two_seg_arch;