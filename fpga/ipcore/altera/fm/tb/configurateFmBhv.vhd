-------------------------------------------------------------------------------
--! @file configurateFmBhv.vhd
--! @brief Testbench module to configure predefined tests
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
--! Use text functions
use ieee.std_logic_textio.all ;

--! Use std library
library std;
--! Use text functions
use std.textio.all;


--! This is the testbench module to configure predefined tests
entity configurateFm is
    generic(
            gTestSetting        : string := "passTest"              --! Task configuration
            );
    port(
        iWrCommAddr : in std_logic_vector(7 downto 0);      --! clock
        oCommData   : out std_logic_vector(31 downto 0)     --! Test finished
        );
end configurateFm;

--! @brief configurateFm architecture
--! @details Testbench module to configure predefined tests
architecture bhv of configurateFm is

begin

    pass:
    if gTestSetting="passTest" generate

        --! Generate configuration
        with iWrCommAddr select
        oCommData<= X"00000000" when "00000001",    --Setting 1 part 1
                    X"00000000" when "00000000",    --Setting 1 part 2
                    X"00000000" when "01000001",    --Setting 2 part 1
                    X"00000000" when "01000000",    --Setting 2 part 2
                    X"00000000" when "10000001",    --Frame data part 1
                    X"00000000" when "10000000",    --Frame data part 2
                    X"00000000" when "11000001",    --Frame mask part 1
                    X"00000000" when "11000000",    --Frame mask part 2
                    X"00000000" when others;

    end generate pass;


    drop:
    if gTestSetting="dropSocCycle2" generate

        --! Generate configuration
        with iWrCommAddr select
        oCommData<= X"02010000" when "00000001",    --Setting 1 part 1
                    X"00000000" when "00000000",    --Setting 1 part 2
                    X"00000000" when "01000001",    --Setting 2 part 1
                    X"00000000" when "01000000",    --Setting 2 part 2
                    X"01FF0000" when "10000001",    --Frame data part 1
                    X"00000000" when "10000000",    --Frame data part 2
                    X"FFFF0000" when "11000001",    --Frame mask part 1
                    X"00000000" when "11000000",    --Frame mask part 2
                    X"00000000" when others;

    end generate drop;

end bhv;
