-------------------------------------------------------------------------------
--! @file FrameManipulator.vhd
--! @brief Ethernet-Framemanipulator toplevel for Altera
--! @details IP-core, which achieves different tasks of manipulations from a POWERLINK Slave
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


--! This is the entity is the top-module of the Framemanipulator
entity FrameManipulator is
    generic(gBytesOfTheFrameBuffer  : natural := 1600;  --! Frame buffer size
            gTaskBytesPerWord       : natural := 4;     --! Word width of Avalon slave for transfer of tasks
            gTaskAddr               : natural := 8;     --! Address width of Avalon slave for transfer of tasks
            gTaskCount              : natural := 32;    --! Number of configurable tasks
            gControlBytesPerWord    : natural := 1;     --! Word width of Avalon slave for transfer of operations
            gControlAddr            : natural := 1;     --! Address width of Avalon slave for transfer of operations
            gBytesOfThePackBuffer   : natural := 16000; --! Packet buffer size
            gNumberOfPackets        : natural := 500    --! Maximal number of safety packets
            );
    port(
        iClk50          : in std_logic;                     --! clock
        iReset          : in std_logic;                     --! reset
        iS_clk          : in std_logic;                     --! clock of avalon slaves
        iRXDV           : in std_logic;                     --! Data valid RMII
        iRXD            : in std_logic_vector(1 downto 0);  --! Data RMII

        --Avalon Slave Task Memory
        iSt_address     : in std_logic_vector(gTaskAddr-1 downto 0);                            --! Task avalon slave address
        iSt_writedata   : in std_logic_vector(gTaskBytesPerWord*cByteLength-1 downto 0);        --! Task avalon slave data write
        iSt_write       : in std_logic;                                                         --! Task avalon slave write enable
        iSt_read        : in std_logic;                                                         --! Task avalon slave read enable
        oSt_readdata    : out std_logic_vector(gTaskBytesPerWord*cByteLength-1 downto 0);       --! Task avalon slave read data
        iSt_byteenable  : in std_logic_vector(gTaskBytesPerWord-1 downto 0);                    --! Task avalon slave byte enable

        --Avalon Slave Contol Memory
        iSc_address     : in std_logic_vector(gControlAddr-1 downto 0);                         --! FM-control avalon slave address
        iSc_writedata   : in std_logic_vector(gControlBytesPerWord*cByteLength-1 downto 0);     --! FM-control avalon slave data write
        iSc_write       : in std_logic;                                                         --! FM-control avalon slave write enable
        iSc_read        : in std_logic;                                                         --! FM-control avalon slave read enable
        oSc_readdata    : out std_logic_vector(gControlBytesPerWord*cByteLength-1 downto 0);    --! FM-control avalon slave read data
        iSc_byteenable  : in std_logic_vector(gControlBytesPerWord-1 downto 0);                 --! FM-control avalon slave byte enable

        oTXData         : out std_logic_vector(1 downto 0); --! RMII data out
        oTXDV           : out std_logic;                    --! RMII data valid

        oLED            : out std_logic_vector(1 downto 0)  --! LED out
     );
end FrameManipulator;


