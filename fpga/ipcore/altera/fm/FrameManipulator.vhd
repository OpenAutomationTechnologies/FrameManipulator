
-- ******************************************************************************************
-- *                            Ethernet-Framemanipulator                                   *
-- ******************************************************************************************
-- *                                                                                        *
-- * IP-core, which achieves different tasks of manipulations from a POWERLINK Slave        *
-- *                                                                                        *
-- * All further information are available in the corresponding documentations:             *
-- *  - FM_Userdoku                                                                         *
-- *  - FM_Developementdoku                                                                 *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Ethernet-Framemanipulator               by Sebastian Muelhausen     *
-- * 25.11.13 V1.1      Updated for safety manipulations        by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.global.all;

entity FrameManipulator is
    generic(gBytesOfTheFrameBuffer: natural:=1600;
            gTaskBytesPerWord:      natural:=4;
            gTaskAddr:              natural:=8;
            gTaskCount:             natural:=32;
            gControlBytesPerWord:   natural:=1;
            gControlAddr:           natural:=1;
            gBytesOfThePackBuffer   : natural := 16000;
            gNumberOfPackets        : natural := 500
            );
    port(
        clk_50, reset:  in std_logic;
        s_clk:          in std_logic;
        iRXDV:          in std_logic;
        iRXD:           in std_logic_vector(1 downto 0);

        --Avalon Slave Task Memory
        st_address:     in std_logic_vector(gTaskAddr-1 downto 0);
        st_writedata:   in std_logic_vector(gTaskBytesPerWord*cByteLength-1 downto 0);
        st_write:       in std_logic;
        st_read:        in std_logic;
        st_readdata:    out std_logic_vector(gTaskBytesPerWord*cByteLength-1 downto 0);
        st_byteenable:  in std_logic_vector(gTaskBytesPerWord-1 downto 0);

        --Avalon Slave Contol Memory
        sc_address:     in std_logic_vector(gControlAddr-1 downto 0);
        sc_writedata:   in std_logic_vector(gControlBytesPerWord*cByteLength-1 downto 0);
        sc_write:       in std_logic;
        sc_read:        in std_logic;
        sc_readdata:    out std_logic_vector(gControlBytesPerWord*cByteLength-1 downto 0);
        sc_byteenable:  in std_logic_vector(gControlBytesPerWord-1 downto 0);

        oTXData:        out std_logic_vector(1 downto 0);
        oTXDV:          out std_logic;

        oLED:           out std_logic_vector(1 downto 0)
     );
end FrameManipulator;

