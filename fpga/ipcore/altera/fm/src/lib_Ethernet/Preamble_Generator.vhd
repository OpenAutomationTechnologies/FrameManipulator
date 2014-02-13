-------------------------------------------------------------------------------
--! @file Preamble_Generator.vhd
--! @brief A Preamble generator for Ethernet frames
-------------------------------------------------------------------------------
--
--    (c) B&R, 2014
--
--    Redistribution and use in source and binary forms, with or without
--    modification, are permitted provided that the following conditions
--    are met:
--
--    1. Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--
--    2. Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
--    3. Neither the name of B&R nor the names of its
--       contributors may be used to endorse or promote products derived
--       from this software without prior written permission. For written
--       permission, please contact office@br-automation.com
--
--    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--    COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
--    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
--    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
--    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--    POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------


--! Use standard ieee library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric functions
use ieee.numeric_std.all;


--! This is the entity of the a Preamble generator for Ethernet frames
entity Preamble_Generator is
    port(
        iClk                : in std_logic;                     --! clk
        iReset              : in std_logic;                     --! reset
        iPreambleActive     : in std_logic;                     --! Module is active
        oTXD                : out  std_logic_vector(1 downto 0) --! Output stream
    );
end Preamble_Generator;


--! @brief Preamble_Generator architecture
--! @details Creates Preamble pattern for ethernet frames
architecture Behave of Preamble_Generator is

    signal sync : std_logic;                    --! Synchronous reset when module is inactive
    signal cnt  : std_logic_vector(4 downto 0); --! Counter value to detect Position for "55 D5" pattern

begin

    sync<= '0' when iPreambleActive='1' else '1';  --start of counter

    --! @brief Counter for Preamble
    --! - Sync, when modul is inactive
    preamble_clk : entity work.FixCnter
    generic map (
                gCntWidth   => 5,
                gStartValue => (4 downto 0=>'0'),
                gInitValue  => (4 downto 0=>'0'),
                gEndValue   => (4 downto 0=>'1')
                )
    port map (
            iClk    => iClk,
            iReset  => iReset,
            iClear  => sync,
            iEn     => '1',
            oQ      => cnt,
            oOv     => open
            );

    --55 55 55 55 55 55 55 D5 Pattern
    oTXD <= "11" when cnt=std_logic_vector(to_unsigned(31,cnt'length)) else "01";


end Behave;