-------------------------------------------------------------------------------
--! @file From_To_Cnt_Filter.vhd
--! @brief A filter for counter
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


--! This is the entity of a counter filter
entity From_To_Cnt_Filter is
    generic(
        gFrom       : natural:=13;  --! Lower limit
        gTo         : natural:=16;  --! Upper limit
        gWidthIn    : natural:=5;   --! Value width
        gWidthOut   : natural:=2    --! Value cnt out
        );
    port(
        iClk    : in std_logic;                                 --! Clock
        iReset  : in std_logic;                                 --! Reset
        iCnt    : in std_logic_vector(gWidthIn-1 downto 0);     --! Input data for the filter
        oCnt    : out std_logic_vector(gWidthOut-1 downto 0);   --! Output data
        oEn     : out std_logic;                                --! Input data is between the limits
        oEnd    : out std_logic                                 --! Input Data beyond the limits
     );
end From_To_Cnt_Filter;

--! @brief From_To_Cnt_Filter architecture
--! @details A filter for counter
--! e.g.: gFrom=12 gTo =15
--!      iCnt || oCnt | oEn | oEnd
--!     --------------------------
--!       10  ||   0  |  0  |  0
--!       11  ||   0  |  0  |  0
--!       12  ||   0  |  1  |  0
--!       13  ||   1  |  1  |  0
--!       14  ||   2  |  1  |  0
--!       15  ||   3  |  1  |  0
--!       16  ||   0  |  0  |  1
--!       17  ||   0  |  0  |  1
architecture two_seg_arch of From_To_Cnt_Filter is

    constant cNumbZero  : std_logic_vector(gWidthIn-1 downto 0) := std_logic_vector(to_unsigned(0,gWidthIn));      --! Zero
    constant cNumbFrom  : std_logic_vector(gWidthIn-1 downto 0) := std_logic_vector(to_unsigned(gFrom,gWidthIn));  --! From: lower limit
    constant cNumbEnd   : std_logic_vector(gWidthIn-1 downto 0) := std_logic_vector(to_unsigned(gTo+1,gWidthIn));  --! To+1: beyond upper limit

     --! Typedef for registers
    type tReg is record
        en      : std_logic;                                --! Register of En
        endo    : std_logic;                                --! Register of End
        cnt     : std_logic_vector(gWidthIn-1 downto 0);    --! Register of iCnt for edge detection
        q       : unsigned(gWidthOut-1 downto 0);           --! Stored cnt value
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                en      => '0',
                                endo    => '0',
                                cnt     => (others=>'0'),
                                q       => (others=>'0')
                                );

    signal reg      : tReg; --! Registers
    signal reg_next : tReg; --! Next register value


begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;



    --! @brief Next register logic
    --! - Next signal is also the output signal
    --! - Set/Reset of En and End
    --! - Count up at edge of iCnt
    combNext :
    process(iCnt, reg)
    begin

        reg_next        <= reg;
        reg_next.cnt    <= iCnt;


        --Cnt out at edge (while en=1)
        if reg.cnt /= iCnt and
            reg.En  = '1' then

            reg_next.q  <= reg.q+1;

        end if;


        --Set/Reset En
        if iCnt = cNumbFrom then
            reg_next.en <= '1';

        elsif iCnt = cNumbEnd then
            reg_next.en <= '0';

        end if;


        --Set/Reset End
        if iCnt = cNumbEnd then
            reg_next.endo   <= '1';
            reg_next.q      <= cRegInit.q;

        elsif iCnt = cNumbZero then
            reg_next.endo   <= '0';

        end if;


    end process;


    oEnd    <= reg_next.endo;
    oEn     <= reg_next.en;
    oCnt    <= std_logic_vector(reg_next.q);


end two_seg_arch;