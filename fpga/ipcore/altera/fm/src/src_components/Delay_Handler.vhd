-------------------------------------------------------------------------------
--! @file Delay_Handler.vhd
--! @brief Handles the delay task of the frames
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


--! Use work library
library work;
--! use fm library
use work.framemanipulatorPkg.all;

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;


--! This is the entity of module, which handles the delay task of the frames.
entity Delay_Handler is
    generic(
            gDelayDataWidth : natural:=6*cByteLength;   --! Width of delay setting
            gNoOfDelFrames  : natural:=255              --! Maximal number of delayed frames
            );
    port(
        iClk                : in std_logic;     --! clk
        iReset              : in std_logic;     --! reset
        --control signals
        iStart              : in std_logic;     --! start delay process
        iFrameIsSoC         : in std_logic;     --! current frame is a SoC
        iTestSync           : in std_logic;     --! reset: a new test has started
        iTestStop           : in std_logic;     --! abort of test series
        oStartAddrStorage   : out std_logic;    --! start storage of the frame-data positions
        --delay variables
        iDelayEn            : in std_logic;                                                 --! task: delay enable
        iDelayData          : in std_logic_vector(gDelayDataWidth-1 downto 0);              --! delay data
        iDelFrameLoaded     : in std_logic;                                                 --! a deleted frame was loaded from the address-fifo
        oCurrentTime        : out std_logic_vector(gDelayDataWidth-cByteLength downto 0);   --! timeline which starts with the first delayed frame
        oDelayTime          : out std_logic_vector(gDelayDataWidth-cByteLength downto 0)    --! start time of the stored frame
     );                                        --size=gDelayDataWidth-stateByte+1 bit to prevent overflow
end Delay_Handler;


--! @brief Delay_Handler architecture
--! @details Handles the delay task of the frames.
--! - It provides the current time after the first task and the timestamp of the outgoing frames.
--! - It also droppes the other incoming framesdepending on the delay-operation-byte.
architecture two_seg_arch of Delay_Handler is


    --constants
    --!width of the time-variables: DelaySettings -1Byte for operation +1Bit toprevent overflow
    constant cSize_Time : natural:=gDelayDataWidth-cByteLength+1;


    --Registers
    --! Typedef for registers
    type tReg is record
        delFrameLoaded  : std_logic;                                    --! Register for edge detection of iDelFrameLoaded
        delayFrame      : std_logic;                                    --! Register for edge detection of iDelayEn + passFrame
        delayType       : std_logic_vector(cByteLength-1 downto 0);     --! Register of delay type
    end record;

    --! Init for registers
    constant cRegInit   : tReg :=  (
                                    delFrameLoaded  => '0',
                                    delayFrame      => '0',
                                    delayType       => (others=>'0')
                                    );


    signal reg          : tReg; --! Register
    signal reg_next     : tReg; --! Next value of register

    --edge detection of task enable
    signal delFrameLoaded_negEdge   : std_logic;    --! negative edge detection of outgoing delayed-frames
    signal delayFrame_posEdge       : std_logic;    --! Positive edge detection of oDelayEnabl, when PassFrame=1


    --signals
    signal passFrame            : std_logic;    --!Frame is processed (not dropped)

    --signal for FSM
    signal active               : std_logic;    --! delay is active
    signal noDelFrameInBuffer   : std_logic;    --! all delayed frames has left the buffer

    --Counter for Stored and loaded Delayed Frames
    signal delCntSync   : std_logic;                                              --! reset cnter
    signal pushCntEn    : std_logic;                                              --! Cnt up number of delayed frames
    signal delCntPush   : std_logic_vector(LogDualis(gNoOfDelFrames)-1 downto 0); --! Number of "pushed" delayed frames to the buffer
    signal delCntPull   : std_logic_vector(LogDualis(gNoOfDelFrames)-1 downto 0); --! Number of "pulled" delayed frames to the buffer


    --current time in 50MHz ticks
    signal currentTime          : std_logic_vector(cSize_Time-1 downto 0);  --! current Timestamp in 20ns

