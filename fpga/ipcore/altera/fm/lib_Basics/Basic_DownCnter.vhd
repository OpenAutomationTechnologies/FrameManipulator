-------------------------------------------------------------------------------
--! @file Basic_DownCnter.vhd
--! @brief Generic down counter with overflow-flag
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

--! This is the entity of the top-module for the generic down counter
entity Basic_DownCnter is -- TODO: Combine this module with the Basic_Counter. Up/Down-count setting via generic
    generic(
            gCntWidth   : natural := 2  --! Width of the coutner
            );
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iClear      : in std_logic;                                 --! Synchronous reset
        iEn         : in std_logic;                                 --! Cnt Enable
        iStartValue : in std_logic_vector(gCntWidth-1 downto 0);    --! Init value
        iEndValue   : in std_logic_vector(gCntWidth-1 downto 0);    --! End value
        oQ          : out std_logic_vector(gCntWidth-1 downto 0);   --! Current value
        oOv         : out std_logic                                 --! Overflow
    );
end Basic_DownCnter;


--! @brief Basic_DownCnter architecture
--! @details Generic down counter
--! - With synchronous reset iClear
--! - Counts down at enable
--! - Init and end value
--! - Overflow at end value
architecture two_seg_arch of Basic_DownCnter is

    signal r_next   : unsigned(gCntWidth-1 downto 0);   --! Next value
    signal r_q      : unsigned(gCntWidth-1 downto 0);   --! Stored value

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            r_q <= (others => '0');

        elsif rising_edge(iClk) then
            r_q <= r_next;

        end if;
    end process;


    --! @brief Next value logic
    --! - Synchronous reset at clear with init value
    --! - Cnt at enable
    --! - Overflow at end value
    process(iClear, iEn, iStartValue, iEndValue,r_q)
    begin
        r_next<=r_q;
        oOv<='0';

        if iClear='1' then
            r_next<=unsigned(iStartValue);

        elsif iEn='1' then
            r_next<=r_q-1;

            if r_q=unsigned(iEndValue) then --"<=" isn't allowed. The end value of the timer could be behind its overflow
                r_next <= (others=>'1');
                oOv<='1';
            end if;

        end if;

    end process;

     oQ <= std_logic_vector(r_q);

end two_seg_arch;