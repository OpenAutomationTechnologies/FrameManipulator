-- ****************************************************************
-- *                       sync_newData                           *
-- ****************************************************************
-- *                                                              *
-- * Synchronizer which sends a sync signal, when new Data arrives*
-- *                                                              *
-- * WIDTH: WIDTH of the input (and output) data                  *
-- *                                                              *
-- * in:  iData                                                   *
-- * out: oData (same Data with one cycle delay)                  *
-- *      oSync                                                   *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 27.04.12 V1.0 created sync_newData  by Sebastian Muelhausen  *
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;

entity sync_newData is
    generic(WIDTH: natural:=8);
    port(
        clk, reset: in std_logic;
        iData: in std_logic_vector(WIDTH-1 downto 0);
        oData: out std_logic_vector(WIDTH-1 downto 0);
        oSync: out std_logic
    );
end sync_newData;

architecture two_seg_arch of sync_newData is
    signal r_q: std_logic_vector(WIDTH-1 downto 0);    --current state of set shift register
    signal r_next: std_logic_vector(WIDTH-1 downto 0); --new state of set shift register

begin

--setting of the Sync signal
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

    r_next <= iData;

    oData <= r_q;
    oSync <= '0' when r_q=r_next else '1';   --output =1, when new Data != old Data

end two_seg_arch;