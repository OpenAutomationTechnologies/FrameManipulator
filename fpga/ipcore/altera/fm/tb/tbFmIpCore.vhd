-------------------------------------------------------------------------------
--! @file tbFmIpCore.vhd
--! @brief Testbench for Framemanipulator IP-core
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

--! use work library
library work;

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;


--! This is the testbench of Framemanipulator IP-core
entity tbFmIpCore is
    generic(gStimIn             : string := "stimEthPacket.txt";    --! Stimulation file in
            gFileFrameOutStim   : string := "outStim.txt";          --! Output of stimulation file
            gFileFrameOutFm     : string := "outFm.txt";            --! Output of stimulation file
            gFileFrameOutTiming : string := "outTiming.txt"         --! Output of frame delay
            );
end tbFmIpCore;

--! @brief tbFmIpCore architecture
--! @details Testbench for Framemanipulator IP-core
--! - Testbench creates Ethernet stream from stimulation file
--! - Stimulated data stream, output stream and frame delay will be stored in
--!   separate files. The data is allocated to bash-variables
--! - Testbench won't stop in case of an error
--! - The module check will be processed in the shell post script afterwards
architecture two_seg_arch of tbFmIpCore is

    constant cPeriode   : time := 20 ns;     -- used 50 MHz clock cycle FM/RMII-clock

    signal wrCommAddr   : std_logic_vector(7 downto 0) := (others => '0');  --! Write address of task-buffer
    signal commData     : std_logic_vector(31 downto 0) := (others => '0'); --! data of task-buffer
    signal writeEn      : std_logic;                                        --! write enable

    signal clk      : std_logic := '0'; --! 50 MHz clock
    signal reset    : std_logic := '1'; --! reset
    signal testDone : std_logic;        --! test finished
    signal stimDone : std_logic;        --! end of stimulation file
    signal trig     : std_logic;        --! trigger of the next frame

    signal RXDV : std_logic := '0';                                 --! RMII data valid to FM
    signal RXD  : std_logic_vector(1 downto 0) := (others => '0');  --! RMII data to FM
    signal TXDV : std_logic;                                        --! RMII data valid from FM
    signal TXD  : std_logic_vector(1 downto 0);                     --! RMII data from FM
    signal LED  : std_logic_vector(1 downto 0);                     --! FM LED output


begin


    clk     <= not clk after cPeriode/2 when testDone /= '1' else '0' after cPeriode/2;

    reset   <= '1', '0' after 50 ns;


    --! Start of next frame every 10µs
    newFrame:
    process

        variable vCntTrig  : natural := 1;

    begin

        testDone    <= '0';
        trig        <= '0';

        wait for 100 ns;

        while stimDone/= '1' loop

            trig    <= '1';

            wait for 20 ns;

            trig    <= '0';

            wait for 10000 ns;

            vCntTrig    := vCntTrig+1;

        end loop;

        testDone    <= '1';

        wait;

    end process;


    writeEn <='0' when CommData=X"000F0000" else '1';

    --! DUT
    FM : entity work.FrameManipulator
    generic map(gBytesOfTheFrameBuffer=>1600)
    port map(
            iClk50          => clk,
            iReset          => reset,
            iS_clk          => clk,
            iRXDV           => RXDV,
            iRXD            => RXD,
            iSt_address     => wrCommAddr,
            iSt_writedata   => commData,
            iSt_write       => writeEn,
            iSt_read        => '0',
            iSt_byteenable  => "1111",
            iSc_address     => "0",
            iSc_writedata   => X"01",
            iSc_write       => '1',
            iSc_read        => '0',
            iSc_byteenable  => "1",
            oSt_readdata    => open,
            oSc_readdata    => open,
            oTXData         => TXD,
            oTXDV           => TXDV,
            oLED            => LED
            );


    wrCommAddr  <= (others=>'0');
    commData    <= (others=>'0');


    --! Ethernet packet generator
    packGen : entity work.ethPktGen
    generic map(gDataWidth  => 2)
    port map(
            iClk        => clk,
            iRst        => reset,
            iTrigTx     => trig,
            iSrcFile    => gStimIn,
            oTxEnable   => RXDV,
            oTxData     => RXD,
            oTxDone     => open,
            oStimDone   => stimDone
            );


    --! Output input data
    writingStim : entity work.ethPktStorage
    generic map(
                gVariableName   => "FRAME",
                gFileFrameOut   => gFileFrameOutStim
                )
    port map(
            iClk        => clk,
            iTestDone   => testDone,
            iDataValid  => RXDV,
            iData       => RXD
            );


    --! Output FM data
    writingTx : entity work.ethPktStorage
    generic map(
                gVariableName   => "FM_FRAME",
                gFileFrameOut   => gFileFrameOutFm
                )
    port map(
            iClk        => clk,
            iTestDone   => testDone,
            iDataValid  => TXDV,
            iData       => TXD
            );


    --! Measure frame delay
    writingTiming :
    process

        file        fOutFile    : text;
        variable    vLineData   : line;
        variable    vTimeDelay  : time;
        variable    vFrameNr    : natural := 0;

    begin

        file_open(fOutFile, gFileFrameOutTiming, WRITE_MODE);

        write(vLineData, string'("#!/bin/bash") );
        writeline(fOutFile, vLineData);

        while testDone/='1' loop

            wait until rising_edge(RXDV);

            vFrameNr    := vFrameNr+1;
            vTimeDelay  := 0 ns;

            while TXDV/='1' loop
                vTimeDelay  :=vTimeDelay+cPeriode;

                wait until rising_edge(clk);
                wait for 2 ns;  -- wait to update signals

            end loop;

            write(vLineData, string'("FRAME_DELAY") );
            write(vLineData, vFrameNr );
            write(vLineData, string'("='") );
            write(vLineData, vTimeDelay);
            write(vLineData, string'("'") );

            writeline(fOutFile, vLineData);

        end loop;

        file_close(fOutFile);

        wait;

    end process writingTiming;

end two_seg_arch;