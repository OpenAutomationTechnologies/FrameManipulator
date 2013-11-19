
-- ******************************************************************************************
-- *                                Delay_Handler                                           *
-- ******************************************************************************************
-- *                                                                                        *
-- * Handles the delay task of the frames. It provides the current time after the first task*
-- * and the timestamp of the outgoing frames. It also droppes the other incoming frames    *
-- * depending on the delay-operation-byte.                                                 *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Delay_Handler                           by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Delay_Handler is
    generic(
            gDelayDataWidth:    natural:=48;
            gNoOfDelFrames:     natural:=255
    );
    port(
        clk, reset:         in std_logic;
        --control signals
        iStart:             in std_logic;   --start delay process
        iFrameIsSoC:        in std_logic;   --current frame is a SoC
        iTestSync:          in std_logic;   --reset: a new test has started
        iTestStop:          in std_logic;   --abort of test series
        oStartAddrStorage:  out std_logic;  --start storage of the frame-data positions
        --delay variables
        iDelayEn:           in std_logic;                                       --task: delay enable
        iDelayData:         in std_logic_vector(gDelayDataWidth-1 downto 0);    --delay data
        iDelFrameLoaded:    in std_logic;                                       --a deleted frame was loaded from the address-fifo
        oCurrentTime:       out std_logic_vector(gDelayDataWidth-8 downto 0);   --timeline which starts with the first delayed frame
        oDelayTime:         out std_logic_vector(gDelayDataWidth-8 downto 0)    --start time of the stored frame
     );                                        --size=gDelayDataWidth-stateByte+1 bit to prevent overflow
end Delay_Handler;

architecture two_seg_arch of Delay_Handler is

    --function of the logarithm to the base of 2
    function log2c(n:natural) return natural is
        variable m, p: natural;
    begin
        m:=0;
        p:=1;
        while p<n loop
            m:=m+1;
            p:=p*2;
        end loop;
        return m;
    end log2c;

    --FSM for the Delay-Handler
    --Handles the different cnters and the current state of the component
    component Delay_FSM
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
    end component;


    --cnter for received-, created-delayed-frames and the timeline
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
          clk, reset:   in std_logic;
          iClear:       in std_logic;
          iEn   :       in std_logic;
          iStartValue:  in std_logic_vector(gCntWidth-1 downto 0);
          iEndValue:    in std_logic_vector(gCntWidth-1 downto 0);
          oQ:           out std_logic_vector(gCntWidth-1 downto 0);
          oOv:          out std_logic
        );
    end component;

    --constants
    --width of the time-variables: DelaySettings -1Byte for operation +1Bit toprevent overflow
    constant cSize_Time: natural:=gDelayDataWidth-8+1;

    --Values of the 3rd Task Byte: delay-operation (procession of other frames, while delay)
    constant cDelay_pass:       std_logic_vector(7 downto 0):=X"01";    --pass all
    constant cDelay_delete:     std_logic_vector(7 downto 0):=X"02";    --deleat all
    constant cDelay_passSoC:    std_logic_vector(7 downto 0):=X"04";    --pass only SoCs


    --signals
    signal PassFrame:   std_logic;  --Frame is processed (not dropped)

    --register of delay-operation
    signal Reg_OtherFrameOperation: std_logic_vector(7 downto 0);
    signal Next_OtherFrameOperation:std_logic_vector(7 downto 0);

    --signal for FSM
    signal active:              std_logic;  --delay is active
    signal NoDelFrameInBuffer:  std_logic;  --all delayed frames has left the buffer

    --Counter for Stored and loaded Delayed Frames
    signal DelCntSync:  std_logic;                                          --reset cnter
    signal PushCntEn:   std_logic;
    signal DelCntPush:  std_logic_vector(log2c(gNoOfDelFrames)-1 downto 0); --Number of "pushed" delayed frames to the buffer
    signal DelCntPull:  std_logic_vector(log2c(gNoOfDelFrames)-1 downto 0); --Number of "pulled" delayed frames to the buffer

    --negative edge detection of outgoing delayed-frames
    signal Reg_DelFrameLoaded   :std_logic;
    signal nEdge_DelFrameLoaded :std_logic;

    --edge detection of task enable
    signal Reg_DelayFrame   :std_logic;
    signal Edge_DelayFrame  :std_logic;

    --current time in 50MHz ticks
    signal CurrentTime: std_logic_vector(cSize_Time-1 downto 0);

