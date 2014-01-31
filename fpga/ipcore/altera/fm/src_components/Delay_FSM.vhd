
-- ******************************************************************************************
-- *                                    Delay_FSM                                           *
-- ******************************************************************************************
-- *                                                                                        *
-- * FSM for the Delay-Handler. It cnts up the push-cnter at receiving a new delay-task and *
-- * switches to "active". It stays in active mode, until all delayed frames has left the   *
-- * buffer.                                                                                *
-- *                                                                                        *
-- * States:                                                                                *
-- *    sIdle:      waiting for the first task                                              *
-- *    sCnt_up:    counts up the push-cnter => new delayed frame enters the buffer         *
-- *    sActive:    delay processes are active + waiting for the next task                  *
-- *    sInactive:  inactive, waiting for the next task                                     *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Delay_FSM                               by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Delay_FSM is
        port(
            clk, reset:             in std_logic;
            --series of test signals
            iTestSync:              in std_logic;   --reset: new series of test
            iTestStop:              in std_logic;   --abort of series of test
            --delay signals
            iDelayEn:               in std_logic;   --task: delay frame
            iNoDelFrameInBuffer:    in std_logic;   --There are no frames in the fifo, which should be delayed
            oActive:                out std_logic;  --delay-task is active => Timeline is counting
            oPushCntEn:             out std_logic;  --a new frame is stored => push counter +1
            oDelCntSync:            out std_logic   --reset: end of delay => reset of push and pull cnter
        );
end Delay_FSM;


architecture two_seg_arch of Delay_FSM is

    --states
    type mc_state_type is
        (sIdle,sCnt_up,sActive,sInactive);

    signal state_reg:   mc_state_type;
    signal state_next:  mc_state_type;


begin

    --register

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            state_reg   <= sIdle;

        elsif rising_edge(clk) then
            state_reg   <= state_next;

        end if;
    end process;


    --next state logic
    process(state_reg,iDelayEn,iTestSync,iNoDelFrameInBuffer)
    begin
        if iTestSync='1' then
            state_next<=sIdle;                  --reset at sync

        else
            case state_reg is
                when sIdle=>
                    if iDelayEn='1'  then
                        state_next<=sCnt_up;    --start/cnt of task with enable

                    else
                        state_next<=sIdle;

                    end if;

                when sCnt_up=>
                    state_next<=sActive;            --goto wait until task ends

                when sActive=>
                    if iDelayEn='1' then
                        state_next<=sCnt_up;        --cnt following delay tasks

                    elsif iNoDelFrameInBuffer='1' then
                        state_next<=sInactive;  --goto inactive, when there are no delayed frames in the buffer

                    else
                        state_next<=sActive;
                    end if;

                when sInactive=>
                    if iDelayEn='1' then
                        state_next<=sCnt_up;        --cnt new delayed frames

                    else
                        state_next<=sInactive;

                    end if;

                when others=>
                    state_next<= sIdle;

            end case;
        end if;
    end process;

    --Moore output
    process(state_reg)
    begin

    oActive     <='0';
    oPushCntEn  <='0';
    oDelCntSync <='0';

    case state_reg is
        when sIdle=>
            oDelCntSync<='1';   --reset of delayed-frame-cnter

        when sCnt_up=>
            oActive<='1';       --Timeline/delaying is active
            oPushCntEn<='1';    --counts a new received delayed frame

        when sActive=>
            oActive<='1';       --Timeline/delaying is active

        when sInactive=>
            oDelCntSync<='1';   --reset of delayed-frame-cnter

        when others =>

    end case;

    end process;



end two_seg_arch;