-------------------------------------------------------------------------------
--! @file tbFromToCntFilter.vhd
--! @brief Testbench for FromToCntFilter
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


--! This is the testbench of From_To_Cnt_Filter
entity tbFromToCntFilter is
    generic(gStimFile   : string := "in.txt";   --! Stimulation file
            gfileOut    : string := "out.txt";  --! Output file
            gFrom       : natural:=13;          --! Lower limit
            gTo         : natural:=16;          --! Upper limit
            gWidthIn    : natural:=5;           --! Value width
            gWidthOut   : natural:=2            --! Value cnt out
            );
end tbFromToCntFilter;

--! @brief tbFromToCntFilter architecture
--! @details Testbench for FromToCntFilter
--! - Testbench won't stop in case of an error
--! - The module check will be processed in the shell post script afterwards
architecture two_seg_arch of tbFromToCntFilter is

    constant cByteLength    : natural := 8;

    constant cPeriode   : time := 20 ns;    -- used 50 MHz clock cycle FM/RMII-clock

    signal Cnt          : std_logic_vector(gWidthIn-1 downto 0) := (others => '0'); --! generated iCnt signal
    signal dutCnt       : std_logic_vector(gWidthOut-1 downto 0);                   --! oCnt from DUT
    signal dutEn        : std_logic;                                                --! oEn from DUT
    signal dutEnd       : std_logic;                                                --! oEnd from DUT

    signal clk          : std_logic :='0';  --! Generated clock for testbench: 50MHz

    signal testDone     : std_logic := '0'; --! Test has finished


begin

    clk <= not clk after cPeriode/2 when testDone /= '1' else '0' after cPeriode/2;


    --! Read stimulation file
    reading :
    process

        file        fInFile         : text;
        variable    vInLine         : line;
        variable    vCnt            : std_logic_vector(cByteLength-1 downto 0);
        variable    vGood           : boolean;
        variable    vFileOpenStatus : FILE_OPEN_STATUS;

    begin

        testDone    <= '0';

        file_open(vFileOpenStatus, fInFile, gStimFile, READ_MODE);

        if vFileOpenStatus = OPEN_OK then
            assert (FALSE)
                report "Open file " & gStimFile & " successfully"
                severity note;

        else
            assert (FALSE)
                report "Open file " & gStimFile & " failed!"
                severity failure;

        end if;


        while not endfile(fInFile) loop

            wait until rising_edge(clk);

            readline(fInFile, vInLine);
            HREAD(vInLine, vCnt, vGood);

            if vGood then
                Cnt <= vCnt(Cnt'range);

            end if;

        end loop;

        testDone    <= '1';

        file_close(fInFile);

        wait;

    end process reading;


    --! DUT
    dut : entity work.From_To_Cnt_Filter
    generic map(
                gFrom       => gFrom,
                gTo         => gTo,
                gWidthIn    => gWidthIn,
                gWidthOut   => gWidthOut
                )
    port map(
            iCnt    => Cnt,
            oCnt    => dutCnt,
            oEn     => dutEn,
            oEnd    => dutEnd
            );


    --! Output Datas
    writing :
    process

        file        fOutFile    : text;
        variable    vLineData   : line;

    begin

        file_open(fOutFile, gfileOut, Write_MODE);

        while testDone='0' loop

            wait until Cnt'event;

            wait for 2 ns;  -- wait to update signals

            hwrite(vLineData, Cnt);
            write(vLineData, string'(" ") );
            hwrite(vLineData, dutCnt);
            write(vLineData, string'(" ") );
            write(vLineData, dutEn);
            write(vLineData, string'(" ") );
            write(vLineData, dutEnd);

            writeline(fOutFile, vLineData);

        end loop;

        file_close(fOutFile);

        wait;

    end process writing;


end two_seg_arch;