-------------------------------------------------------------------------------
--! @file adder_2121.vhd
--! @brief Module for merging two inputs alternating bitwise
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


--! This is the entity of the module for merging two inputs alternating bitwise
entity adder_2121 is
    generic(
            WIDTH_IN: natural   := 4    --! Word width
            );
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iD1         : in std_logic_vector(WIDTH_IN-1 downto 0);     --! Data 1
        iD2         : in std_logic_vector(WIDTH_IN-1 downto 0);     --! Data 2
        iEn         : in std_logic;                                 --! Enable => output active
        oQ          : out std_logic_vector((WIDTH_IN*2)-1 downto 0) --! Data out
    );
end adder_2121;

--! @brief adder_2121 architecture
--! @details Module for merging two inputs alternating bitwise
architecture two_seg_arch of adder_2121 is

    signal r_q          : std_logic_vector((WIDTH_IN*2)-1 downto 0);    --! current value
    signal r_next       : std_logic_vector((WIDTH_IN*2)-1 downto 0);    --! next value
    signal r_calculated : std_logic_vector((WIDTH_IN*2)-1 downto 0);    --! calculated new value

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            r_q <= (others=>'0');

        elsif rising_edge(iClk) then
            r_q <= r_next;

        end if;
    end process;

    --! @brief Merge data
    combMerge :
    process(iD1,iD2)
    begin

        for i in 0 to (WIDTH_IN)-1 loop
              r_calculated(i*2)     <= iD1(i);
              r_calculated(i*2+1)   <= iD2(i);
        end loop;

    end process;


    r_next <= r_calculated when iEn='1' else r_q;

    oQ <= r_q;

end two_seg_arch;