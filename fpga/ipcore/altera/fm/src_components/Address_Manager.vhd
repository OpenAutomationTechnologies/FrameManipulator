
-- ******************************************************************************************
-- *                                Address_Manager                                         *
-- ******************************************************************************************
-- *                                                                                        *
-- * The Address_Manager handels the start-address of the Frame_Receiver. Invalid and       *
-- * dropped frames are overwritten by the next frame. The accepted ones start after the    *
-- * last end-address.                                                                      *
-- * The delay-task is also processed here. A delayed frame receives a timestamp and get    *
-- * stored with it. Once it is loaded, the Address_Manager waits until it has passed this  *
-- * point of time.                                                                         *
-- * The loaded addresses are then stored and passed on to the Frame_Creator with the CRC-  *
-- * distortion flag (which is stored with the end-address).                                *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Address_Manager                         by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Address_Manager is
    generic(
            gAddrDataWidth:     natural:=11;
            gDelayDataWidth:    natural:=48;
            gNoOfDelFrames:     natural:=8
    );
    port(
        clk, reset:         in std_logic;
        --control signals
        iStartFrameStorage: in std_logic;   --frame position can be stored
        iFrameEnd:          in std_logic;   --frame reached its end => endaddress is valid
        iFrameIsSoC:        in std_logic;   --current frame is a SoC
        iTestSync:          in std_logic;   --sync: Test started
        iTestStop:          in std_logic;   --Test abort
        iNextFrame:         in std_logic;   --frame_creator is ready for new data
        oStartNewFrame:     out std_logic;  --new frame data is vaild
        --manipulations
        iDelaySetting:      in std_logic_vector(gDelayDataWidth-1 downto 0);    --setting for delaying frames
        iTaskDelayEn:       in std_logic;                                       --task: delay frames
        iTaskCrcEn:         in std_logic;                                       --task: distort crc ready to be stored
        oDistCrcEn:         out std_logic;                                      --task: new frame receives a distorted crc
        --memory management
        iDataInEndAddr:     in std_logic_vector(gAddrDataWidth-1 downto 0);     --end position of current frame
        oDataInStartAddr:   out std_logic_vector(gAddrDataWidth-1 downto 0);    --start position of next incoming frame
        oDataOutStartAddr:  out std_logic_vector(gAddrDataWidth-1 downto 0);    --start position of next created frame
        oDataOutEndAddr:    out std_logic_vector(gAddrDataWidth-1 downto 0);    --end position of next created frame
        oError_Addr_Buff_OV:out std_logic                                       --error: address-buffer-overflow
    );
end Address_Manager;

architecture two_seg_arch of Address_Manager is


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


    --component for handling the delay-frame task
    component Delay_Handler
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
        );                                         --size=gDelayDataWidth-stateByte+1 bit to prevent overflow
    end component;


    --FSM for storing the frame-data-position
    component StoreAddress_FSM
        generic(
                gAddrDataWidth: natural:=11;
                gSize_Time:     natural:=40;
                gFiFoBitWidth:  natural:=52
        );
        port(
            clk, reset:         in std_logic;
            --control signals
            iStartStorage:      in std_logic;                                   --start storing positions
            iFrameEnd:          in std_logic;                                   --end position is valid
            iDataInEndAddr:     in std_logic_vector(gAddrDataWidth-1 downto 0); --end position of the current frame
            oDataInStartAddr:   out std_logic_vector(gAddrDataWidth-1 downto 0);--new start position of the next frame
            --tasks
            iCRCManEn:          in std_logic;                                   --task: crc distortion
            iDelayTime:         in std_logic_vector(gSize_Time-1 downto 0);     --delay timestamp
            --storing data
            oWr:                out std_logic;                                  --write Fifo
            oFiFoData :         out std_logic_vector(gFiFoBitWidth-1 downto 0)  --Fifo data
        );
    end component;


    --Fifo for address-data
    component FiFo_top
        generic(
            B:natural:=8;       --number of Bits
            W:natural:=8;       --number of address bits
            Cnt_Mode:natural:=0 --binary or LFSR(not included)
        );
        port(
            clk, reset: in std_logic;
            iRd:        in std_logic;
            iWr:        in std_logic;
            iWrData:    in std_logic_vector(B-1 downto 0);
            oFull:      out std_logic;
            oEmpty:     out std_logic;
            oRdData:    out std_logic_vector(B-1 downto 0)
        );
    end component;


    --FSM for reading Fifo an storing the data positions of new frames
    component ReadAddress_FSM
        generic(
                gAddrDataWidth:natural:=11;
                gBuffBitWidth:natural:=16
        );
        port(
            clk, reset:     in std_logic;
            --control signals
            iNextFrame:     in std_logic;   --frame-creator is ready for new data
            iDataReady:     in std_logic;   --has to wait for new data
            oStart:         out std_logic;  --start new frame
            --fifo signals
            oRd:            out std_logic;                                  --read fifo
            iFifoData:      in std_logic_vector(gBuffBitWidth-1 downto 0);  --fifo data
            --new frame positions
            oDataOutStart:  out std_logic_vector(gAddrDataWidth-1 downto 0);--start position of new frame
            oDataOutEnd:    out std_logic_vector(gAddrDataWidth-1 downto 0) --end position of new frame
        );
    end component;

    --constants
    constant cSize_Time: natural:=gDelayDataWidth-8+1;  -- +1 in case of overflow

    --Fifo address and word width
    constant cBuffAddrWidth:natural:=log2c((2**gAddrDataWidth)/60*2);   -- => every frame uses two entries of the fifo
    constant cBuffWordWidth:natural:=gAddrDataWidth+cSize_Time;


    signal StartAddrStorage:std_logic;  --start address storage of the current frame

    signal DelayTime:       std_logic_vector(cSize_Time-1 downto 0);    --delay timestamp for the incoming frame

    --received fifo data
    signal AddrOutData:     std_logic_vector(gAddrDataWidth-1 downto 0);--address for new frame
    signal FrameTimestamp:  std_logic_vector(cSize_Time-1 downto 0);    --frame timestamp
    signal CurrentTime:     std_logic_vector(cSize_Time-1 downto 0);    --current time
    signal DelFrameLoaded:  std_logic;                                  --a delayed frame was loaded

    --Fifo signals
    signal FifoWr:          std_logic;  --write data
    signal FifoRd:          std_logic;  --read data
    signal FifoFull:        std_logic;  --fifo overflow
    signal FifoEmpty:       std_logic;  --fifo empty
    signal FifoDataReady:   std_logic;  --fifo data is ready

    --fifo data
    signal WrFifoData:      std_logic_vector(cBuffWordWidth-1 downto 0);--data in
    signal RdFifoData:      std_logic_vector(cBuffWordWidth-1 downto 0);--data out