begin

    --edge detections----------------------------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then   --TODO rebuild with register type
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;


    delFrameLoaded_negEdge  <= '1' when reg_next.delFrameLoaded='0' and reg.delFrameLoaded='1' else '0';
            --Counting on the negativ Edge => Frame was already loaded

    delayFrame_posEdge      <= '1' when reg_next.delayFrame='1' and reg.delayFrame='0' else '0';
    --------------------------------------------------------------------------------------



    --Counting of delayed-frames ----------------------------------------------------------

    --! @brief Delay FSM
    --! - provides active-task signal, cnts the push-cnter up and resets the frame-cnter
    FSM : entity work.Delay_FSM
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iDelayEn            => delayFrame_posEdge,
            iTestSync           => iTestSync,
            iTestStop           => iTestStop,
            iNoDelFrameInBuffer => noDelFrameInBuffer,
            oActive             => active,
            oPushCntEn          => pushCntEn,
            oDelCntSync         => delCntSync
            );


    --! @brief Number of stored Delayed Frame
    --! - push delayed frame to buffer
    PushCnter : entity work.FixCnter
    generic map(
                gCntWidth   => LogDualis(gNoOfDelFrames),
                gStartValue => (LogDualis(gNoOfDelFrames)-1 downto 0 => '0'),
                gInitValue  => (LogDualis(gNoOfDelFrames)-1 downto 0 => '0'),
                gEndValue   => (LogDualis(gNoOfDelFrames)-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => delCntSync,
            iEn     => pushCntEn,
            oQ      => delCntPush,
            oOv     => open
            );


    --! @brief Number of loaded Delayed Frame
    --! - delayed frame was pulled from buffer
    PullCnter : entity work.FixCnter
    generic map(
                gCntWidth   => LogDualis(gNoOfDelFrames),
                gStartValue => (LogDualis(gNoOfDelFrames)-1 downto 0 => '0'),
                gInitValue  => (LogDualis(gNoOfDelFrames)-1 downto 0 => '0'),
                gEndValue   => (LogDualis(gNoOfDelFrames)-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => delCntSync,
            iEn     => delFrameLoaded_negEdge,
            oQ      => delCntPull,
            oOv     => open
            );

    noDelFrameInBuffer  <= '1' when delCntPush<=delCntPull else '0';
        --no delayed frames are inside the buffer, when NoOfPushedFrames = NoOfPulledFrames
    --------------------------------------------------------------------------------------



    --Time of delayed frames--------------------------------------------------------------

    --! @brief Counter for the time in 50MHz ticks, when task is active
    TimeCnter : entity work.FixCnter
    generic map(
                gCntWidth   => oCurrentTime'length,
                gStartValue => (oCurrentTime'length-1 downto 0 => '0'),
                gInitValue  => (oCurrentTime'length-1 downto 0 => '0'),
                gEndValue   => (oCurrentTime'length-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => iTestSync,
            iEn     => active,
            oQ      => currentTime,
            oOv     => open
            );

                                                    --"-8" for DelayData without the first byte for the states
                                                    --"downto 1" for division of 2 => 10ns to 20ns steps
    oDelayTime  <= std_logic_vector(unsigned(currentTime)+unsigned(iDelayData(gDelayDataWidth-8-1 downto 1))+1)
                when iDelayEn='1' else (others=>'0');
        --start time of the delayed frame = current time + task delay + 1 in 20ns

    oCurrentTime    <= currentTime;
    --------------------------------------------------------------------------------------



    --! @brief handling of undelayed frames
    --! - Also next value logic
    process(reg,iStart, iDelFrameLoaded, iDelayEn, passFrame, active, iDelayData, iFrameIsSoC)
    begin

        passFrame   <= '0';
        reg_next    <= reg;

        reg_next.delFrameLoaded <= iDelFrameLoaded;
        reg_next.delayFrame     <= iDelayEn and passFrame;

        if active='1' then  --if active...
                case reg.delayType is
                    when cDelayType.pass    => passFrame    <= iStart;                   --pass
                    when cDelayType.delete  => passFrame    <= '0';                      --delete all
                    when cDelayType.passSoC => passFrame    <= iStart and iFrameIsSoC;   --pass SoCs
                    when others             => passFrame    <= iStart;

                end case;

            if (iDelayEn='1' and iStart='1') then   --update of operation at enable signal
                reg_next.delayType<= iDelayData(iDelayData'left downto iDelayData'left-cByteLength+1);  --first Byte

            else
                reg_next.delayType  <= reg.delayType;

            end if;

        else                --if inactive => pass
            passFrame           <= iStart;
            reg_next.delayType  <= (others=>'0');

        end if;

    end process;

    oStartAddrStorage   <= passFrame;

end two_seg_arch;