architecture two_seg_arch of FrameManipulator is

    --Interface to the PL-Slave with two avalon slave ---------------------------------------
    --contains the register for tasks, operations and errors
    component Memory_Interface
        generic(gSlaveTaskWordWidth:    natural:=4*cByteLength;
                gSlaveTaskAddrWidth:    natural:=8;
                gTaskWordWidth:         natural:=8*cByteLength;
                gTaskAddrWidth:         natural:=5;
                gSlaveControlWordWidth: natural:=cByteLength;
                gSlaveControlAddrWidth: natural:=1
            );
        port(
            clk, reset:             in std_logic;
            s_clk:                  in std_logic;   --avalon bus clock domain
            --Avalon Slave Task Memory
            st_address:             in std_logic_vector(gSlaveTaskAddrWidth-1 downto 0);
            st_writedata:           in std_logic_vector(gSlaveTaskWordWidth-1 downto 0);
            st_write:               in std_logic;
            st_read:                in std_logic;
            st_readdata:            out std_logic_vector(gSlaveTaskWordWidth-1 downto 0);
            st_byteenable:          in std_logic_vector((gSlaveTaskWordWidth/8)-1 downto 0);
            --Avalon Slave Contol Memory
            sc_address:             in std_logic_vector(gSlaveControlAddrWidth-1 downto 0);
            sc_writedata:           in std_logic_vector(gSlaveControlWordWidth-1 downto 0);
            sc_write:               in std_logic;
            sc_read:                in std_logic;
            sc_readdata:            out std_logic_vector(gSlaveControlWordWidth-1 downto 0);
            sc_byteenable:          in std_logic_vector(gSlaveControlWordWidth/8-1 downto 0);
            --status signals
            iError_Addr_Buff_OV:    in std_logic;   --Error: Overflow address-buffer
            iError_Frame_Buff_OV:   in std_logic;   --Error: Overflow data-buffer
            iError_Packet_Buff_OV:  in std_logic;   --Error: Overflow packet-buffer
            iError_Task_Conf:       in std_logic;   --Error: Wrong task configuration
            oStartTest:             out std_logic;  --start a new series of test
            oStopTest:              out std_logic;  --aborts the current test
            oClearMem               : out std_logic;  --clear all tasks
            oResetPaketBuff:        out std_logic;  --Resets the packet FIFO and removes the packet lag
            iTestActive:            in std_logic;   --Series of test is active
            --task signals
            iRdTaskAddr:            in std_logic_vector(gTaskAddrWidth-1 downto 0);     --task selection
            oTaskSettingData:       out std_logic_vector(2*gTaskWordWidth-1 downto 0);  --settings of the task
            oTaskCompFrame:         out std_logic_vector(gTaskWordWidth-1 downto 0);    --header-data of the manipulated frame
            oTaskCompMask:          out std_logic_vector(gTaskWordWidth-1 downto 0)     --mask-data of the manipulated frame
        );
    end component;


    --component for receiving the PL-Frame --------------------------------------------------
    --Checking the Preamble and Ethertype, generating sync signal and storing the Frames in
    -- the Data-Buffer
    component Frame_Receiver
        generic(
                gBuffAddrWidth      : natural :=11;
                gEtherTypeFilter    : std_logic_vector :=X"88AB_0800_0806"  --filter
                );
        port(
            clk, reset:         in std_logic;
            iRXDV:              in std_logic;                                   --frame data valid
            iRXD:               in std_logic_vector(1 downto 0);                --frame data (2bit)
            --write data
            oData:              out std_logic_vector(cByteLength-1 downto 0);   --frame data (1byte)
            oWrBuffAddr:        out std_logic_vector(gBuffAddrWidth-1 downto 0);--write address
            oWrBuffEn :         out std_logic;                                  --write data-memory enable
            iDataStartAddr:     in std_logic_vector(gBuffAddrWidth-1 downto 0); --first byte of frame data
            oDataEndAddr:       out std_logic_vector(gBuffAddrWidth-1 downto 0);--last byte of frame data
            --truncate frame
            iTaskCutEn:         in std_logic;                                   --cut task enabled
            iTaskCutData:       in std_logic_vector(gBuffAddrWidth-1 downto 0); --cut task setting
            --start process-unit
            oStartFrameProcess: out std_logic;                                  --valid frame received
            oFrameEnded:        out std_logic;                                  --frame ended
            oFrameSync:         out std_logic                                   --synchronization signal
        );
    end component;


    --internal Memory for the frame data ----------------------------------------------------
    --stores data and manipulates the header files
    component Data_Buffer
        generic(gDataWidth:         natural:=cByteLength;
                gDataAddrWidth:     natural:=11;
                gNoOfHeadMani:      natural:=8;
                gTaskWordWidth:     natural:=8*cByteLength;
                gManiSettingWidth:  natural:=14*cByteLength
                );
        port
        (
            clk, reset:             in std_logic;
            iData:                  in std_logic_vector(gDataWidth-1 downto 0);         --write data    Port A
            iRdAddress:             in std_logic_vector(gDataAddrWidth-1 downto 0);     --read address  Port B
            iRdEn:                  in std_logic;                                       --read enable   Port B
            iWrAddress:             in std_logic_vector(gDataAddrWidth-1 downto 0);     --write address Port A
            iWrEn:                  in std_logic  := '0';                               --write enable  Port A
            oData:                  out std_logic_vector(gDataWidth-1 downto 0);        --read data     Port B
            oError_Frame_Buff_OV:   out std_logic;                                      --Error flag, when overflow occurs

            iManiSetting:           in std_logic_vector(gManiSettingWidth-1 downto 0);  --header manipulation setting
            iTaskManiEn:            in std_logic;                                       --header manipulation enable
            iDataStartAddr:         in std_logic_vector(gDataAddrWidth-1 downto 0)      --start byte of manipulated header
        );
    end component;


    --component for processing the frame ----------------------------------------------------
    --selects the task for the selected frame and handles the addresses of the stored data
    component Process_Unit
        generic(gDataBuffAddrWidth:     natural:=11;
                gTaskWordWidth:         natural:=8*cByteLength;
                gTaskAddrWidth:         natural:=5;
                gManiSettingWidth:      natural:=14*cByteLength;
                gSafetySetting          : natural :=5*cByteLength;  --5 Byte safety setting
                gCycleCntWidth:         natural:=cByteLength;
                gSize_Mani_Time:        natural:=5*cByteLength;
                gNoOfDelFrames:         natural:=255
                );
        port(
            clk, reset:             in std_logic;

            iStartFrameProcess:     in std_logic;   --valid frame received
            iFrameEnded:            in std_logic;   --frame has reached its end
            iFrameSync:             in std_logic;   --synchronization of the frame-data-stream
            iStartTest:             in std_logic;   --start of a series of test
            iStopTest:              in std_logic;   --abort of a series of test
            iClearMem               : in std_logic; --clear all tasks
            iNextFrame:             in std_logic;   --a new frame could be created
            iSafetyActive:          in std_logic;   --safety manipulations are active
            oTestActive:            out std_logic;  --Series of Test is active => Flag for PRes
            oStartNewFrame:         out std_logic;  --data of a new frame is available
            oError_Task_Conf:       out std_logic;  --Error: Wrong task configuration

            --compare Tasks from memory with the frame
            iData:                  in std_logic_vector(cByteLength-1 downto 0);        --frame-data-stream
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
            oDistCrcEn:             out std_logic;
            oTaskSafetyEn:          out std_logic;                                      --task: safety packet manipulation
            oSafetyFrame:           out std_logic;                                      --current frame matches to the current or last safety task
            oFrameIsSoc:            out std_logic;                                      --current frame is a SoC
            oManiSetting:           out std_logic_vector(gManiSettingWidth-1 downto 0); --settings of the manipulations
            oSafetySetting          : out std_logic_vector(gSafetySetting-1 downto 0)   --Setting of the current or last safety task
         );
    end component;


    --component for generating a new frame --------------------------------------------------
    --creates a new frame with new generated Preamble and CRC
    component Frame_Creator
        generic(gDataBuffAddrWidth      : natural:=11;
                gSafetyPackSelCntWidth  : natural :=8);
        port(
            clk, reset:     in std_logic;

            iStartNewFrame: in std_logic;   --data for a new frame is available
            oNextFrame:     out std_logic;  --frame-creator is ready for new data
            iDistCrcEn:     in std_logic;   --task: distortion of frame-CRC

            --Read data buffer
            iDataStartAddr: in std_logic_vector(gDataBuffAddrWidth-1 downto 0); --Position of the first frame-byte
            iDataEndAddr:   in std_logic_vector(gDataBuffAddrWidth-1 downto 0); --Position of the last
            iData:          in std_logic_vector(cByteLength-1 downto 0);        --frame-data
            oRdBuffAddr:    out std_logic_vector(gDataBuffAddrWidth-1 downto 0);--read address of data-memory
            oRdBuffEn:      out std_logic;                                      --read-enable

            --Safety packet exchange
            iPacketExchangeEn   : in std_logic;                                    --Start of the exchange of the safety packet
            iPacketStart        : in std_logic_vector(cByteLength-1 downto 0);     --Start of safety packet
            iPacketSize         : in std_logic_vector(cByteLength-1 downto 0);     --Size of safety packet
            iPacketData         : in std_logic_vector(cByteLength-1 downto 0);     --Data of the new safety packet
            iPacketExtension    : in std_logic;                                    --Exchange will be extended for several tacts
            oExchangeData       : out std_logic;                                   --Exchanging safety data

            --Output
            oTXData :       out std_logic_vector(1 downto 0);   --frame-output-data
            oTXDV:          out std_logic                       --frame-output-data-valid
        );
    end component;


    --component for safety packet manipulations ---------------------------------------------
    --! @brief Stores and exchanges safety packets
    component Packet_Buffer
        generic(gSafetySetting      : natural:=5*cByteLength;
                gPacketAddrWidth    : natural := 14;    --enough for 500 Packets with the size of 28 Bytes
                gAddrMemoryWidth    : natural := 9);    --Width of address memory, should store at least 500 addresses
        port(
            clk, reset              : in std_logic;

            iResetPaketBuff         : in std_logic;     --Resets the packet FIFO and removes the packet lag
            iStopTest               : in std_logic;     --abort of a series of test
            oSafetyActive           : out std_logic;    --safety manipulations are active
            oError_Packet_Buff_OV   : out std_logic;    --Error: Overflow packet-buffer

            iTaskSafetyEn           : in std_logic;                                     --task: safety packet manipulation
            iExchangeData           : in std_logic;                                     --exchange packet data
            iSafetyFrame            : in std_logic;                                     --current frame matches to the current or last safety task
            iFrameIsSoc             : in std_logic;                                     --current frame is a SoC
            iManiSetting            : in std_logic_vector(gSafetySetting-1 downto 0);   --settings of the manipulations
            oPacketExchangeEn       : out std_logic;                                    --Start of the exchange of the safety packet
            oPacketExtension        : out std_logic;                                    --Exchange will be extended for several tacts
            oPacketStart            : out std_logic_vector(cByteLength-1 downto 0);     --Start of safety packet
            oPacketSize             : out std_logic_vector(cByteLength-1 downto 0);     --Size of safety packet

            iFrameData              : in std_logic_vector(cByteLength-1 downto 0);      --Data of the current frame
            oPacketData             : out std_logic_vector(cByteLength-1 downto 0)      --Data of the safety packet
         );
    end component;


    constant cDataBuffAddrWidth:    natural:=LogDualis(gBytesOfTheFrameBuffer);

    constant cSlaveTaskWordWidth:   natural:=gTaskBytesPerWord*8;
    constant cSlaveTaskAddr:        natural:=gTaskAddr;

    constant cTaskWordWidth:        natural:=cSlaveTaskWordWidth*2;
    --doubled memory width for the internal process
    constant cTaskAddrWidth:        natural:=LogDualis(gTaskCount);

    constant cCycleCntWidth:        natural:=cByteLength;   --maximal number of POWERLINK cycles for the series of test, 1 Byte
    constant cSize_Mani_Time:       natural:=5*cByteLength; --size of time setting of the delay task, 5 Byte
    constant cNoOfHeadMani:         natural:=8;             --Number of manipulated header bytes
    constant cNoOfDelFrames:        natural:=255;           --Maximal number of delayed frame tasks

    constant cManiSettingWidth:     natural:=2*cTaskWordWidth-cCycleCntWidth-8;
                                            --two task objects - Cycle Word - Task Byte

    constant cSafetySetting         : natural:=6*cByteLength;   --6 Byte Safety Setting
    constant cSafetyPackSelCntWidth : natural:=11;              --Width of counter to select packet: 11 bit to change the whole frame
    constant cPacketAddrWidth       : natural:=LogDualis(gBytesOfThePackBuffer);
    constant cAddrMemoryWidth       : natural:=LogDualis(gNumberOfPackets);


    --signals memory interface
    signal Error_Addr_Buff_OV   : std_logic;
    signal Error_Frame_Buff_OV  : std_logic;
    signal Error_Packet_Buff_OV : std_logic;
    signal Error_Task_Conf      : std_logic;

    signal RdTaskAddr:          std_logic_vector(cTaskAddrWidth-1 downto 0);

    signal TaskSettingData:     std_logic_vector(2*cTaskWordWidth-1 downto 0);
    signal TaskCompFrame:       std_logic_vector(cTaskWordWidth-1 downto 0);
    signal TaskCompMask:        std_logic_vector(cTaskWordWidth-1 downto 0);

    --writing data buffer
    signal WrBuffAddr:          std_logic_vector(cDataBuffAddrWidth-1 downto 0);
    signal WrBuffEn:            std_logic;
    signal DataToBuff:          std_logic_vector(cByteLength-1 downto 0);

    signal DataInStartAddr:     std_logic_vector(cDataBuffAddrWidth-1 downto 0):=(others=>'0');
    signal DataInEndAddr:       std_logic_vector(cDataBuffAddrWidth-1 downto 0);

    --reading data buffer
    signal RdBuffAddr:          std_logic_vector(cDataBuffAddrWidth-1 downto 0);
    signal RdBuffEn:            std_logic;
    signal DataFromBuff:        std_logic_vector(cByteLength-1 downto 0);

    signal DataOutStartAddr:    std_logic_vector(cDataBuffAddrWidth-1 downto 0);
    signal DataOutEndAddr:      std_logic_vector(cDataBuffAddrWidth-1 downto 0);

    --Incoming frames
    signal StartFrameProc:      std_logic;
    signal FrameEnded:          std_logic;
    signal FrameSync:           std_logic;

    --Test control
    signal StartTest:           std_logic;
    signal StopTest:            std_logic;
    signal ClearMem             : std_logic;
    signal TestActive:          std_logic;

    --Outgoing frames
    signal NextFrame:           std_logic;
    signal StartNewFrame:       std_logic;
    signal FrameIsSoc           : std_logic;                                    --current frame is a SoC

    --Manipulations
    signal ManiSetting:         std_logic_vector(cManiSettingWidth-1 downto 0);
    signal TaskManiEn:          std_logic;
    signal TaskCutEn:           std_logic;
    signal DistCrcEn:           std_logic;


    --Reducing ManiSetting via alias
    alias ManiSetting_Cut      : std_logic_vector(cDataBuffAddrWidth-1 downto 0)
                                    is ManiSetting(cDataBuffAddrWidth+cTaskWordWidth-1 downto cTaskWordWidth);


    --Safety
    signal TaskSafetyEn         : std_logic;                                    --task: safety packet manipulation
    signal SafetyFrame          : std_logic;                                    --Current Frame is a selected safety frame
    signal PacketExchangeEn     : std_logic;                                    --Start of the exchange of the safety packet
    signal PacketStart          : std_logic_vector(cByteLength-1 downto 0);     --Start of safety packet
    signal PacketSize           : std_logic_vector(cByteLength-1 downto 0);     --Size of safety packet
    signal PacketData           : std_logic_vector(cByteLength-1 downto 0);     --Data of the safety packet
    signal SafetyActive         : std_logic;                                    --safety manipulations are active
    signal ExchangeData         : std_logic;                                    --exchange packet data
    signal PacketExtension      : std_logic;                                    --Exchange will be extended for several tacts
    signal SafetySetting        : std_logic_vector(cSafetySetting-1 downto 0);  --Setting of the current or last safety task
    signal ResetPaketBuff       : std_logic;                                    --Resets the packet FIFO and removes the packet lag

    --Output
    signal TXData:              std_logic_vector(1 downto 0);
    signal TXDV:                std_logic;