--! @brief FrameManipulator architecture
--! @details IP-core, which achieves different tasks of manipulations from a POWERLINK Slave
--! All further information are available in the corresponding documentations:
--!   - FM_Userdoku
--!   - FM_Developementdoku
architecture two_seg_arch of FrameManipulator is

    constant cDataBuffAddrWidth     : natural := LogDualis(gBytesOfTheFrameBuffer);             --! Address width of the frame buffer

    constant cSlaveTaskWordWidth    : natural := gTaskBytesPerWord*cByteLength;                 --! Word width of the avalon bus of the task transfer
    constant cSlaveTaskAddr         : natural := gTaskAddr;                                     --! Address width of the avalon slave for the task transfer

    constant cTaskWordWidth         : natural := cSlaveTaskWordWidth*2;                         --! doubled memory width for the internal process

    constant cTaskAddrWidth         : natural := LogDualis(gTaskCount);                         --! Address width of the task memory

    constant cCycleCntWidth         : natural := cByteLength;                                   --! maximal number of POWERLINK cycles for the series of test, 1 Byte
    constant cManiSettingWidth      : natural := 2*cTaskWordWidth-cCycleCntWidth-cByteLength;   --! Width of the task parameters


    constant cPacketAddrWidth       : natural := LogDualis(gBytesOfThePackBuffer);              --! Address width of the packet buffer
    constant cAddrMemoryWidth       : natural := LogDualis(gNumberOfPackets);                   --! Address width of the packet address-Fifo


    --signals memory interface
    signal error_addrBuffOv     : std_logic;                                        --! Error: Address buffer overflow
    signal error_frameBuffOv    : std_logic;                                        --! Error: Frame buffer overflow
    signal error_packetBuffOv   : std_logic;                                        --! Error: Packet buffer overflow
    signal error_taskConf       : std_logic;                                        --! Error: Wrong configuration

    signal rdTaskAddr           : std_logic_vector(cTaskAddrWidth-1 downto 0);      --! Read address of task memory

    signal taskSettingData      : std_logic_vector(2*cTaskWordWidth-1 downto 0);    --! Paramters of the task
    signal taskCompFrame        : std_logic_vector(cTaskWordWidth-1 downto 0);      --! Frame data of the task
    signal taskCompMask         : std_logic_vector(cTaskWordWidth-1 downto 0);      --! Frame mask of the task

    --writing data buffer
    signal wrBuffAddr           : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Write address of frame buffer
    signal wrBuffEn             : std_logic;                                        --! Write enable of frame buffer
    signal dataToBuff           : std_logic_vector(cByteLength-1 downto 0);         --! Write data of frame buffer

    signal dataInStartAddr      : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Write start address of frame buffer
    signal dataInEndAddr        : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Write end address of frame buffer

    --reading data buffer
    signal rdBuffAddr           : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Read address of frame buffer
    signal rdBuffEn             : std_logic;                                        --! Read enable of frame buffer
    signal dataFromBuff         : std_logic_vector(cByteLength-1 downto 0);         --! Read data of frame buffer

    signal dataOutStartAddr     : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Read start address of frame buffer
    signal dataOutEndAddr       : std_logic_vector(cDataBuffAddrWidth-1 downto 0);  --! Read ed address of frame buffer

    --Incoming frames
    signal startFrameProc       : std_logic;    --! Start processing the current frame
    signal frameEnded           : std_logic;    --! Incomming frame ended
    signal frameSync            : std_logic;    --! New frame started => Synchronous reset of modules

    --Test control
    signal startTest            : std_logic;    --! Start series of test
    signal stopTest             : std_logic;    --! Stop series of test
    signal clearMem             : std_logic;    --! Clear Memory
    signal testActive           : std_logic;    --! Series of test is active

    --Outgoing frames
    signal nextFrame            : std_logic;    --! New frame can be put out
    signal startNewFrame        : std_logic;    --! data for a new frame is available
    signal frameIsSoc           : std_logic;    --! current frame is a SoC

    --Manipulations
    signal maniSetting          : std_logic_vector(cManiSettingWidth-1 downto 0);   --! Setting of current manipulation
    signal taskManiEn           : std_logic;                                        --! Enable frame header manipulation
    signal taskCutEn            : std_logic;                                        --! Enable frame truncation
    signal distCrcEn            : std_logic;                                        --! Enable CRC distortion


    --! Reducing ManiSetting of cut-manipulation via alias
    alias maniSetting_cut      : std_logic_vector(cDataBuffAddrWidth-1 downto 0)
                                    is maniSetting(cDataBuffAddrWidth+cTaskWordWidth-1 downto cTaskWordWidth);


    --Safety
    signal taskSafetyEn         : std_logic;                                        --! task: safety packet manipulation
    signal safetyFrame          : std_logic;                                        --! Current Frame is a selected safety frame
    signal packetExchangeEn     : std_logic;                                        --! Start of the exchange of the safety packet
    signal packetStart          : std_logic_vector(cByteLength-1 downto 0);         --! Start of safety packet
    signal packetSize           : std_logic_vector(cByteLength-1 downto 0);         --! Size of safety packet
    signal packetData           : std_logic_vector(cByteLength-1 downto 0);         --! Data of the safety packet
    signal safetyActive         : std_logic;                                        --! safety manipulations are active
    signal exchangeData         : std_logic;                                        --! exchange packet data
    signal packetExtension      : std_logic;                                        --! Exchange will be extended for several tacts
    signal safetySetting        : std_logic_vector(cSettingSize.Safety-1 downto 0); --! Setting of the current or last safety task
    signal resetPaketBuff       : std_logic;                                        --! Resets the packet FIFO and removes the packet lag

    --Output
    signal txData               : std_logic_vector(1 downto 0); --! RMII TX-data
    signal txDv                 : std_logic;                    --! RMII TX-data-valid


