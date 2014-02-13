-------------------------------------------------------------------------------
--! @file Preamble_check.vhd
--! @brief Component to check the Preamble of an Ethernet frame for RMII PHYs
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

--! This is the entity of the Preamble check
entity Preamble_check is
    port(
        iClk        : in std_logic;                     --! clk
        iReset      : in std_logic;                     --! reset
        iRXD        : in std_logic_vector(1 downto 0);  --! RMII-RX data
        iRXDV       : in std_logic;                     --! RX data valid
        iSync       : in std_logic;                     --! Modul synchronisation
        oPreOk      : out std_logic                     --! Preamble is correct
    );
end Preamble_check;


--! @brief Preamble_check architecture
--! @details Component to check the Preamble of an Ethernet frame for RMII PHYs
--! - Counting of the toggeling Bits
architecture Behave of Preamble_check is

    signal en       : std_logic;                    --! Counter enable
    signal clear    : std_logic;                    --! Counter clear when RXDV=0
    signal cnt      : std_logic_vector(5 downto 0); --! Value of counter

begin

    en      <= '1' when iRXD="01" and iSync='1' else '0';   --counting the Bits while the other components resets
    clear   <= not iRXDV;                                   --reset, when RXDV=0

    --! @brief Counter of toggeling Preamble
    --! - Count up at toggeling bit
    --! - Clear at RXDV = 0
    cnter : entity work.FixCnter
    generic map(
                gCntWidth   => 6,
                gStartValue => (5 downto 0=>'0'),
                gInitValue  => (5 downto 0=>'0'),
                gEndValue   => (5 downto 0=>'1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => clear,
            iEn     => en,
            oQ      => cnt,
            oOv     => open
            );

    oPreOk<='1' when cnt>std_logic_vector(to_unsigned(24,6)) else '0';

end Behave;