-------------------------------------------------------------------------------
--! @file Manipulation_Manager.vhd
--! @brief Selection of the currrent task
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


--! This is the entity of the module to select the current manipulation task
entity Manipulation_Manager is
    generic(
            gFrom               : natural := 15;                --! Start byte for checking the frame header
            gTo                 : natural := 22;                --! Last byte for checking the frame header
            gWordWidth          : natural := 8*cByteLength;     --! Width of the task objects
            gManiSettingWidth   : natural := 14*cByteLength;    --! Width of the total setting
            gSafetySetting      : natural := 5*cByteLength;     --! Width of the used setting for safety manipulations
            gCycleCntWidth      : natural := 8;                 --! Width of the counter for the current cycle
            gBuffAddrWidth      : natural := 5                  --! Address width of the task memory
        );
    port(
        iClk                : in std_logic;     --! clk
        iReset              : in std_logic;     --! reset
        --control signals
        iStartFrameProcess  : in std_logic;     --! Valid Frame received for processing
        iFrameSync          : in std_logic;     --! sync for collecting header-data
        iStartTest          : in std_logic;     --! start series of test
        iStopTest           : in std_logic;     --! stop test
        iClearMem           : in std_logic;     --! clear all tasks
        iSafetyActive       : in std_logic;     --! safety manipulations are active
        oStartFrameStorage  : out std_logic;    --! valid frame was compared and can be stored
        oTestSync           : out std_logic;    --! sync of a new test
        oManiActive         : out std_logic;    --! series of test is currently running
        oFrameIsSoc         : out std_logic;    --! current frame is a SoC
        oError_taskConf    : out std_logic;    --! Error: Wrong task configuration
        --data signals
        iData               : in std_logic_vector(cByteLength-1 downto 0);          --! frame-stream
        iTaskSettingData    : in std_logic_vector(2*gWordWidth-1 downto 0);         --! settings for the tasks
        iTaskCompFrame      : in std_logic_vector(gWordWidth-1 downto 0);           --! frame-header-data for the tasks
        iTaskCompMask       : in std_logic_vector(gWordWidth-1 downto 0);           --! frame-mask for the tasks
        oTaskSelection      : out std_logic_vector(gBuffAddrWidth-1 downto 0);      --! Task selection
        --manipulations
        oTaskDelayEn        : out std_logic;                                        --! task: delay frame
        oTaskManiEn         : out std_logic;                                        --! task: manipulate header
        oTaskCrcEn          : out std_logic;                                        --! task: distort crc
        oTaskCutEn          : out std_logic;                                        --! task: truncate frame
        oTaskSafetyEn       : out std_logic;                                        --! task: safety packet manipulation
        oSafetyFrame        : out std_logic;                                        --! current frame matches to the current or last safety task
        oManiSetting        : out std_logic_vector(gManiSettingWidth-1 downto 0);   --! manipulation setting
        oSafetySetting      : out std_logic_vector(gSafetySetting-1 downto 0)       --! Setting of the current or last safety task
     );
end Manipulation_Manager;