begin


    --! @brief Interface to the PL-Slave with two avalon slave
    --! s_clk for the clock domain of the avSalon slaves
    --! st_...    avalon slave for the different tasks
    --! sc_...    avalon slave for the control registers
    --! FM Error collection   => iError_Addr_Buff_OV, iError_Frame_Buff_OV
    --! output of test status => oStartTest, oStopTest
    --! reading tasks         => iRdTaskAddr
    --! output tasks          => oTaskSettingData, oTaskCompFrame, oTaskCompMask
    M_Interface : entity work.Memory_Interface
    generic map(
                gSlaveTaskWordWidth     => cSlaveTaskWordWidth,
                gSlaveTaskAddrWidth     => cSlaveTaskAddr,
                gTaskWordWidth          => cTaskWordWidth,
                gTaskAddrWidth          => cTaskAddrWidth,
                gSlaveControlWordWidth  => gControlBytesPerWord*cByteLength,
                gSlaveControlAddrWidth  => gControlAddr
                )
    port map(
            iClk                    => iClk50,
            iS_clk                  => iS_clk,
            iReset                  => iReset,

            iSt_address             => iSt_address,
            iSt_writedata           => iSt_writedata,
            iSt_write               => iSt_write,
            iSt_read                => iSt_read,
            oSt_readdata            => oSt_readdata,
            iSt_byteenable          => iSt_byteenable,

            iSc_address             => iSc_address,
            iSc_writedata           => iSc_writedata,
            iSc_write               => iSc_write,
            iSc_read                => iSc_read,
            oSc_readdata            => oSc_readdata,
            iSc_byteenable          => iSc_byteenable,

            iError_addrBuffOv       => error_addrBuffOv,
            iError_frameBuffOv      => error_frameBuffOv,
            iError_packetBuffOv     => error_packetBuffOv,
            iError_taskConf         => error_taskConf,
            oStartTest              => startTest,
            oStopTest               => stopTest,
            oClearMem               => clearMem,
            oResetPaketBuff         => resetPaketBuff,
            iTestActive             => testActive,

            iRdTaskAddr             => rdTaskAddr,
            oTaskSettingData        => taskSettingData,
            oTaskCompFrame          => taskCompFrame,
            oTaskCompMask           => taskCompMask
            );



    --! @brief component for receiving the PL-Frame
    --! convert the 2bit data stream to 1 byte    => oData
    --! storing the Frames in the Data-Buffer     => oWrBuffAddr, oWrBuffEn
    --! Checking the Preamble                     => oFrameStart
    --! generating sync signal for Process-Unit   => oFrameSync
    F_Receiver : entity work.Frame_Receiver
    generic map(
                gBuffAddrWidth      => cDataBuffAddrWidth,
                gEtherTypeFilter    => cEth.FilterEtherType
                )
    port map (
            iClk                => iClk50,
            iReset              => iReset,
            iRXDV               => iRXDV,
            iRXD                => iRXD,
            iDataStartAddr      => dataInStartAddr,
            iTaskCutEn          => taskCutEn,
            iTaskCutData        => maniSetting_cut,

            oData               => dataToBuff,
            oWrBuffAddr         => wrBuffAddr,
            oWrBuffEn           => wrBuffEn,
            oDataEndAddr        => dataInEndAddr,
            oStartFrameProcess  => startFrameProc,
            oFrameEnded         => frameEnded,
            oFrameSync          => frameSync
            );



    --! @brief internal Memory for the frame data
    --! storing frame data        => iData, iWrAddress, iWrEn
    --! reading frame data        => oData, iRdAddress, iRdEn
    --! manipuating header files  => iTaskManiEn, iManiSetting, iDataStartAddr(for offset)
    --! Overflow detection        => oerror_frameBuffOv
    D_Buffer : entity work.Data_Buffer
    generic map(gDataWidth          => cByteLength,
                gDataAddrWidth      => cDataBuffAddrWidth,
                gNoOfHeadMani       => cParam.NoOfHeadMani,
                gTaskWordWidth      => cTaskWordWidth,
                gManiSettingWidth   => cManiSettingWidth)
    port map (
            iClk                    => iClk50,
            iReset                  => iReset,
            iData                   => dataToBuff,
            iWrAddress              => wrBuffAddr,
            iWrEn                   => wrBuffEn,
            oData                   => dataFromBuff,
            iRdAddress              => rdBuffAddr,
            iRdEn                   => rdBuffEn,

            iTaskManiEn             => taskManiEn,
            iManiSetting            => maniSetting,
            iDataStartAddr          => dataInStartAddr,
            oError_frameBuffOv      => error_frameBuffOv
            );



    --! @brief component for processing the frame
    --! handles the whole series of test      =>  iStartTest, iStopTest
    --! compares the frame with the tasks-mem =>  iData, iTaskSettingData,
    --!                                           iTaskCompFrame, iTaskCompMask
    --! manages the space of the data memory  =>  oDataInStartAddr, iDataInEndAddr,
    --!                                           oDataOutStartAddr,oDataOutEndAddr
    P_Unit : entity work.Process_Unit
    generic map(gDataBuffAddrWidth  =>  cDataBuffAddrWidth,
                gTaskWordWidth      =>  cTaskWordWidth,
                gTaskAddrWidth      =>  cTaskAddrWidth,
                gManiSettingWidth   =>  cManiSettingWidth,
                gSafetySetting      =>  cSettingSize.Safety,
                gCycleCntWidth      =>  cCycleCntWidth,
                gSize_Mani_Time     =>  cSettingSize.Delay,
                gNoOfDelFrames      =>  cParam.NoDelFrames)
    port map(
            iClk                => iClk50,
            iReset              => iReset,

            iStartFrameProcess  => startFrameProc,
            iFrameEnded         => frameEnded,
            iFrameSync          => frameSync,
            iNextFrame          => nextFrame,
            iStartTest          => startTest,
            iStopTest           => stopTest,
            iClearMem           => clearMem,
            iSafetyActive       => safetyActive,
            oTestActive         => testActive,
            oStartNewFrame      => startNewFrame,
            oError_taskConf     => error_taskConf,

            iData               => dataToBuff,
            iTaskSettingData    => taskSettingData,
            iTaskCompFrame      => taskCompFrame,
            iTaskCompMask       => taskCompMask,
            oRdTaskAddr         => rdTaskAddr,

            oDataInStartAddr    => dataInStartAddr,
            iDataInEndAddr      => dataInEndAddr,
            oDataOutStartAddr   => dataOutStartAddr,
            oDataOutEndAddr     => dataOutEndAddr,
            oError_addrBuffOv   => error_addrBuffOv,

            oTaskManiEn         => taskManiEn,
            oTaskCutEn          => taskCutEn,
            oDistCrcEn          => distCrcEn,
            oTaskSafetyEn       => taskSafetyEn,
            oSafetyFrame        => safetyFrame,
            oFrameIsSoc         => frameIsSoc,
            oManiSetting        => maniSetting,
            oSafetySetting      => safetySetting
            );



    --! @brief component for generating a new frame
    --! readout the data-buffer and generates a new frame
    F_Creator : entity work.Frame_Creator
    generic map(gDataBuffAddrWidth      => cDataBuffAddrWidth,
                gSafetyPackSelCntWidth  => cParam.SafetyPackSelCntWidth)
    port map (
            iClk                => iClk50,
            iReset              => iReset,

            iStartNewFrame      => startNewFrame,
            oNextFrame          => nextFrame,
            iDistCrcEn          => distCrcEn,

            iDataEndAddr        => dataOutEndAddr,
            iDataStartAddr      => dataOutStartAddr,
            iData               => dataFromBuff,
            oRdBuffEn           => rdBuffEn,
            oRdBuffAddr         => rdBuffAddr,

            iPacketExchangeEn   => packetExchangeEn,
            iPacketStart        => packetStart,
            iPacketSize         => packetSize,
            iPacketData         => packetData,
            iPacketExtension    => packetExtension,
            oExchangeData       => exchangeData,

            oTXData             => txData,
            oTXDV               => txDv
            );


    --! @brief component for safety packet manipulations
    --! stores and exchanges safety packets
    P_Buff : entity work.Packet_Buffer
    generic map(gSafetySetting      => cSettingSize.Safety,
                gPacketAddrWidth    => cPacketAddrWidth,
                gAddrMemoryWidth    => cAddrMemoryWidth)
    port map(
            iClk                    => iClk50,
            iReset                  => iReset,

            iResetPaketBuff         => resetPaketBuff,
            iStopTest               => stopTest,
            oSafetyActive           => safetyActive,
            oError_packetBuffOv     => error_packetBuffOv,

            iTaskSafetyEn           => taskSafetyEn,
            iExchangeData           => exchangeData,
            iSafetyFrame            => safetyFrame,
            iFrameIsSoc             => frameIsSoc,
            iManiSetting            => safetySetting,
            oPacketExchangeEn       => packetExchangeEn,
            oPacketExtension        => packetExtension,
            oPacketStart            => packetStart,
            oPacketSize             => packetSize,

            iFrameData              => dataFromBuff,
            oPacketData             => packetData
            );




    --! @brief register to decrease timing problems of the PHY
    --! better alternative: 100MHz clock with synchronization on the falling edge
    --! - Storing with asynchronous reset
    registers :
    process(iClk50, iReset)
    begin
        if iReset='1' then
            oTXData <= "00";
            oTXDV   <= '0';

        elsif rising_edge(iClk50) then
            oTXData <= txData;
            oTXDV   <= txDv;

        end if;
    end process;

    --output of active and abort LED:
    oLED    <= testActive & stopTest;


end two_seg_arch;