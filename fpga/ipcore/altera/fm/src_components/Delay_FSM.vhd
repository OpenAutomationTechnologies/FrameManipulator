-------------------------------------------------------------------------------
--! @file Delay_FSM.vhd
--! @brief FSM for the Delay_Handler
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


--! This is the entity of the FSM for the Delay_Handler
entity Delay_FSM is
    port(
        iClk                : in std_logic;     --! clk
        iReset              : in std_logic;     --! reset
        --series of test signals
        iTestSync           : in std_logic;     --! reset: new series of test
        iTestStop           : in std_logic;     --! abort of series of test TODO include this signal
        --delay signals
        iDelayEn            : in std_logic;     --! task: delay frame
        iNoDelFrameInBuffer : in std_logic;     --! There are no frames in the fifo, which should be delayed
        oActive             : out std_logic;    --! delay-task is active => Timeline is counting
        oPushCntEn          : out std_logic;    --! a new frame is stored => push counter +1
        oDelCntSync         : out std_logic     --! reset: end of delay => reset of push and pull cnter
    );
end Delay_FSM;


--! @brief Delay_FSM architecture
--! @details FSM for the Delay_Handler
--! - It cnts up the push-cnter at receiving a new delay-task and switches to "active".
--!   It stays in active mode, until all delayed frames has left the buffer.
architecture two_seg_arch of Delay_FSM is

    --! states
    type tMcState is (
            sIdle,      --! waiting for the first task
            sCnt_up,    --! counts up the push-cnter => new delayed frame enters the buffer
            sActive,    --! delay processes are active + waiting for the next task
            sInactive   --! inactive, waiting for the next task
            );

    signal state_reg    : tMcState; --! Current state
    signal state_next   : tMcState; --! Next state

begin

    --register

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            state_reg   <= sIdle;

        elsif rising_edge(iClk) then
            state_reg   <= state_next;

        end if;
    end process;


    --! @brief next state logic
    process(state_reg,iDelayEn,iTestSync,iNoDelFrameInBuffer)
    begin
        if iTestSync='1' then
            state_next<=sIdle;                      --reset at sync

        else
            case state_reg is
                when sIdle=>
                    if iDelayEn='1'  then
                        state_next  <= sCnt_up;     --start/cnt of task with enable

                    else
                        state_next  <= sIdle;

                    end if;

                when sCnt_up=>
                    state_next  <= sActive;         --goto wait until task ends

                when sActive=>
                    if iDelayEn='1' then
                        state_next  <= sCnt_up;     --cnt following delay tasks

                    elsif iNoDelFrameInBuffer='1' then
                        state_next  <= sInactive;   --goto inactive, when there are no delayed frames in the buffer

                    else
                        state_next  <= sActive;
                    end if;

                when sInactive=>
                    if iDelayEn='1' then
                        state_next  <= sCnt_up;     --cnt new delayed frames

                    else
                        state_next  <= sInactive;

                    end if;

            end case;
        end if;
    end process;

    --! @brief Moore output
    process(state_reg)
    begin

        oActive     <='0';
        oPushCntEn  <='0';
        oDelCntSync <='0';

        case state_reg is
            when sIdle=>
                oDelCntSync <= '1'; --reset of delayed-frame-cnter

            when sCnt_up=>
                oActive     <= '1'; --Timeline/delaying is active
                oPushCntEn  <= '1'; --counts a new received delayed frame

            when sActive=>
                oActive     <= '1'; --Timeline/delaying is active

            when sInactive=>
                oDelCntSync <= '1'; --reset of delayed-frame-cnter

        end case;

    end process;


end two_seg_arch;