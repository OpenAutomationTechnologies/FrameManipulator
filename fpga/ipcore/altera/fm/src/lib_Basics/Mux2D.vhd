-------------------------------------------------------------------------------
--! @file Mux2D.vhd
--! @brief Two-dimensional Multiplexer using an one-dimensional parameterized tree-shaped multiplexer
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


--! This is the entity of the two-dimensional Multiplexer
entity Mux2D is
    generic(
            gWordsWidth : natural:=8;   --! Word width
            gWordsNo    : natural:=8;   --! Number of words
            gWidthSel   : natural:=3    --! Width of select input
            );
    port(
        iData   : in std_logic_vector(gWordsWidth*gWordsNo-1 downto 0); --! Data with multiple Words
        iSel    : in std_logic_vector(gWidthSel-1 downto 0);            --! Select
        oWord   : out std_logic_vector(gWordsWidth-1 downto 0)          --! Word out
        );
end Mux2D;


--! @brief Mux2D architecture
--! @details Two-dimensional Multiplexer using an one-dimensional parameterized tree-shaped multiplexer
--! - Source: RTL Hardware Design Using VHDL
architecture loop_tree_arch of Mux2D is

    --! Length of a Row
    constant cRoW   : natural := gWordsWidth;

    --! Selection of the words in the data like an array
    function ix(c,r:natural) return natural is
    begin
        return (c*cRoW+r);
    end ix;


    type array_transpose_type is
        array(gWordsWidth-1 downto 0) of std_logic_vector(gWordsNo-1 downto 0);

    signal arrayConnect : array_transpose_type; --! Array with input data


begin


    --! @brief convert to array-of-array data type
    conv :
    process(iData)
    begin
        for i in 0 to (gWordsWidth-1) loop
            for j in 0 to (gWordsNo-1) loop
                arrayConnect(i)(j)  <= iData(ix(j,i));
            end loop;
        end loop;
    end process;


    --! @brief replicate 1-Bit multiplexer gWordsWidth times
    gen_nbit :
    for i in 0 to (gWordsWidth-1) generate
        mux : entity work.Mux1D
            generic map(gWidthData  => gWordsNo,
                        gWidthSel   => gWidthSel
                        )
            port map(
                    iData   => arrayConnect(i),
                    iSel    => iSel,
                    oBit    => oWord(i));

    end generate;


end loop_tree_arch;