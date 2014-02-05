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

    signal cnt      : natural;      --! iCnt as number
    signal cntout   : natural;      --! oCnt as number
    signal en       : std_logic;    --! oEn
    signal endo     : std_logic;    --! oEnd

begin


    cnt <=to_integer(unsigned(iCnt));

    endo <= '1' when cnt > gTo   else '0';
    en  <= '1' when (cnt > (gFrom-1))and (endo = '0')  else '0';

    cntout <= cnt-gFrom when en='1' else 0;

    oCnt <= std_logic_vector(to_unsigned(cntout,gWidthOut));
    oEnd <= endo;
    oEn  <= en;

end two_seg_arch;