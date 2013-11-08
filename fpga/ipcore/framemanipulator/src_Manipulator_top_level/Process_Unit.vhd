
-- ******************************************************************************************
-- *                                Process_Unit                                            *
-- ******************************************************************************************
-- *                                                                                        *
-- * Handels the series of test of the Framemanipulator.                                    *
-- *                                                                                        *
-- * Selecting the different tasks and handling the series of test are done in the          *
-- * Manipulation_Manager.                                                                  *
-- *                                                                                        *
-- * The addresses of the frame-data are allocated by the Address_Manager                   *
-- * The delay-task is also done there                                                      *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Process_Unit                            by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Process_Unit is
    generic(gDataBuffAddrWidth:     natural:=11;
            gTaskWordWidth:         natural:=64;
            gTaskAddrWidth:         natural:=5;
            gManiSettingWidth:      natural:=112;
            gCycleCntWidth:         natural:=8;
            gSize_Mani_Time:        natural:=40;
            gNoOfDelFrames:         natural:=255);
    port(
        clk, reset:             in std_logic;

        iStartFrameProcess:     in std_logic;   --valid frame received
        iFrameEnded:            in std_logic;   --frame has reached its end
        iFrameSync:             in std_logic;   --synchronization of the frame-data-stream
        iStartTest:             in std_logic;   --start of a series of test
        iStopTest:              in std_logic;   --abort of a series of test
        iNextFrame:             in std_logic;   --a new frame could be created
        oTestActive:            out std_logic;  --Series of Test is active => Flag for PRes
        oStartNewFrame:         out std_logic;  --data of a new frame is available

        --compare Tasks from memory with the frame
        iData:                  in std_logic_vector(7 downto 0);                    --frame-data-stream
        iTaskSettingData:       in std_logic_vector(gTaskWordWidth*2-1 downto 0);   --task settings
        iTaskCompFrame:         in std_logic_vector(gTaskWordWidth-1 downto 0);     --frame-selection-data
        iTaskCompMask:          in std_logic_vector(gTaskWordWidth-1 downto 0);     --frame-selection-mask
        oRdTaskAddr:            out std_logic_vector(gTaskAddrWidth-1 downto 0);    --task selection

        --Start/End address of the frame-data
        oDataInStartAddr:       out std_logic_vector(gDataBuffAddrWidth-1 downto 0);--position of the first written byte of the next frame
        iDataInEndAddr:         in std_logic_vector(gDataBuffAddrWidth-1 downto 0); --position of the last written byte of the current frame
        oDataOutStartAddr:      out std_logic_vector(gDataBuffAddrWidth-1 downto 0);--position of the first written byte of the created frame
        oDataOutEndAddr:        out std_logic_vector(gDataBuffAddrWidth-1 downto 0);--position of the last written byte of the created frame
        oError_Addr_Buff_OV:    out std_logic;                                      --Error: Overflow of the address-buffer

        --Manipulations in other components
        oTaskManiEn:            out std_logic;                                      --task: header manipulation
        oTaskCutEn:             out std_logic;                                      --task: cut frame
        oDistCrcEn:             out std_logic;                                      --task: crc distortion
        oManiSetting:           out std_logic_vector(gManiSettingWidth-1 downto 0)  --settings of the manipulations
     );
end Process_Unit;