begin

    --FRAME STORING---------------------------------------------------------------------------

    --delay task handler
    --generates delay timestamp for incoming frames
    DelHan:Delay_Handler
    generic map(gDelayDataWidth =>gDelayDataWidth,
                gNoOfDelFrames  =>gNoOfDelFrames)
    port map(
            clk=>clk,reset=>reset,
            iStart=>iStartFrameStorage,         iFrameIsSoC=>iFrameIsSoC,   iDelayEn=>iTaskDelayEn,
            iTestSync=>iTestSync,               iTestStop=>iTestStop,       iDelayData=>iDelaySetting,
            iDelFrameLoaded=>DelFrameLoaded,
            oStartAddrStorage=>StartAddrStorage,oCurrentTime=>CurrentTime,  oDelayTime=>DelayTime);

    --address storer
    --stores start and end address with delay timestamp and crc distortion flag
    Addr_in:StoreAddress_FSM
    generic map(
            gAddrDataWidth=>gAddrDataWidth,
            gSize_Time=>cSize_Time,
            gFiFoBitWidth=>cBuffWordWidth)
    port map(
            clk=>clk, reset=>reset,
            iStartStorage=>StartAddrStorage,        iFrameEnd=>iFrameEnd,   iCRCManEn=>iTaskCrcEn,
            iDataInEndAddr=>iDataInEndAddr,         iDelayTime=>DelayTime,
            oDataInStartAddr=>oDataInStartAddr,     oWr=>FifoWr,            oFiFoData=>WrFifoData
            );
    ------------------------------------------------------------------------------------------




    --FIFO------------------------------------------------------------------------------------

    --Fifo for frame address and timestamp/crc
    FiFo:FiFo_top
    generic map(B=>cBuffWordWidth,W=>cBuffAddrWidth,Cnt_Mode=>1)
    port map(
            clk=>clk,       reset=>reset,
            iRd=>FifoRd,    iWr=>FifoWr,        iWrData=>WrFifoData,
            oFull=>FifoFull,oEmpty=>FifoEmpty,  oRdData=>RdFifoData);

    --address-buffer-overflow, when Fifo=full+write
    oError_Addr_Buff_OV<='1' when FifoWr='1' and FifoFull='1' else '0';
    ------------------------------------------------------------------------------------------




    --DATA-SPLIT OFF--------------------------------------------------------------------------

    --first bits => Timestamp                           iNextFrame='1' appears only at reading the start address
    FrameTimestamp<=    RdFifoData(RdFifoData'left downto gAddrDataWidth) when iNextFrame='1'
                        and iTestStop='0' else (others=>'0');

    --CRC flag                                          iNextFrame='0' appears only at reading the end address
    oDistCrcEn<=    RdFifoData(gAddrDataWidth)  when iNextFrame='0' else '0';

    --last bits => address-data
    AddrOutData<=   RdFifoData(gAddrDataWidth-1 downto 0);
    ------------------------------------------------------------------------------------------




    --DELAYING FRAME--------------------------------------------------------------------------

    --Timestamp isn't zero => a delayed frame was loaded => pull counter +1
    DelFrameLoaded<='1' when FrameTimestamp/=(FrameTimestamp'range=>'0') else '0';

    --data is ready, when data is available and timestamp has been reached
    FifoDataReady<= not FifoEmpty when FrameTimestamp<=CurrentTime else '0';
    ------------------------------------------------------------------------------------------




    --DATA OUTPUT-----------------------------------------------------------------------------

    --storing addresses of the next frame
    Addr_out:ReadAddress_FSM
        generic map(
            gAddrDataWidth=>gAddrDataWidth,
            gBuffBitWidth=>gAddrDataWidth)
    port map(
            clk=>clk,                           reset=>reset,
            iFifoData=>AddrOutData,             iDataReady=>FifoDataReady,      iNextFrame=>iNextFrame,
            oDataOutStart=>oDataOutStartAddr,   oDataOutEnd=>oDataOutEndAddr,   oRd=>FifoRd,
            oStart=>oStartNewFrame
            );
    ------------------------------------------------------------------------------------------


end two_seg_arch;