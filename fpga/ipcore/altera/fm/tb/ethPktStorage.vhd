-------------------------------------------------------------------------------
--! @file ethPktStorage.vhd
--! @brief Testbench module to store Ethernet frames
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

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;


--! This is the testbench module to store Ethernet frames
entity ethPktStorage is
    generic(
            gVariableName   : string := "FRAME";
            gFileFrameOut   : string := "out.txt"         --! Output of frame data
            );
    port(
        iClk        : in std_logic;                     --! clock
        iTestDone   : in std_logic;                     --! Test finished
        iDataValid  : in std_logic;                     --! RMII data valid
        iData       : in std_logic_vector(1 downto 0)   --! RMII data
        );
end ethPktStorage;

--! @brief ethPktStorage architecture
--! @details Testbench module to store Ethernet frames
--! - Storage of frames as bash-variables
architecture bhv of ethPktStorage is

begin


    --! Output Ethernet stream
    writing :
    process

        file        fOutFile    : text;
        variable    vLineData   : line;
        variable    vEthByte    : std_logic_vector(cByteLength-1 downto 0);
        variable    vFrameNr    : natural := 0;

    begin

        file_open(fOutFile, gFileFrameOut, WRITE_MODE);

        write(vLineData, string'("#!/bin/bash") );
        writeline(fOutFile, vLineData);

        while iTestDone/='1' loop

            if iDataValid='1' then

                vFrameNr    := vFrameNr+1;

                write(vLineData, string'(gVariableName) );
                write(vLineData, vFrameNr );
                write(vLineData, string'("=(") );

                while iDataValid='1' loop

                    vEthByte(1 downto 0)    := iData;

                    wait until rising_edge(iClk);

                    vEthByte(3 downto 2)    := iData;

                    wait until rising_edge(iClk);

                    vEthByte(5 downto 4)    := iData;

                    wait until rising_edge(iClk);

                    vEthByte(7 downto 6)    := iData;

                    wait until rising_edge(iClk);

                    hwrite(vLineData, vEthByte);
                    write(vLineData, string'(" ") );

                end loop;

                write(vLineData, string'(")") );

                writeline(fOutFile, vLineData);

            else
                wait until rising_edge(iClk) or iTestDone='1';

            end if;
        end loop;

        write(vLineData, string'("NR_OF_") );
        write(vLineData, string'(gVariableName) );
        write(vLineData, string'("=") );
        write(vLineData, vFrameNr );

        writeline(fOutFile, vLineData);

        file_close(fOutFile);

        wait;

    end process writing;

end bhv;