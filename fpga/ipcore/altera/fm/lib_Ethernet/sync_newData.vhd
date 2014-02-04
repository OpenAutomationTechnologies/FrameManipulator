-------------------------------------------------------------------------------
--! @file sync_newData.vhd
--! @brief Synchronizer which sends a sync signal, when new Data arrives
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

--! This is the entity of the synchronizer at incoming data
entity sync_newData is
    generic(
            gWidth  : natural:=8    --! Data width
            );
    port(
        iClk        : in std_logic;                             --! clk
        iReset      : in std_logic;                             --! reset
        iData       : in std_logic_vector(gWidth-1 downto 0);   --! Data stream in
        oData       : out std_logic_vector(gWidth-1 downto 0);  --! Data stream out with 1 cycle delay
        oSync       : out std_logic                             --! Synchronisate all stations
    );
end sync_newData;


--! @brief sync_newData architecture
--! @details Synchronizer which sends a sync signal, when new Data arrives
architecture two_seg_arch of sync_newData is

    signal r_q      : std_logic_vector(gWidth-1 downto 0);  --! current state of set shift register
    signal r_next   : std_logic_vector(gWidth-1 downto 0);  --! new state of set shift register

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - setting of the Sync signal
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            r_q <= (others=>'0');

        elsif rising_edge(iClk) then
            r_q <= r_next;

        end if;
    end process;


    r_next <= iData;

    oData <= r_q;
    oSync <= '0' when r_q=r_next else '1';   --output =1, when new Data != old Data

end two_seg_arch;