begin

    --edge detections----------------------------------------------------------------------
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                Reg_DelFrameLoaded      <='0';
                Reg_DelayFrame              <='0';
                Reg_OtherFrameOperation <=(others=>'0');

            else
                Reg_DelFrameLoaded      <=iDelFrameLoaded;
                Reg_DelayFrame          <=iDelayEn and PassFrame;
                Reg_OtherFrameOperation <=Next_OtherFrameOperation;

            end if;
        end if;
    end process;

    nEdge_DelFrameLoaded<= '1' when iDelFrameLoaded='0' and Reg_DelFrameLoaded='1' else '0';
            --Counting on the negativ Edge => Frame was already loaded

    Edge_DelayFrame<= '1' when (iDelayEn='1' and PassFrame='1') and Reg_DelayFrame='0' else '0';
    --------------------------------------------------------------------------------------



    --Counting of delayed-frames ----------------------------------------------------------

    --Delay FSM
    --provides active-task signal, cnts the push-cnter up and resets the frame-cnter
    FSM:Delay_FSM
    port map(
        clk=>clk, reset=>reset,
        iDelayEn=>Edge_DelayFrame,  iTestSync=>iTestSync,   iTestStop=>iTestStop,
        iNoDelFrameInBuffer=>       NoDelFrameInBuffer,
        oActive=>active,            oPushCntEn=>PushCntEn,  oDelCntSync=>DelCntSync);


    --Number of stored Delayed Frame
    PushCnter:Basic_Cnter   --push delayed frame to buffer
    generic map(gCntWidth=>log2c(gNoOfDelFrames))
    port map(
            clk=>clk,           reset=>reset,
            iClear=>DelCntSync, iEn=>PushCntEn, iStartValue=>(others=>'0'), iEndValue=>(others=>'1'),
            oQ=>DelCntPush,     oOv=>open);


    --Number of loaded Delayed Frame
    PullCnter:Basic_Cnter   --delayed frame was pulled from buffer
    generic map(gCntWidth=>log2c(gNoOfDelFrames))
    port map(
            clk=>clk,           reset=>reset,
            iClear=>DelCntSync, iEn=>nEdge_DelFrameLoaded,  iStartValue=>(others=>'0'), iEndValue=>(others=>'1'),
            oQ=>DelCntPull,     oOv=>open);

    NoDelFrameInBuffer<='1' when DelCntPush<=DelCntPull else '0';
        --no delayed frames are inside the buffer, when NoOfPushedFrames = NoOfPulledFrames
    --------------------------------------------------------------------------------------



    --Time of delayed frames--------------------------------------------------------------

    --Counter for the time in 50MHz ticks, when task is active
    TimeCnter:Basic_Cnter
    generic map(gCntWidth=>oCurrentTime'length)
    port map(
            clk=>clk,           reset=>reset,
            iClear=>iTestSync,  iEn=>active,    iStartValue=>(others=>'0'), iEndValue=>(others=>'1'),
            oQ=>CurrentTime,    oOv=>open);

                                                    --"-8" for DelayData without the first byte for the states
                                                    --"downto 1" for division of 2 => 10ns to 20ns steps
    oDelayTime<=std_logic_vector(unsigned(CurrentTime)+unsigned(iDelayData(gDelayDataWidth-8-1 downto 1))+1)
                when iDelayEn='1' else (others=>'0');
        --start time of the delayed frame = current time + task delay + 1 in 20ns

    oCurrentTime<=CurrentTime;
    --------------------------------------------------------------------------------------



    --handling of undelayed frames--------------------------------------------------------
    process(Reg_OtherFrameOperation,iStart)     --not on change of the active-signal
    begin

        PassFrame<='0';

        if active='1' then  --if active...
                case Reg_OtherFrameOperation is
                    when cDelay_pass    => PassFrame<=iStart;                   --pass
                    when cDelay_delete  => PassFrame<='0';                      --delete all
                    when cDelay_passSoC => PassFrame<=iStart and iFrameIsSoC;   --pass SoCs
                    when others         => PassFrame<=iStart;

                end case;

            if (iDelayEn='1' and iStart='1') then   --update of operation at enable signal
                Next_OtherFrameOperation<= iDelayData(iDelayData'left downto iDelayData'left-7);    --first Byte

            else
                Next_OtherFrameOperation<=Reg_OtherFrameOperation;

            end if;

        else                --if inactive => pass
            PassFrame<=iStart;
            Next_OtherFrameOperation<=(others=>'0');

        end if;

    end process;

    oStartAddrStorage<=PassFrame;

end two_seg_arch;