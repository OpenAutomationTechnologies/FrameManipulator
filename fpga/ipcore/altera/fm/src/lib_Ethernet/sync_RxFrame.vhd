-------------------------------------------------------------------------------
--! @file sync_RxFrame.vhd
--! @brief Synchronizer for the begin of an Ethernet frame
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


--! This is the entity of the synchronizer for Ethernet frame begin
entity sync_RxFrame is
    port(
        iClk        : in std_logic; --! clk
        iReset      : in std_logic; --! reset
        iRXDV       : in std_logic; --! RX data valid
        iRXD1       : in std_logic; --! Second bit of RMII RX data
        oSync       : out std_logic --! Synchronize output
    );
end sync_RxFrame;

--! @brief sync_RxFrame architecture
--! @details This is the synchronizer for an Ethernet frame begin
--! - Sync set at incoming RX-data-valid signal ("011" edge)
--! - Sync reset at end of Preamble ("01" edge of RXD(1))
architecture two_seg_arch of sync_RxFrame is

    signal set_q    : std_logic_vector(2 downto 0); --! current state of set shift register
    signal set_next : std_logic_vector(2 downto 0); --! new state of set shift register

    signal res_q    : std_logic_vector(1 downto 0); --! current state of reset shift register
    signal res_next : std_logic_vector(1 downto 0); --! new state of reset shift register

    signal syn      : std_logic := '0';             --! synchronisation signal

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            set_q <= (others=>'0');

        elsif rising_edge(iClk) then
            set_q <= set_next;
            res_q <= res_next;

            if (set_q="110") then
                syn <= '1';

            elsif (res_q="10") then
                syn <= '0';

            end if;

        end if;
    end process;


    res_next <= iRXD1 & res_q(1);           --shift register for set
    set_next <= iRXDV & set_q(2 downto 1);  --shift register for reset


     oSync <= syn;


end two_seg_arch;