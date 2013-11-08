-- **********************************************************************
-- *                 shift_right_register                               *
-- **********************************************************************
-- *                                                                    *
-- * A little 4Bit shift right register                                 *
-- * in:  iD       for Data in                                          *
-- * out: oQ[3..0] for 4bit Data out                                    *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 27.04.12 V1.0 created shift_right_register  by Sebastian Muelhausen*
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;

entity shift_right_register is
    generic(
        gWidth: natural:=8
        );
    port(
        clk, reset: in std_logic;
        iD: in std_logic;
        oQ: out std_logic_vector(gWidth-1 downto 0)
    );
end shift_right_register;

architecture two_seg_arch of shift_right_register is
    signal r_next: std_logic_vector(gWidth-1 downto 0);
    signal r_q: std_logic_vector(gWidth-1 downto 0);
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

    r_next <= iD & r_q(gWidth-1 downto 1);

    oQ <= r_q;
end two_seg_arch;