--! @brief Manipulation_Manager architecture
--! @details component for selecting the right task and passing trough the
--! manipulations to the other components
--! - It starts counting the following POWERLINK-cycles by detecting the SoCs.
--!   It is reading the tasks and selecting the fitting one.
architecture two_seg_arch of Manipulation_Manager is

    --! Typedef for registers
    type tReg is record
        startTest       : std_logic;                                                --! Register for edge detection of iStartTest
        testActive      : std_logic;                                                --! Test is active
        maniSetting     : std_logic_vector(2*gWordWidth-gCycleCntWidth-1 downto 0); --!settings for the task
        cycleLastTask   : std_logic_vector(gCycleCntWidth-1 downto 0);              --! cycle number of the last task
    end record;


    --! Init for registers
    --! - Manipulator should run for at least one PL cycle
    constant cRegInit   : tReg :=(
                                startTest       => '0',
                                testActive      => '0',
                                maniSetting     => (others => '0'),
                                cycleLastTask   => (0=>'1', others => '0')
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers


    --Test signals
    signal testSync : std_logic;  --!reset for new test at positive edge of iStartTest

    --collector signals
    signal collFinished         : std_logic;                                    --! collector received the header data
    signal headerData           : std_logic_vector(gWordWidth-1 downto 0);      --! received header data
    signal frameIsSoc           : std_logic;                                    --! Current frame is a SoC

    --memory signals
    signal readEn               : std_logic;                                    --! read task-buffer
    signal taskSelection        : std_logic_vector(gBuffAddrWidth-1 downto 0);  --! task address

    --cycle variables
    signal currentCycle         : std_logic_vector(gCycleCntWidth-1 downto 0);  --! current PL Cycle of the Ssries of test

    --task variables
    signal taskEmpty            : std_logic;                                    --! current task consists of zeroes => reached end of task
    signal headerConformance    : std_logic;                                    --! frame header fits with the frame of the task
    signal selectedTask         : std_logic;                                    --! conformance with header an POWRLINK-cycle
    signal compFinished         : std_logic;                                    --! all tasks were compared

    --manipulation tasks:
    signal taskDropEn           : std_logic;                                    --! drop frame
    signal safetyTask           : std_logic_vector(cByteLength-1 downto 0);     --! safety task of the test


    --! Manipulation setting of whole setting:
    alias iTaskSettingData_maniSetting  : std_logic_vector(reg.maniSetting'range)
                                            is iTaskSettingData(reg.maniSetting'left downto 0);

    --! Manipulation setting for safety packets
    alias iTaskSettingData_safety       : std_logic_vector(gSafetySetting-1 downto 0)
                                            is iTaskSettingData(reg.maniSetting'left downto reg.maniSetting'left-gSafetySetting+1);

    --! Cycle of whole setting
    alias iTaskSettingData_cycle        : std_logic_vector(gCycleCntWidth-1 downto 0)
                                            is iTaskSettingData(iTaskSettingData'left downto iTaskSettingData'left-gCycleCntWidth+1);

    --! Task of whole setting
    alias iTaskSettingData_task         : std_logic_vector(cByteLength-1 downto 0)
                                            is iTaskSettingData(reg.maniSetting'left downto reg.maniSetting'left-cByteLength+1);

    --! Setting of the selected manipulation:
    alias maniSetting_task              : std_logic_vector(cByteLength-1 downto 0)
                                            is reg.ManiSetting(reg.maniSetting'left downto reg.maniSetting'left-cByteLength+1);


    -- safety tasks:
    signal nextSafetyFrame     : std_logic_vector(gWordWidth-1 downto 0);   --! data of next safety frame
    signal nextSafetyMask      : std_logic_vector(gWordWidth-1 downto 0);   --! mask of next safety frame

begin

    --MENAGER CONTROL (start, stop, ...)-------------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;


    --! @brief Next register value logic
    --! - Set test-active at test start.
    --!   Reset at end of cycle counter, last task or an abort
    --! - Set ManiSetting when the matching task of the current frame was found.
    --!   Reset when new frame arrives
    --! - storing the last cycle of all tasks
    nextComb :
    process(reg, iStartTest, TestSync, iStopTest, currentCycle, selectedTask, iFrameSync)
    begin
        reg_next    <= reg;

        reg_next.startTest  <= iStartTest;


        --end of cycle counter
        if currentCycle=(gCycleCntWidth-1 downto 0 => '1')  then
            reg_next.testActive <= '0';

        end if;


        --last task was processed (current>lastTask)
        if unsigned(currentCycle)>unsigned(reg.cycleLastTask)  then
            reg_next.testActive <= '0';

        end if;

        --start of a test
        if testSync='1' then
            reg_next.testActive <= '1';

        end if;

        --test is stoped by an operation
        if iStopTest='1'  then
            reg_next.testActive <= '0';

        end if;

        --Set Mani setting at start of Frame
        if (selectedTask='1') then          --task fits => store setting
            reg_next.maniSetting    <= iTaskSettingData_maniSetting;

        elsif (iFrameSync='1') then         --reset => delete setting
            reg_next.maniSetting    <= cRegInit.maniSetting;

        end if;


        --Reset, when test inactive
        if reg.TestActive = '0' then
            reg_next.CycleLastTask  <= cRegInit.CycleLastTask;

        end if;

        --store the last task cycle
        if unsigned(iTaskSettingData_Cycle) > unsigned(reg.CycleLastTask) then
            reg_next.CycleLastTask  <= iTaskSettingData_Cycle;

        end if;

    end process;


    --Test reset after positive edge of start signal
    testSync    <= '1' when (iStartTest = '1' and reg.startTest = '0')  else '0';
    oTestSync   <= testSync;


    --! @brief Soc Counter: counts PL-cycles as long as TestActive is '1'
    CycleCnter : entity work.SoC_Cnter
    generic map(gCnterWidth => gCycleCntWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iTestSync   => testSync,
            iFrameSync  => iFrameSync,
            iEn         => reg.TestActive,
            iData       => iData,
            oFrameIsSoc => frameIsSoc,
            oSocCnt     => currentCycle
            );


    --output of SoC information, when comparison of the manipulation tasks has finished
    -- => it can be used for storing setting information
    oFrameIsSoc <= frameIsSoc when compFinished='1' else '0';

    ---------------------------------------------------------------------------------------------



    --DATA GATHERING (collecting header-data, reading tasks)--------------------------------------

    --! @brief Header data collector
    FC : entity work.Frame_collector
    generic map(
                gFrom   => gFrom,
                gTo     => gTo
                )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iData               => iData,
            iSync               => iFrameSync,
            oFrameData          => headerData,
            oCollectorFinished  => collFinished
            );


    --enable task-reading, when header-data are ready and the manager is still comparing the tasks
    ReadEn  <= '1' when (collFinished='1' and compFinished='0') else '0';


    --! @brief logic for reading the task-data
    CommandRL : entity work.read_logic
    generic map(
                gPrescaler  => 1,
                gAddrWidth  => gBuffAddrWidth
                )
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iEn         => readEn,
            iSync       => iFrameSync,
            iStartAddr  => (others=>'0'),
            oAddr       => taskSelection
            );


    --Comparing has finished, when the last entry or an gap was reached
    compFinished<= '1' when (to_integer(unsigned(taskSelection))+1=2**gBuffAddrWidth)
                                or TaskEmpty='1' else '0';

    --current task is empty => gap
    taskEmpty<= '1' when iTaskSettingData=(iTaskSettingData'range=>'0')
                            and iTaskCompFrame=(iTaskCompFrame'range=>'0')
                            and iTaskCompMask=(iTaskCompMask'range=>'0') else '0';
    ---------------------------------------------------------------------------------------------



    --TASK SELECTING(compare of setting and cycle number)----------------------------------------

    --Header fits with the task-data
    headerConformance <= '1' when ((headerData xor iTaskCompFrame)
                                    and iTaskCompMask)=(headerData'range=>'0') else '0';


    --Task Cycle=current cycle => Frame fits with selected task
    selectedTask<= '1' when (headerConformance='1' and collFinished='1' and reg.testActive='1'
                        and (currentCycle=iTaskSettingData_Cycle or iTaskSettingData_Cycle=X"FF") ) else '0';


    ---------------------------------------------------------------------------------------------



    --DATA HANDLING (select the right manipulation, output)----------------------------------

    --Second Byte: Definnition of the kind of manipulation with the second Byte
    taskDropEn<=    '1' when maniSetting_task = cTask.drop      else '0';
    oTaskDelayEn<=  '1' when maniSetting_task = cTask.delay     else '0';
    oTaskCrcEn<=    '1' when maniSetting_task = cTask.crc       else '0';
    oTaskManiEn<=   '1' when maniSetting_task = cTask.mani      else '0';
    oTaskCutEn<=    '1' when maniSetting_task = cTask.cut       else '0';
    oTaskSafetyEn<= '1' when (maniSetting_task = safetyTask and safetyTask /= (safetyTask'range=>'0'))
                        else '0';

    --output
    oManiSetting    <= reg.maniSetting(oManiSetting'left downto 0);
    oTaskSelection  <= taskSelection;
    oManiActive     <= reg.testActive;

    --frame can be stored, after comparing and not dropping the frame
    oStartFrameStorage<=iStartFrameProcess and compFinished and not taskDropEn;

    ---------------------------------------------------------------------------------------------



    -- SAFETY TASK DETECTION --------------------------------------------------------------------


    --! @brief Check of safety task
    SafetyTaskCheck : entity work.SafetyTaskSelection
    generic map(
                gWordWidth      => gWordWidth,
                gSafetySetting  => gSafetySetting
                )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iClearMem           => iClearMem,
            iTestActive         => reg.TestActive,
            iSafetyActive       => iSafetyActive,
            iReadEn             => readEn,
            iCycleNr            => currentCycle,
            iTaskMem            => iTaskSettingData_Task,
            iCycleMem           => iTaskSettingData_Cycle,
            iSettingMem         => iTaskSettingData_Safety,
            iFrameMem           => iTaskCompFrame,
            iMaskMem            => iTaskCompMask,
            oError_taskConf     => oError_taskConf,
            oNextSafetySetting  => oSafetySetting,
            oNextSafetyFrame    => nextSafetyFrame,
            oNextSafetyMask     => nextSafetyMask,
            oSafetyTask         => safetyTask);

    --current frame matches to the current or last safety task
    oSafetyFrame    <= '1' when ((headerData xor nextSafetyFrame) and nextSafetyMask)
                                =(headerData'range=>'0')
                            and compFinished = '1'                              --when comparison has finished ...
                            and nextSafetyMask/=(nextSafetyMask'range=>'0')     --... and frame mask is valid
                            else '0';


end two_seg_arch;