-------------------------------------------------------------------------------
--! @file Process_Unit.vhd
--! @brief Handels the series of test of the Framemanipulator
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


--! This is the entity of the top-module for handling the series of test
entity Process_Unit is
    generic(gDataBuffAddrWidth  : natural := 11;                --! Address width of the frame buffer
            gTaskWordWidth      : natural := 8*cByteLength;     --! Width of task setting
            gTaskAddrWidth      : natural := 5;                 --! Address width of the task memory
            gManiSettingWidth   : natural := 14*cByteLength;    --! Width of the total task setting
            gSafetySetting      : natural := 5*cByteLength;     --! 5 Byte safety setting
            gCycleCntWidth      : natural := cByteLength;       --! Width of the counter for the current cycle
            gSize_Mani_Time     : natural := 5*cByteLength;     --! Width of setting from delay-manipulation
            gNoOfDelFrames      : natural := 255                --! Maximal number of delayed frames
            );
    port(
        iClk                : in std_logic;     --! clk
        iReset              : in std_logic;     --! reset

        iStartFrameProcess  : in std_logic;     --! valid frame received
        iFrameEnded         : in std_logic;     --! frame has reached its end
        iFrameSync          : in std_logic;     --! synchronization of the frame-data-stream
        iStartTest          : in std_logic;     --! start of a series of test
        iStopTest           : in std_logic;     --! abort of a series of test
        iClearMem           : in std_logic;     --! clear all tasks
        iNextFrame          : in std_logic;     --! a new frame could be created
        iSafetyActive       : in std_logic;     --! safety manipulations are active
        oTestActive         : out std_logic;    --! Series of Test is active => Flag for PRes
        oStartNewFrame      : out std_logic;    --! data of a new frame is available
        oError_taskConf     : out std_logic;    --! Error: Wrong task configuration

        --compare Tasks from memory with the frame
        iData               : in std_logic_vector(cByteLength-1 downto 0);          --! frame-data-stream
        iTaskSettingData    : in std_logic_vector(gTaskWordWidth*2-1 downto 0);     --! task settings
        iTaskCompFrame      : in std_logic_vector(gTaskWordWidth-1 downto 0);       --! frame-selection-data
        iTaskCompMask       : in std_logic_vector(gTaskWordWidth-1 downto 0);       --! frame-selection-mask
        oRdTaskAddr         : out std_logic_vector(gTaskAddrWidth-1 downto 0);      --! task selection

        --Start/End address of the frame-data
        oDataInStartAddr    : out std_logic_vector(gDataBuffAddrWidth-1 downto 0);  --! position of the first written byte of the next frame
        iDataInEndAddr      : in std_logic_vector(gDataBuffAddrWidth-1 downto 0);   --! position of the last written byte of the current frame
        oDataOutStartAddr   : out std_logic_vector(gDataBuffAddrWidth-1 downto 0);  --! position of the first written byte of the created frame
        oDataOutEndAddr     : out std_logic_vector(gDataBuffAddrWidth-1 downto 0);  --! position of the last written byte of the created frame
        oError_addrBuffOv   : out std_logic;                                        --! Error: Overflow of the address-buffer

        --Manipulations in other components
        oTaskManiEn         : out std_logic;                                        --! task: header manipulation
        oTaskCutEn          : out std_logic;                                        --! task: cut frame
        oDistCrcEn          : out std_logic;
        oTaskSafetyEn       : out std_logic;                                        --! task: safety packet manipulation
        oSafetyFrame        : out std_logic;                                        --! current frame matches to the current or last safety task
        oFrameIsSoc         : out std_logic;                                        --! current frame is a SoC
        oManiSetting        : out std_logic_vector(gManiSettingWidth-1 downto 0);   --! settings of the manipulations
        oSafetySetting      : out std_logic_vector(gSafetySetting-1 downto 0)       --! Setting of the current or last safety task
     );
end Process_Unit;


