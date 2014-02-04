-------------------------------------------------------------------------------
--! @file PacketControl_FSM.vhd
--! @brief Control of the safety packet manipulation
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


--! Entity of safety packet control
entity PacketControl_FSM is
    port(
        iClk                : in std_logic;                                 --! clk
        iReset              : in std_logic;                                 --! reset
        iSafetyTask         : in std_logic_vector(cByteLength-1 downto 0);  --! current safety task
        iTaskSafetyEn       : in std_logic;                                 --! task: safety packet manipulation
        iStopTest           : in std_logic;                                 --! abort of a series of test
        iResetPaketBuff     : in std_logic;                                 --! Resets the packet FIFO and removes the packet lag
        oPacketExchangeEn   : out std_logic;                                --! Start of the exchange of the safety packet
        oPacketExtension    : out std_logic;                                --! Exchange will be extended for several tacts
        oSafetyActive       : out std_logic;                                --! safety manipulations are active

        iNewTask            : in std_logic;     --! current manipulation task changed
        iSn2Pre             : in std_logic;     --! SN2 packet arrives before DUT packet
        iDutNoPaGap         : in std_logic;     --! there is no gap after DUT packet
        iSnNoPaGap          : in std_logic;     --! there is no gap after SN2 packet
        iExchangeData       : in std_logic;     --! exchange packet data
        iLagReached         : in std_logic;     --! reached required number of delayed packets

        iSafetyFrame        : in std_logic;     --! current frame matches to the current or last safety task
        iFrameIsSoc         : in std_logic;     --! current frame is a SoC

        iCntEnd             : in std_logic;     --! all packets were manipulated
        oCntEn              : out std_logic;    --! enable packet counter
        oCntClear           : out std_logic;    --! reset packet counter

        oStore              : out std_logic;    --! store current frame data into memory
        oRead               : out std_logic;    --! load data from current memory
        oClonePacketEx      : out std_logic;    --! exchange current packet with clone
        oZeroPacketEx       : out std_logic;    --! exchange current packet with zero pattern
        oTwistPacketEx      : out std_logic;    --! exchange packets in opposite order

        oPacketStartSoc     : out std_logic;    --! change manipulation start to SoC Timestamp
        oPacketStartPayload : out std_logic;    --! change manipulation start to safety packet payload
        oPacketStartSN2     : out std_logic     --! change manipulation start to SN2
        );
end PacketControl_FSM;


