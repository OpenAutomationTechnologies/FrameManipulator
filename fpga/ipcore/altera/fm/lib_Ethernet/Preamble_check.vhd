-- **********************************************************************
-- *                          Preamble_check                            *
-- **********************************************************************
-- *                                                                    *
-- * Component to check the Preamble of an Ethernet frame for RMII PHYs *
-- *                                                                    *
-- * in:  iRXD    input data                                            *
-- *      iRXDV   Data Valid signal                                     *
-- *      iSync   Synchronization for every frame                       *
-- * out: oPreOk  Preamble valid                                        *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 11.05.12 V1.0 created Preamble_check      by Sebastian Muelhausen  *
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Preamble_check is
    port(
        clk, reset: in std_logic;
        iRXD:  in std_logic_vector(1 downto 0);
        iRXDV:  in std_logic;
        iSync:  in std_logic;
        oPreOk: out std_logic
    );
end Preamble_check;

architecture Behave of Preamble_check is

--Counter to count the toggelng Bits
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

    signal en: std_logic;
    signal clear: std_logic;
    signal cnt: std_logic_vector(5 downto 0);

begin

    en<='1' when iRXD="01" and iSync='1' else '0';--counting the Bits while the other components resets
    clear<= not iRXDV;                            --reset, when RXDV=0

    cnter:Basic_Cnter
    generic map(gCntWidth=>6)
    port map(
            clk=>clk, reset=>reset,
            iClear=>clear,iEn=>en,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ=>cnt, oOv=> open);

    oPreOk<='1' when cnt>std_logic_vector(to_unsigned(24,6)) else '0';

end Behave;