--! @brief Process_Unit architecture
--! @details Handels the series of test of the Framemanipulator.
--! - Selecting the different tasks and handling the series of test are done in the
--!   Manipulation_Manager.
--! - The addresses of the frame-data are allocated by the Address_Manager
--!   The delay-task is also done there
architecture two_seg_arch of Process_Unit is

    constant cDelayDataWidth    : natural :=gSize_Mani_Time+8;  --! Width of setting from delay-manipulation TODO exchange with existing generic


    signal startFrameStorage    : std_logic;    --! Store current frame
    signal testSync             : std_logic;    --! Start of test
    signal frameIsSoC           : std_logic;    --! Current frame is a SoC

    signal taskDelayEn          : std_logic;    --! Delay task is active
    signal taskCrcEn            : std_logic;    --! CRC manipulation is active

    signal maniActive           : std_logic;    --! Series of test is active

    signal maniSetting          : std_logic_vector(gManiSettingWidth-1 downto 0);   --! Task setting

    --! Needed setting for delay task
    alias aManiSetting_Delay     : std_logic_vector(cDelayDataWidth-1 downto 0)
                                    is maniSetting(cDelayDataWidth+gTaskWordWidth-1 downto gTaskWordWidth);

begin



    --! @brief manipulation selector
    --! - starts a test of series after receiving the iStartTest signal.
    --! - compares the ethernet-header-data with the task settings, filter and mask
    --! - process the drop-frame manipulation task
    --! - enables the active manipulation
    M_Manager : entity work.Manipulation_Manager
    generic map(gFrom               => cEth.StartFrameFilter,
                gTo                 => cEth.EndFrameFilter,
                gWordWidth          => gTaskWordWidth,
                gManiSettingWidth   => gManiSettingWidth,
                gSafetySetting      => gSafetySetting,
                gCycleCntWidth      => gCycleCntWidth,
                gBuffAddrWidth      => gTaskAddrWidth)
    port map(
            iClk                => iClk,
            iReset              => iReset,
            --control signals
            iStartFrameProcess  => iStartFrameProcess,
            iFrameSync          => iFrameSync,
            iStartTest          => iStartTest,
            oStartFrameStorage  => StartFrameStorage,
            iStopTest           => iStopTest,
            iClearMem           => iClearMem,
            iSafetyActive       => iSafetyActive,
            oTestSync           => testSync,
            oManiActive         => maniActive,
            oFrameIsSoc         => frameIsSoC,
            oError_taskConf     => oError_taskConf,
            --data signals
            oTaskSelection      => oRdTaskAddr,
            iData               => iData,
            iTaskSettingData    => iTaskSettingData,
            iTaskCompFrame      => iTaskCompFrame,
            iTaskCompMask       => iTaskCompMask,
            --manipulations
            oTaskDelayEn        => taskDelayEn,
            oTaskManiEn         => oTaskManiEn,
            oTaskCrcEn          => taskCrcEn,
            oTaskCutEn          => oTaskCutEn,
            oTaskSafetyEn       => oTaskSafetyEn,
            oSafetyFrame        => oSafetyFrame,
            oManiSetting        => maniSetting,
            oSafetySetting      => oSafetySetting
            );

    --Output of active Bit
    oTestActive <= maniActive or iSafetyActive;
    oFrameIsSoc <= frameIsSoc;


    --! @brief memory manager for the data-buffer
    --! - Stores the start- and end-address of valid frames (with iDataInEndAddr StartFrameStorage
    --!   and iFrameEnded)
    --! - It also allocates a new start address to the Frame-Receiver with oDataInStartAddr.
    --! - The signal oDataInStartAddr remains after receiving an invalid or dropped frames. Thus,
    --!   these frames are overwritten with the data following frame.
    --! - The delay task is also done in this component.
    --! - Addresses for new frames can be ordered from the Frame-Creator with iNextFrame
    A_Manager : entity work.Address_Manager
    generic map(gAddrDataWidth  => gDataBuffAddrWidth,
                gDelayDataWidth => cDelayDataWidth,
                gNoOfDelFrames  => gNoOfDelFrames)
    port map(
            iClk                => iClk,
            iReset              => iReset,
            --control signals
            iStartFrameStorage  => startFrameStorage,
            iFrameEnd           => iFrameEnded,
            iFrameIsSoC         => frameIsSoC,
            iTestSync           => testSync,
            iTestStop           => iStopTest,
            iNextFrame          => iNextFrame,
            oStartNewFrame      => oStartNewFrame,
            --manipulations
            iDelaySetting       => aManiSetting_Delay,
            iTaskDelayEn        => taskDelayEn,
            iTaskCrcEn          => taskCrcEn,
            oDistCrcEn          => oDistCrcEn,
            --memory management
            iDataInEndAddr      => iDataInEndAddr,
            oDataInStartAddr    => oDataInStartAddr,
            oDataOutStartAddr   => oDataOutStartAddr,
            oDataOutEndAddr     => oDataOutEndAddr,
            oError_addrBuffOv   => oError_addrBuffOv
            );


    oManiSetting    <= maniSetting;

end two_seg_arch;