begin


    --Interface to the PL-Slave with two avalon slave ---------------------------------------
    --s_clk for the clock domain of the avSalon slaves
    --st_...    avalon slave for the different tasks
    --sc_...    avalon slave for the control registers
    --FM Error collection   => iError_Addr_Buff_OV, iError_Frame_Buff_OV
    --output of test status => oStartTest, oStopTest
    --reading tasks         => iRdTaskAddr
    --output tasks          => oTaskSettingData, oTaskCompFrame, oTaskCompMask
    -----------------------------------------------------------------------------------------
    M_Interface:Memory_Interface
    generic map(gSlaveTaskWordWidth=>cSlaveTaskWordWidth,       gSlaveTaskAddrWidth=>cSlaveTaskAddr,
                gTaskWordWidth=>cTaskWordWidth,                 gTaskAddrWidth=>cTaskAddrWidth,
                gSlaveControlWordWidth=>gControlBytesPerWord*8, gSlaveControlAddrWidth=>gControlAddr)
    port map(
            clk=>clk_50,s_clk=>s_clk,       reset=>reset,

            st_address=>st_address,     st_writedata=>st_writedata,     st_write=>st_write,
            st_read=>st_read,           st_readdata=>st_readdata,       st_byteenable=>st_byteenable,

            sc_address=>sc_address,     sc_writedata=>sc_writedata,     sc_write=>sc_write,
            sc_read=>sc_read,           sc_readdata=>sc_readdata,       sc_byteenable=>sc_byteenable,

            iError_Addr_Buff_OV     => Error_Addr_Buff_OV,
            iError_Frame_Buff_OV    => Error_Frame_Buff_OV,
            iError_Packet_Buff_OV   => Error_Packet_Buff_OV,
            iError_Task_Conf        => Error_Task_Conf,
            oStartTest              => StartTest,
            oStopTest               => StopTest,
            oClearMem               => ClearMem,
            oResetPaketBuff         => ResetPaketBuff,
            iTestActive             => TestActive,

            iRdTaskAddr             => RdTaskAddr,
            oTaskSettingData=>TaskSettingData,  oTaskCompFrame=>TaskCompFrame,  oTaskCompMask=>TaskCompMask
            );



    --component for receiving the PL-Frame --------------------------------------------------
    --convert the 2bit data stream to 1 byte    => oData
    --storing the Frames in the Data-Buffer     => oWrBuffAddr, oWrBuffEn
    --Checking the Preamble                     => oFrameStart
    --generating sync signal for Process-Unit   => oFrameSync
    -----------------------------------------------------------------------------------------
    F_Receiver : Frame_Receiver
    generic map(
                gBuffAddrWidth      => cDataBuffAddrWidth,
                gEtherTypeFilter    => X"88AB_0800_0806"    --POWERLINK, IP and ARP frames are valid
                )
    port map (
            clk=>clk_50, reset=>reset,
            iRXDV => iRXDV,     iRXD =>  iRXD,              iDataStartAddr=>DataInStartAddr,
            iTaskCutEn=>TaskCutEn,  iTaskCutData=>ManiSetting_Cut,

            oData => DataToBuff,                oWrBuffAddr => WrBuffAddr,  oWrBuffEn => WrBuffEn,
            oDataEndAddr => DataInEndAddr,
            oStartFrameProcess =>StartFrameProc,oFrameEnded=>FrameEnded,    oFrameSync=>FrameSync);



    --internal Memory for the frame data ----------------------------------------------------
    --storing frame data        => iData, iWrAddress, iWrEn
    --reading frame data        => oData, iRdAddress, iRdEn
    --manipuating header files  => iTaskManiEn, iManiSetting, iDataStartAddr(for offset)
    --Overflow detection        => oError_Frame_Buff_OV
    -----------------------------------------------------------------------------------------
    D_Buffer : Data_Buffer
    generic map(gDataWidth          =>  cByteLength,
                gDataAddrWidth      =>  cDataBuffAddrWidth,
                gNoOfHeadMani       =>  cNoOfHeadMani,
                gTaskWordWidth      =>  cTaskWordWidth,
                gManiSettingWidth   =>  cManiSettingWidth)
    port map (
            clk=>clk_50,reset=>reset,
            iData => DataToBuff,        iWrAddress => WrBuffAddr, iWrEn => WrBuffEn,
            oData => DataFromBuff,      iRdAddress => RdBuffAddr, iRdEn=>RdBuffEn,

            iTaskManiEn=>TaskManiEn,    iManiSetting=>ManiSetting,iDataStartAddr=>DataInStartAddr,
            oError_Frame_Buff_OV=>Error_Frame_Buff_OV);



    --component for processing the frame ----------------------------------------------------
    --handles the whole series of test      =>  iStartTest, iStopTest
    --compares the frame with the tasks-mem =>  iData, iTaskSettingData,
    --                                          iTaskCompFrame, iTaskCompMask
    --manages the space of the data memory  =>  oDataInStartAddr, iDataInEndAddr,
    --                                          oDataOutStartAddr,oDataOutEndAddr
    -----------------------------------------------------------------------------------------
    P_Unit:Process_Unit
    generic map(gDataBuffAddrWidth  =>  cDataBuffAddrWidth,
                gTaskWordWidth      =>  cTaskWordWidth,
                gTaskAddrWidth      =>  cTaskAddrWidth,
                gManiSettingWidth   =>  cManiSettingWidth,
                gSafetySetting      =>  cSafetySetting,
                gCycleCntWidth      =>  cCycleCntWidth,
                gSize_Mani_Time     =>  cSize_Mani_Time,
                gNoOfDelFrames      =>  cNoOfDelFrames)
    port map(
            clk                 => clk_50,              reset           => reset,

            iStartFrameProcess  => StartFrameProc,
            iFrameEnded         => FrameEnded,
            iFrameSync          => FrameSync,
            iNextFrame          => NextFrame,
            iStartTest          => StartTest,
            iStopTest           => StopTest,
            iClearMem           => ClearMem,
            iSafetyActive       => SafetyActive,
            oTestActive         => TestActive,
            oStartNewFrame      => StartNewFrame,
            oError_Task_Conf    => Error_Task_Conf,

            iData               => DataToBuff,
            iTaskSettingData    => TaskSettingData,     iTaskCompFrame  => TaskCompFrame,
            iTaskCompMask       => TaskCompMask,        oRdTaskAddr     => RdTaskAddr,

            oDataInStartAddr    => DataInStartAddr,     iDataInEndAddr  => DataInEndAddr,
            oDataOutStartAddr   => DataOutStartAddr,    oDataOutEndAddr => DataOutEndAddr,
            oError_Addr_Buff_OV => Error_Addr_Buff_OV,

            oTaskManiEn         => TaskManiEn,          oTaskCutEn      => TaskCutEn,
            oDistCrcEn          => DistCrcEn,           oTaskSafetyEn   => TaskSafetyEn,
            oSafetyFrame        => SafetyFrame,         oFrameIsSoc     => FrameIsSoc,
            oManiSetting        => ManiSetting,         oSafetySetting  => SafetySetting);






    --component for generating a new frame --------------------------------------------------
    --readout the data-buffer and generates a new frame
    -----------------------------------------------------------------------------------------
    F_Creator : Frame_Creator
    generic map(gDataBuffAddrWidth      => cDataBuffAddrWidth,
                gSafetyPackSelCntWidth  => cSafetyPackSelCntWidth)
    port map (
            clk=>clk_50,                                reset               => reset,

            iStartNewFrame      => StartNewFrame,       oNextFrame          => NextFrame,
            iDistCrcEn          => DistCrcEn,

            iDataEndAddr        => DataOutEndAddr,      iDataStartAddr      => DataOutStartAddr,
            iData               => DataFromBuff,        oRdBuffEn           => RdBuffEn,
            oRdBuffAddr         => RdBuffAddr,

            iPacketExchangeEn   => PacketExchangeEn,
            iPacketStart        => PacketStart,         iPacketSize         => PacketSize,
            iPacketData         => PacketData,          iPacketExtension    => PacketExtension,
            oExchangeData       => ExchangeData,

            oTXData             => TXData,              oTXDV               => TXDV);


    --component for safety packet manipulations ---------------------------------------------
    --stores and exchanges safety packets
    -----------------------------------------------------------------------------------------
    P_Buff : Packet_Buffer
    generic map(gSafetySetting      => cSafetySetting,
                gPacketAddrWidth    => cPacketAddrWidth,
                gAddrMemoryWidth    => cAddrMemoryWidth)
    port map(
            clk                 => clk_50,              reset                   => reset,

            iResetPaketBuff         => ResetPaketBuff,
            iStopTest               => StopTest,
            oSafetyActive           => SafetyActive,
            oError_Packet_Buff_OV   => Error_Packet_Buff_OV,

            iTaskSafetyEn       => TaskSafetyEn,        iExchangeData           => ExchangeData,
            iSafetyFrame        => SafetyFrame,         iFrameIsSoc             => FrameIsSoc,
            iManiSetting        => SafetySetting,
            oPacketExchangeEn   => PacketExchangeEn,    oPacketExtension        => PacketExtension,
            oPacketStart        => PacketStart,         oPacketSize             => PacketSize,

            iFrameData          => DataFromBuff,        oPacketData             => PacketData);




    -- register to decrease timing problems of the PHY --------------------------------
    -- better alternative: 100MHz clock with synchronization on the falling edge
    process(clk_50)
    begin
        if clk_50'event and clk_50='1' then
            oTXData<=TXData;
            oTXDV<=TXDV;
        end if;
    end process;


    --output of active and abort LED:
    oLED    <= TestActive & StopTest;


end two_seg_arch;