--! @brief Control of the safety packet manipulation
--! @details This module executes the different safety tasks
--! - Handles the different tasks
--! - Controls data stream and storage of data
architecture two_seg_arch of PacketControl_FSM is


    --! Typedef for states
    type tMcState is
        (
        sIdle,

        sRepetition,
        sRepetitionExchange,
        sRepetitionCloneOutput,
        sRepetitionCloneExchange,

        sPaLoss,
        sPaLossMani,

        sInsertion,
        sInsertionMani,
        sStoreSN2,

        sIncSeq,
        sIncSeqDelay,
        sIncSeqEx,
        sIncSeqAct,
        sIncTwistPack,

        sIncData,
        sIncDataMani,

        sPaDelay,
        sPaDelayMani,
        sPaDelayKill,
        sPaDelayKillMani,

        sMasquerade,
        sMasqueradeMani,
        sStoreSoC
        );


    --! Typedef for registers
    type tReg is record
        state           : tMcState;         --!State of FSM
        active          : std_logic;        --!Manipulation of safety packets are active
        safetyFrame     : std_logic;        --!register for edge detection iSafetyFrame
        exchangeData    : std_logic;        --!register for edge detection iExchangeData
        exchangeData_l2 : std_logic;        --!register for a delay of two clock cycles
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                state           => sIdle,
                                active          => '0',
                                safetyFrame     => '0',
                                exchangeData    => '0',
                                exchangeData_l2 => '0'
                                );

    signal reg          : tReg; --! Registers


    --next signals
    signal state_next       : tMcState;         --! Next state of FSM
    signal active_next      : std_logic;        --! State of FSM


    --edges
    signal safetyFrame_posEdge  : std_logic;    --!positive edge of iSafetyFrame
    signal exchangeData_negEdge : std_logic;    --!negative edge of iExchangeData

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    regs:
    process(iClk,iReset)
    begin
        if iReset = '1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg.state           <= state_next;
            reg.active          <= active_next;
            reg.exchangeData    <= iExchangeData;
            reg.exchangeData_l2 <= reg.ExchangeData;
            reg.safetyFrame     <= iSafetyFrame;

        end if;
    end process;


    --!positive edge of iExchangeData => start of Manipulation
    safetyFrame_posEdge     <= '1' when reg.safetyFrame = '0' and iSafetyFrame='1' else '0';

    --!negative edge of iExchangeData => end of Manipulation
    exchangeData_negEdge    <= '1' when reg.exchangeData = '1' and iExchangeData='0' else '0';


    --! @brief Logic of safety-active signal
    --! - Set at iTaskSafetyEn
    --! - Reset, when all frames have arrived
    --! - Reset at error or stop
    comp_active:
    process(reg, iCntEnd, iTaskSafetyEn, iStopTest)
    begin
        active_next     <= reg.active;

        if iTaskSafetyEn='1' then
            active_next <= '1';

        elsif iCntEnd='1' then
            active_next <= '0';

        end if;

        if iStopTest    = '1' then  --abort (error or manual stop)
            active_next <= '0';

        end if;

    end process;



    --! @brief Logic for FSMs next state
    --! - Execute the different tasks
    --! - Reset when new task arrives or abort of test
    comb_next:
    process(reg, iStopTest, iNewTask, iSn2Pre, iSafetyTask, iFrameIsSoc, iSafetyFrame, safetyFrame_posEdge,
            exchangeData_negEdge, iLagReached, iResetPaketBuff, active_next)
    begin

        --!FSM-logic
        if iStopTest='1' or iNewTask='1' then
            state_next<=sIdle;                  --reset at abort or new manipuation

        else
            case reg.state is
                when sIdle=>
                    case iSafetyTask is
                        when cTask.repetition=>
                            state_next  <= sRepetition;

                        when cTask.paLoss=>
                            state_next  <= sPaLoss;

                        when cTask.insertion=>
                            state_next  <= sInsertion;

                        when cTask.incSeq=>
                            state_next  <= sIncSeq;

                        when cTask.incData=>
                            state_next  <= sIncData;

                        when cTask.paDelay=>
                            state_next  <= sPaDelay;

                        when cTask.masquerade=>
                            state_next  <= sMasquerade;

                        when others=>
                            state_next  <= sIdle;

                    end case;

                -- Repetition manipulation --------------------------------------------

                --Inactive Part:

                when sRepetition=>                  --Packet repetition
                    if active_next  = '1' then      --when manipulation is active
                        state_next  <= sRepetitionCloneOutput;

                        if safetyFrame_posEdge='1' then
                            state_next  <= sRepetitionCloneExchange;

                        end if;

                    elsif safetyFrame_posEdge='1' then      --when INACTIVE...
                        state_next  <= sRepetitionExchange; --Store clone at incoming safety frame

                    else
                        state_next <= sRepetition;

                    end if;

                when sRepetitionExchange=>          --Output of (delayed) packets and storage of the clone
                    if active_next  = '1' then      --when manipulation goes to active state
                        state_next  <= sRepetitionCloneExchange;

                    elsif exchangeData_negEdge='1' then
                        state_next <= sRepetition;  --return after storage

                    else
                        state_next<=sRepetitionExchange;

                    end if;

                --Active Part:

                when sRepetitionCloneOutput=>       --Output of clone packets
                    if active_next = '0' then       --when manipulation is inactive
                        state_next  <= sRepetition;

                    elsif safetyFrame_posEdge='1' then              --when ACTIVE...
                        state_next  <= sRepetitionCloneExchange;    --Store clone at incoming safety frame

                    else
                        state_next <= sRepetitionCloneOutput;

                    end if;

                when sRepetitionCloneExchange=>     --Exchange packets with clones
                    if active_next  = '0' then      --when manipulation goes to inactive state
                        state_next  <= sRepetitionExchange;

                    elsif exchangeData_negEdge='1' then
                        state_next  <= sRepetitionCloneOutput;   --return after exchange

                    else
                        state_next  <= sRepetitionCloneExchange;

                    end if;

                -- Loss manipulation --------------------------------------------------

                when sPaLoss=>                      --packet loss
                    if safetyFrame_posEdge='1' and active_next = '1' then
                        state_next<=sPaLossMani;    --Manipulation at incoming safety frame

                    else
                        state_next<=sPaLoss;

                    end if;

                when sPaLossMani=>                  --packet loss manipulating
                    if exchangeData_negEdge='1' then
                        state_next<=sPaLoss;

                    else
                        state_next<=sPaLossMani;

                    end if;

                -- Insertion manipulation ---------------------------------------------

                when sInsertion=>                       --packet Insertion
                    if safetyFrame_posEdge='1' then     --Incoming safety frame
                        if  iSn2Pre     = '1' or        --if SN-packet comes first
                            active_next = '0' then      --or manipulation hasn't started
                            state_next<=sStoreSN2;

                        elsif active_next = '1' then    --if DUT-packet comes first + Active
                            state_next<=sInsertionMani;

                        else
                            state_next<=sInsertion;

                        end if;

                    else
                        state_next<=sInsertion;

                    end if;

                when sInsertionMani=>                  --packet Insertion starts
                    if exchangeData_negEdge='1' then
                        if iSn2Pre = '0' then          --if DUT-packet comes first
                            state_next<=sStoreSN2;

                        else
                            state_next<=sInsertion;     --cnt following delay tasks

                        end if;

                    else
                        state_next<=sInsertionMani;

                    end if;

                when sStoreSN2=>                        --collecting the packet of the second safety node
                    if exchangeData_negEdge='1' then
                        if iSn2Pre      = '1' and       --if SN-packet comes first...
                            active_next = '1' then      --... and manipulation is active
                            state_next<=sInsertionMani;

                        else
                            state_next<=sInsertion;

                        end if;

                    else
                        state_next<=sStoreSN2;

                    end if;

                -- Incorrect sequence manipulation ------------------------------------

                --Inactive Part:

                when sIncSeq=>                      --Incorrect sequence
                    if active_next  = '1' then      --when manipulation is active
                        state_next <= sIncSeqAct;

                        if safetyFrame_posEdge='1' then
                            state_next  <= sIncTwistPack;

                        end if;

                    elsif safetyFrame_posEdge='1' then      --when INACTIVE...

                        if iLagReached = '1' or iResetPaketBuff='1' then    --delayed enough packets or reset active...
                            state_next <= sIncSeqEx;            --...exchange current packet with a delayed one

                        else
                            state_next  <= sIncSeqDelay;        --...delay more packets

                        end if;

                    else
                        state_next <= sIncSeq;

                    end if;

                when sIncSeqDelay=>                 --delay packets until reaching required number
                    if active_next  = '1' then      --when manipulation goes to active state
                        state_next  <= sIncTwistPack;

                    elsif exchangeData_negEdge='1' then
                        state_next  <= sIncSeq;  --return after storage

                    else
                        state_next  <= sIncSeqDelay;

                    end if;

                when sIncSeqEx=>                    --exchange packet with delayed one
                    if active_next  = '1' then      --when manipulation goes to active state
                        state_next  <= sIncTwistPack;

                    elsif exchangeData_negEdge='1' then
                        state_next  <= sIncSeq;  --return after storage

                    else
                        state_next  <= sIncSeqEx;

                    end if;

                --Active Part:

                when sIncSeqAct=>                   --Incorrect sequence active
                    if active_next  = '0' then      --when manipulation is inactive
                        state_next <= sIncSeq;

                    elsif safetyFrame_posEdge='1' then      --when Active...
                        state_next <= sIncTwistPack;        --...exchange packets in opposite order

                    else
                        state_next <= sIncSeqAct;

                    end if;

                when sIncTwistPack=>                --exchange packets in opposite order
                    if active_next  = '0' then      --when manipulation goes to inactive state

                        if iLagReached = '1' or iResetPaketBuff='1' then    --delayed enough packets...
                            state_next <= sIncSeqEx;            --...exchange current packet with a delayed one

                        else
                            state_next  <= sIncSeqDelay;        --...delay more packets

                        end if;

                    elsif exchangeData_negEdge='1' then
                        state_next  <= sIncSeqAct;  --return after storage

                    else
                        state_next  <= sIncTwistPack;

                    end if;


                -- Incorrect data manipulation ----------------------------------------

                when sIncData=>                      --Incorrect data
                    if safetyFrame_posEdge='1' and active_next = '1' then
                        state_next  <= sIncDataMani;    --Manipulation at incoming safety frame

                    else
                        state_next  <= sIncData;

                    end if;

                when sIncDataMani=>                  --Incorrect data manipulating
                    if exchangeData_negEdge='1' then
                        state_next  <= sIncData;

                    else
                        state_next  <= sIncDataMani;

                    end if;


                -- Packet delay manipulation ------------------------------------------

                --Inactive Part:

                when sPaDelay=>                     --Packet delay
                    if active_next  = '1' then      --when manipulation is active
                        state_next  <= sPaDelayKill;

                        if safetyFrame_posEdge='1' then
                            state_next  <= sPaDelayKillMani;

                        end if;

                    elsif safetyFrame_posEdge='1' then      --when INACTIVE...
                        state_next  <= sPaDelayMani; --Exchange frame with delayed packets

                    else
                        state_next <= sPaDelay;

                    end if;

                when sPaDelayMani=>                 --Exchange frame with delayed packets
                    if active_next  = '1' then      --when manipulation goes to active state
                        state_next  <= sPaDelayKillMani;

                    elsif exchangeData_negEdge='1' then
                        state_next <= sPaDelay;     --return after storage

                    else
                        state_next<=sPaDelayMani;

                    end if;

                --Active Part:

                when sPaDelayKill=>                 --Remove packets
                    if active_next  = '0' then      --when manipulation is inactive
                        state_next  <= sPaDelay;

                    elsif safetyFrame_posEdge='1' then      --when ACTIVE...
                        state_next  <= sPaDelayKillMani;    --Remove packets

                    else
                        state_next <= sPaDelayKill;

                    end if;

                when sPaDelayKillMani=>             --Remove packets
                    if active_next  = '0' then      --when manipulation goes to inactive state
                        state_next  <= sPaDelayMani;

                    elsif exchangeData_negEdge='1' then
                        state_next <= sPaDelayKill;     --return after exchange

                    else
                        state_next<=sPaDelayKillMani;

                    end if;


                -- Masquerade manipulation --------------------------------------------

                when sMasquerade=>                      --Masquerade
                    if iFrameIsSoc='1' then
                        state_next      <= sStoreSoC;   --store incoming SoCs

                    elsif safetyFrame_posEdge='1' and active_next = '1' then
                        state_next  <= sMasqueradeMani; --Manipulation at incoming safety frame

                    else
                        state_next  <= sMasquerade;

                    end if;

                when sMasqueradeMani=>                  --Masquerade manipulating
                    if exchangeData_negEdge='1' then
                        state_next  <= sMasquerade;

                    else
                        state_next  <= sMasqueradeMani;

                    end if;

                when sStoreSoC=>                    --Masquerade storing SoC time
                    if iFrameIsSoc='0' then
                        state_next  <= sMasquerade; --go back to the last state

                    else
                        state_next  <= sStoreSoC;

                    end if;

                when others=>
                    state_next<= sIdle;

            end case;
        end if;
    end process;




    --! @brief Moore output of FSM
    --! - Starts Exchanges of packets
    --! - Enables safety frame counter
    --! - Control the data stream and packet storage
    process(reg, state_next, iExchangeData, iDutNoPaGap, iSnNoPaGap, iLagReached)
    begin

        oPacketExchangeEn   <= '0';
        oPacketExtension    <= '0';
        oCntEn              <= '0';

        oStore              <= '0';
        oRead               <= '0';

        oPacketStartSoc     <= '0';
        oPacketStartPayload <= '0';
        oPacketStartSN2     <= '0';

        oClonePacketEx      <= '0';
        oZeroPacketEx       <= '0';
        oTwistPacketEx      <= '0';

        --active signals
        oSafetyActive       <= reg.Active;
        oCntClear           <= not reg.Active;  --reset of packet cnter


        case reg.state is
            when sIdle=>

            -- Repetition manipulation --------------------------------------------
            when sRepetition=>

            when sRepetitionExchange=>
                oPacketExchangeEn   <= '1'; --packet change enabled

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                --No Counting at end, because it is an inactive part

            when sRepetitionCloneOutput=>
                oClonePacketEx      <= '1'; --exchange current packet with clone

            when sRepetitionCloneExchange=>
                oPacketExchangeEn   <= '1'; --packet change enabled
                oClonePacketEx      <= '1'; --exchange current packet with clone

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                if state_next = sRepetitionCloneOutput then
                        oCntEn          <= '1'; --Counting at manipulation end

                    end if;

            -- Loss manipulation --------------------------------------------------
            when sPaLoss=>          --packet loss

            when sPaLossMani=>      --packet loss manipulating
                oPacketExchangeEn   <= '1'; --packet change enabled

                if state_next = sPaLoss then
                    oCntEn          <= '1'; --Counting at manipulation end

                end if;


            -- Insertion manipulation ---------------------------------------------
            when sInsertion=>       --Masquerade

            when sInsertionMani=>   --packet loss manipulating
                oPacketExchangeEn   <= '1'; --packet change enabled
                oRead               <= iExchangeData;

                if state_next = sInsertion then
                    oCntEn          <= '1'; --Counting at manipulation end

                end if;

            when sStoreSN2=>       --Store the SoC Timestamp
                oPacketExchangeEn   <= '1'; --packet change enabled
                oPacketStartSN2     <= '1'; --Selecting SN2
                oStore              <= iExchangeData;

                if state_next = sInsertion then
                    oCntEn          <= '1'; --Counting at manipulation end

                end if;


            -- Incorrect sequence manipulation ------------------------------------
            when sIncSeq=>
                if iLagReached = '0' then
                    oZeroPacketEx       <= '1'; --exchange current packet with zeros

                end if;

            when sIncSeqDelay=> --delay packets
                oPacketExchangeEn   <= '1'; --packet change enabled
                oZeroPacketEx       <= '1'; --exchange current packet with zeros

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                --No Counting at end, because it is an inactive part

            when sIncSeqEx=>    --exchange packets with delayed ones
                oPacketExchangeEn   <= '1'; --packet change enabled

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                --No Counting at end, because it is an inactive part

            when sIncSeqAct=>
                oTwistPacketEx      <= '1'; --exchange packets in opposite order

            when sIncTwistPack=>
                oPacketExchangeEn   <= '1'; --packet change enabled
                oTwistPacketEx      <= '1'; --exchange packets in opposite order

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                if state_next = sIncSeqAct then
                        oCntEn          <= '1'; --Counting at manipulation end

                    end if;

            -- Incorrect data manipulation ----------------------------------------
            when sIncData=>          --Incorrect data
                oPacketStartPayload <= '1'; --Manipulation of safety payload

            when sIncDataMani=>      --Incorrect data manipulating
                oPacketExchangeEn   <= '1'; --packet change enabled
                oPacketStartPayload <= '1'; --Manipulation of safety payload

                if state_next = sIncData then
                    oCntEn          <= '1'; --Counting at manipulation end

                end if;


            -- Packet delay manipulation ------------------------------------------
            when sPaDelay=>

            when sPaDelayMani=>
                oPacketExchangeEn   <= '1'; --packet change enabled

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                --No Counting at end, because it is an inactive part

            when sPaDelayKill=>
                oZeroPacketEx       <= '1'; --exchange current packet with zeros

            when sPaDelayKillMani=>
                oPacketExchangeEn   <= '1'; --packet change enabled
                oZeroPacketEx       <= '1'; --exchange current packet with zeros

                --exchange Packet
                oStore              <= iExchangeData;
                oRead               <= iExchangeData;

                if state_next = sPaDelayKill then
                        oCntEn          <= '1'; --Counting at manipulation end

                    end if;


            -- Masquerade manipulation --------------------------------------------
            when sMasquerade=>          --Masquerade

            when sMasqueradeMani=>      --Masquerade manipulating

                oPacketExchangeEn   <= '1'; --packet change enabled
                oRead               <= iExchangeData;

                if state_next = sMasquerade then
                    oCntEn          <= '1'; --Counting at manipulation end

                end if;

            when sStoreSoC=>       --Store the SoC Timestamp
                oPacketExchangeEn   <= '1'; --packet change enabled
                oPacketStartSoc     <= '1'; --Selecting SoC
                oStore              <= iExchangeData;

            when others =>

        end case;


        --Extension logic

        if  iExchangeData       = '0' and
            reg.ExchangeData_l2 = '1' then          --only for two clock cycles after iExchangeData

            if      state_next  = sInsertionMani then   --only at packet insertion
                if  iDutNoPaGap = '1' then              --only when there is no gap after DUT packet
                    oPacketExtension    <= '1';
                    oRead               <= '1';

                end if;
             end if;


            if      state_next  = sStoreSN2 then        --only at packet insertion
                if iSnNoPaGap = '1' then                --only when there is no gap after DUT packet
                    oPacketExtension    <= '1';
                    oStore               <= '1';

                end if;

            end if;
        end if;


    end process;

end two_seg_arch;
