-- **********************************************************************
-- *                         Preamble_Generator                         *
-- **********************************************************************
-- *                                                                    *
-- * A Preamble generator for Ethernet frames. It starts with the state *
-- * "preamble" from the FSM Frame_starter.vhd                          *
-- *                                                                    *
-- * in:  iState    States from the FSM                                 *
-- * out: oTXD      Preamble output                                     *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 07.05.12 V1.0 created Preamble_Generator  by Sebastian Muelhausen  *
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Preamble_Generator is
    port(
        clk, reset:         in std_logic;
        iPreamble_Active:   in std_logic;
        oTXD:               out  std_logic_vector(1 downto 0)
    );
end Preamble_Generator;

architecture Behave of Preamble_Generator is

    --Counter for the generating of the Preamble
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

    signal sync: std_logic;
    signal cnt :std_logic_vector(4 downto 0);
begin

    sync<= '0' when iPreamble_Active='1' else '1';  --start of counter

    preamble_clk : Basic_Cnter
    generic map (gCntWidth => 5)
    port map (
            clk=>clk, reset=>reset,
            iClear=>sync,iEn => '1', iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ => cnt, oOv => open
            );

    --55 55 55 55 55 55 55 D5 Pattern
    oTXD <= "11" when cnt=std_logic_vector(to_unsigned(31,cnt'length)) else "01";


end Behave;