architecture two_seg_arch of Process_Unit is

    --manipulation selector ------------------------------------------------------------------
    --collects the data of the ethernet header and chooses the fitting manipulation task
    component Manipulation_Manager
        generic(
                gFrom:              natural:=15;
                gTo :               natural:=22;
                gWordWidth:         natural:=64;
                gManiSettingWidth:  natural:=112;
                gCycleCntWidth:     natural:=8;
                gBuffAddrWidth:     natural:=5
            );
        port(
            clk, reset:         in std_logic;
            --control signals
            iStartFrameProcess: in std_logic;   --Valid Frame received for processing
            iFrameSync:         in std_logic;   --sync for collecting header-data
            iStartTest:         in std_logic;   --start series of test
            iStopTest:          in std_logic;   --stop test
            oStartFrameStorage: out std_logic;  --valid frame was compared and can be stored
            oTestSync:          out std_logic;  --sync of a new test
            oTestActive:        out std_logic;  --series of test is currently running
            oFrameIsSoc:        out std_logic;  --current frame is a SoC
            --data signals
            iData:              in std_logic_vector(7 downto 0);                    --frame-stream
            iTaskSettingData:   in std_logic_vector(2*gWordWidth-1 downto 0);       --settings for the tasks
            iTaskCompFrame:     in std_logic_vector(gWordWidth-1 downto 0);         --frame-header-data for the tasks
            iTaskCompMask:      in std_logic_vector(gWordWidth-1 downto 0);         --frame-mask for the tasks
            oTaskSelection:     out std_logic_vector(gBuffAddrWidth-1 downto 0);    --Task selection
            --manipulations
            oTaskDelayEn:       out std_logic;                                      --task: delay frame
            oTaskManiEn:        out std_logic;                                      --task: manipulate header
            oTaskCrcEn:         out std_logic;                                      --task: distort crc
            oTaskCutEn:         out std_logic;                                      --task: truncate frame
            oManiSetting:       out std_logic_vector(gManiSettingWidth-1 downto 0)  --manipulation setting
         );
    end component;


    --memory manager for the data-buffer -----------------------------------------------------
    --handles the addresses of the frame-data for receiving and created frames
    --also processes the delay-frame manipulation
    component Address_Manager
        generic(
                gAddrDataWidth:     natural:=11;
                gDelayDataWidth:    natural:=112;
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
    end component;


    constant cDelayDataWidth: natural :=gSize_Mani_Time+8;


    signal StartFrameStorage:   std_logic;
    signal TestSync:            std_logic;
    signal FrameIsSoC:          std_logic;

    signal TaskDelayEn:         std_logic;
    signal TaskCrcEn:           std_logic;

    signal ManiSetting:         std_logic_vector(gManiSettingWidth-1 downto 0);
    signal DelaySetting:        std_logic_vector(cDelayDataWidth-1 downto 0);

begin



    --manipulation selector ------------------------------------------------------------------
    --starts a test of series after receiving the iStartTest signal.
    --compares the ethernet-header-data with the task settings, filter and mask
    --process the drop-frame manipulation task
    --enables the active manipulation
    ------------------------------------------------------------------------------------------
    M_Manager:Manipulation_Manager
    generic map(gFrom=>15,gTo=>22,
                gWordWidth          =>  gTaskWordWidth,
                gManiSettingWidth   =>  gManiSettingWidth,
                gCycleCntWidth      =>  gCycleCntWidth,
                gBuffAddrWidth      =>  gTaskAddrWidth)
    port map(
            clk=>clk, reset=>reset,
            --control signals
            iStartFrameProcess=>iStartFrameProcess, iFrameSync=>iFrameSync, iStartTest=>iStartTest,
            oStartFrameStorage=>StartFrameStorage,  iStopTest=>iStopTest,   oTestSync=>TestSync,
            oTestActive=>oTestActive,               oFrameIsSoc=>FrameIsSoC,
            --data signals
            oTaskSelection=>oRdTaskAddr,            iData=>iData,           iTaskSettingData=>iTaskSettingData,
            iTaskCompFrame=>iTaskCompFrame,         iTaskCompMask=>iTaskCompMask,
            --manipulations
            oTaskDelayEn=>TaskDelayEn,              oTaskManiEn=>oTaskManiEn,oTaskCrcEn=>TaskCrcEn,
            oTaskCutEn=>oTaskCutEn,                 oManiSetting=>ManiSetting
            );


    --reduction of unused bits
    DelaySetting<=ManiSetting(cDelayDataWidth+gTaskWordWidth-1 downto gTaskWordWidth);

    --memory manager for the data-buffer -----------------------------------------------------
    --Stores the start- and end-address of valid frames (with iDataInEndAddr StartFrameStorage
    --and iFrameEnded)
    --It also allocates a new start address to the Frame-Receiver with oDataInStartAddr.
    --
    --The signal oDataInStartAddr remains after receiving an invalid or dropped frames. Thus,
    --these frames are overwritten with the data following frame.
    --
    --The delay task is also done in this component.
    --
    --Addresses for new frames can be ordered from the Frame-Creator with iNextFrame
    ------------------------------------------------------------------------------------------
    A_Manager:Address_Manager
    generic map(gAddrDataWidth      =>  gDataBuffAddrWidth,
                gDelayDataWidth     =>  cDelayDataWidth,
                gNoOfDelFrames      =>  gNoOfDelFrames)
    port map(
            clk=>clk, reset=>reset,
            --control signals
            iStartFrameStorage=>StartFrameStorage,  iFrameEnd=>iFrameEnded,     iFrameIsSoC=>FrameIsSoC,
            iTestSync=>TestSync,                    iTestStop=>iStopTest,       iNextFrame=>iNextFrame,
            oStartNewFrame=>oStartNewFrame,
            --manipulations
            iDelaySetting=>DelaySetting,            iTaskDelayEn=>TaskDelayEn,  iTaskCrcEn=>TaskCrcEn,
            oDistCrcEn=>oDistCrcEn,
            --memory management
            iDataInEndAddr=>iDataInEndAddr,         oDataInStartAddr=>oDataInStartAddr,
            oDataOutStartAddr=>oDataOutStartAddr,   oDataOutEndAddr=>oDataOutEndAddr,
            oError_Addr_Buff_OV=>oError_Addr_Buff_OV);


    oManiSetting<=ManiSetting;

end two_seg_arch;