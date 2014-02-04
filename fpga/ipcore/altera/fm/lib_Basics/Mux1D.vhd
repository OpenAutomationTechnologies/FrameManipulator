-------------------------------------------------------------------------------
--! @file Mux1D.vhd
--! @brief Parameterized tree-shaped multiplexer
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


--! This is the entity of the tree-shaped multiplexer
entity Mux1D is
    generic(
            gWidthData  :  natural :=8; --! Data width
            gWidthSel   :  natural :=3  --! Width of select input
            );
    port(
        iData:  in std_logic_vector(gWidthData-1 downto 0); --! Data
        iSel:   in std_logic_vector(gWidthSel-1 downto 0);  --! Select
        oBit:   out std_logic                               --! Bit out
        );
end Mux1D;


--! @brief Mux1D architecture
--! @details Parameterized tree-shaped multiplexer
--! - Source: RTL Hardware Design Using VHDL
architecture loop_tree_arch of Mux1D is

    --! Tree size
    constant cStage: natural:=gWidthSel;

    --! 2d bit array
    type std_logic_2d is
        array (natural range <>, natural range <>) of std_logic;

    --! bit array p
    signal p    : std_logic_2d(cStage downto 0, 2**cStage-1 downto 0);

begin

    --! @brief Tree-shaped logic
    comb :
    process(iData,iSel,p)
    begin
        for i in 0 to (2**cStage-1) loop
            if i<gWidthData then
                p(cStage,i) <= iData(i);    --rename input signal
            else
                p(cStage,i) <= '0';     --padding 0's
            end if;
        end loop;

        --replace structure

        for s in (cStage-1) downto 0 loop
            for r in 0 to (2**s-1) loop
                if iSel((cStage-1)-s)='0' then
                    p(s,r) <= p(s+1,2*r);
                else
                    p(s,r) <= p(s+1,2*r+1);
                end if;
            end loop;
        end loop;
    end process;

    --rename output signal
    oBit<= p(0,0);

end loop_tree_arch;