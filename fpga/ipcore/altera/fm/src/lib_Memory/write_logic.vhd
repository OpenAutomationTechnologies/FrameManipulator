-------------------------------------------------------------------------------
--! @file write_logic.vhd
--! @brief Logic to write Ethernet frames into a DPRAM
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

--! Use work library
library work;
--! use global library
use work.global.all;


--! This is the entity of a write logic for memories
entity write_logic is
    generic(
            gPrescaler  : natural:=4;   --! Prescaler value
            gAddrWidth  : natural:=11   --! Width of address
            );
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iSync       : in std_logic;                                 --! Synchronous reset
        iEn         : in std_logic;                                 --! Cnt enable
        iStartAddr  : in std_logic_vector(gAddrWidth-1 downto 0);   --! Start address
        oAddr       : out std_logic_vector(gAddrWidth-1 downto 0);  --! Write address
        oWrEn       : out std_logic                                 --! Write enable
    );
end write_logic;


--! @brief write_logic architecture
--! @details Logic to write Ethernet frames into a DPRAM
--! - With adjustable prescaler
architecture two_seg_arch of write_logic is

    signal preEn    : std_logic_vector(LogDualis(gPrescaler)-1 downto 0) := (others=>'0');  --! Prescaler enable
    signal add_en   : std_logic;                                                            --! Enable address counter

begin

    --! @brief Included prescaler
    Prescale:
    if gPrescaler>1 generate

        --! @brief Prescaler with counter
        difpre_clk : entity work.Basic_Cnter
        generic map (gCntWidth => LogDualis(gPrescaler))
        port map (
                iClk        => iClk,
                iReset      => iReset,
                iClear      => iSync,
                iEn         => iEn,
                iStartValue => (others=>'0'),
                iEndValue   => (others=>'1'),
                oQ          => preEn,
                oOv         => open
                );
    end generate;

    --TODO Case gPrescaler=0

    add_en  <= '1' when preEn = (preEn'range=>'0') and iEn = '1' else '0';
    oWrEn   <= add_en;

    --! @brief Address counter
    addr_cnt : entity work.Basic_Cnter
    generic map (gCntWidth => gAddrWidth)
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iClear      => iSync,
            iEn         => add_en,
            iStartValue => iStartAddr,
            iEndValue   => (others=>'1'),
            oQ          => oAddr,
            oOv         => open
            );


end two_seg_arch;