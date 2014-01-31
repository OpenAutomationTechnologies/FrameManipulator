-- ****************************************************************
-- *                       sync_RxFrame                           *
-- ****************************************************************
-- *                                                              *
-- * Synchronizer for the begin of an Ethernet frame              *
-- *                                                              *
-- * in:  iRXDV                                                   *
-- *      iRXD1                                                   *
-- * out: oSync                                                   *
-- *                                                              *
-- *--------------------------------------------------------------*
-- *                                                              *
-- * 27.04.12 V1.0 created sync_RxFrame  by Sebastian Muelhausen  *
-- *                                                              *
-- ****************************************************************

library ieee;
use ieee.std_logic_1164.all;

entity sync_RxFrame is
    port(
        clk, reset: in std_logic;
        iRXDV: in std_logic;
        iRXD1: in std_logic;
        oSync: out std_logic
    );
end sync_RxFrame;

architecture two_seg_arch of sync_RxFrame is
    signal set_q: std_logic_vector(2 downto 0);    --current state of set shift register
    signal set_next: std_logic_vector(2 downto 0); --new state of set shift register
    signal res_q: std_logic_vector(1 downto 0);    --current state of reset shift register
    signal res_next: std_logic_vector(1 downto 0); --new state of reset shift register
    signal syn: std_logic := '0';                         --synchronisation signal
begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            set_q <= (others=>'0');

        elsif rising_edge(clk) then
            set_q <= set_next;
            res_q <= res_next;

            if (set_q="110") then
                syn <= '1';

            elsif (res_q="10") then
                syn <= '0';

            end if;

        end if;
    end process;


    res_next <= iRXD1 & res_q(1);
    set_next <= iRXDV & set_q(2 downto 1);


     oSync <= syn;


end two_seg_arch;