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
--! use global library
use work.global.all;
--! use fm library
use work.framemanipulatorPkg.all;


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
    constant cSize_Time : natural:=gDelayDataWidth-8+1;

    --signals
    signal passFrame    : std_logic;    --!Frame is processed (not dropped)

    --register of delay-operation
    signal reg_delayType        : std_logic_vector(cByteLength-1 downto 0); --! Register of delay type
    signal next_delayType       : std_logic_vector(cByteLength-1 downto 0); --! Next value of delay type

    --signal for FSM
    signal active               : std_logic;    --! delay is active
    signal noDelFrameInBuffer   : std_logic;    --! all delayed frames has left the buffer

    --Counter for Stored and loaded Delayed Frames
    signal delCntSync   : std_logic;                                              --! reset cnter
    signal pushCntEn    : std_logic;                                              --! Cnt up number of delayed frames
    signal delCntPush   : std_logic_vector(LogDualis(gNoOfDelFrames)-1 downto 0); --! Number of "pushed" delayed frames to the buffer
    signal delCntPull   : std_logic_vector(LogDualis(gNoOfDelFrames)-1 downto 0); --! Number of "pulled" delayed frames to the buffer

    --negative edge detection of outgoing delayed-frames
    signal reg_delFrameLoaded   : std_logic;    --! Register for edge detection of iDelFrameLoaded
    signal nEdge_delFrameLoaded : std_logic;    --! Negatice edge of iDelFrameLoaded

    --edge detection of task enable
    signal reg_delayFrame       : std_logic;    --! Register for edge detection of iDelayEn
    signal edge_delayFrame      : std_logic;    --! Positive edge detection

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
            reg_delFrameLoaded  <= '0';
            reg_delayFrame      <= '0';
            reg_delayType       <= (others=>'0');

        elsif rising_edge(iClk) then
            reg_delFrameLoaded  <= iDelFrameLoaded;
            reg_delayFrame      <= iDelayEn and PassFrame;
            reg_delayType       <= next_delayType;

        end if;
    end process;


    nEdge_delFrameLoaded    <= '1' when iDelFrameLoaded='0' and reg_delFrameLoaded='1' else '0';
            --Counting on the negativ Edge => Frame was already loaded

    edge_delayFrame <= '1' when (iDelayEn='1' and passFrame='1') and reg_delayFrame='0' else '0';
    --------------------------------------------------------------------------------------



    --Counting of delayed-frames ----------------------------------------------------------

    --! @brief Delay FSM
    --! - provides active-task signal, cnts the push-cnter up and resets the frame-cnter
    FSM : entity work.Delay_FSM
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iDelayEn            => edge_DelayFrame,
            iTestSync           => iTestSync,
            iTestStop           => iTestStop,
            iNoDelFrameInBuffer => noDelFrameInBuffer,
            oActive             => active,
            oPushCntEn          => pushCntEn,
            oDelCntSync         => delCntSync
            );


    --! @brief Number of stored Delayed Frame
    --! - push delayed frame to buffer
    PushCnter : entity work.Basic_Cnter
    generic map(gCntWidth   => LogDualis(gNoOfDelFrames))
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => delCntSync,
            iEn         => pushCntEn,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => delCntPush,
            oOv         => open
            );


    --! @brief Number of loaded Delayed Frame
    --! - delayed frame was pulled from buffer
    PullCnter : entity work.Basic_Cnter
    generic map(gCntWidth   => LogDualis(gNoOfDelFrames))
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => delCntSync,
            iEn         => nEdge_DelFrameLoaded,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => delCntPull,
            oOv         => open
            );

    noDelFrameInBuffer  <= '1' when delCntPush<=delCntPull else '0';
        --no delayed frames are inside the buffer, when NoOfPushedFrames = NoOfPulledFrames
    --------------------------------------------------------------------------------------



    --Time of delayed frames--------------------------------------------------------------

    --! @brief Counter for the time in 50MHz ticks, when task is active
    TimeCnter : entity work.Basic_Cnter
    generic map(gCntWidth   => oCurrentTime'length)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => iTestSync,
            iEn         => active,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => currentTime,
            oOv         => open
            );

                                                    --"-8" for DelayData without the first byte for the states
                                                    --"downto 1" for division of 2 => 10ns to 20ns steps
    oDelayTime  <= std_logic_vector(unsigned(currentTime)+unsigned(iDelayData(gDelayDataWidth-8-1 downto 1))+1)
                when iDelayEn='1' else (others=>'0');
        --start time of the delayed frame = current time + task delay + 1 in 20ns

    oCurrentTime    <= currentTime;
    --------------------------------------------------------------------------------------



    --! @brief handling of undelayed frames
    process(Reg_DelayType,iStart)     --not on change of the active-signal TODO
    begin

        passFrame<='0';

        if active='1' then  --if active...
                case reg_delayType is
                    when cDelayType.pass    => passFrame    <= iStart;                   --pass
                    when cDelayType.delete  => passFrame    <= '0';                      --delete all
                    when cDelayType.passSoC => passFrame    <= iStart and iFrameIsSoC;   --pass SoCs
                    when others             => passFrame    <= iStart;

                end case;

            if (iDelayEn='1' and iStart='1') then   --update of operation at enable signal
                next_DelayType<= iDelayData(iDelayData'left downto iDelayData'left-cByteLength+1);  --first Byte

            else
                next_DelayType  <= reg_DelayType;

            end if;

        else                --if inactive => pass
            passFrame       <= iStart;
            next_DelayType  <= (others=>'0');

        end if;

    end process;

    oStartAddrStorage   <= passFrame;

end two_seg_arch;