-------------------------------------------------------------------------------
--! @file SafetyTaskSelection.vhd
--! @brief Selection of next safety task
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


--! This is the entity of the top-module for selecting of next safety task
entity SafetyTaskSelection is
    generic(
            gWordWidth      : natural :=8*cByteLength;  --!8 Byte data
            gSafetySetting  : natural :=5*cByteLength   --!5 Byte safety setting
            );
    port(
        iClk                : in std_logic;                                     --! clk
        iReset              : in std_logic;                                     --! reset
        iClearMem           : in std_logic;                                     --! clear all tasks
        iTestActive         : in std_logic;                                     --! Testcycle is active
        iSafetyActive       : in std_logic;                                     --! safety manipulations are active
        iReadEn             : in std_logic;                                     --! Read active
        iCycleNr            : in std_logic_vector(cByteLength-1 downto 0);      --! Current cycle number
        iTaskMem            : in std_logic_vector(cByteLength-1 downto 0);      --! task from memory
        iCycleMem           : in std_logic_vector(cByteLength-1 downto 0);      --! Cycle of the task
        iSettingMem         : in std_logic_vector(gSafetySetting-1 downto 0);   --! Setting of the task
        iFrameMem           : in std_logic_vector(gWordWidth-1 downto 0);       --! Frame of the task
        iMaskMem            : in std_logic_vector(gWordWidth-1 downto 0);       --! Frame mask of the task
        oError_taskConf    : out std_logic;                                    --! Error: Wrong task configuration
        oNextSafetySetting  : out std_logic_vector(gSafetySetting-1 downto 0);  --! Setting of the current or last safety task
        oNextSafetyFrame    : out std_logic_vector(gWordWidth-1 downto 0);      --! Frame of the current or last safety task
        oNextSafetyMask     : out std_logic_vector(gWordWidth-1 downto 0);      --! Mask of the current or last safety task
        oSafetyTask         : out std_logic_vector(cByteLength-1 downto 0)      --! Type of the current safety task
     );
end SafetyTaskSelection;

--! @brief SafetyTaskSelection architecture
--! @details Selection of next safety task
--! - Storing of parameter for the next task
--! - Output of frame and filter for the next safety frame
--! - Detection of wrong configuration
architecture two_seg_arch of SafetyTaskSelection is


    --Registers
    --! Typedef for registers
    type tReg is record
        readEn              : std_logic;                                    --!ReadEn for edge detection
        safetyTask          : std_logic_vector(cByteLength-1 downto 0);     --!used safety task
        TaskOut             : std_logic_vector(cByteLength-1 downto 0);     --!task output
        nextCycle           : std_logic_vector(cByteLength-1 downto 0);     --!Cycle number of next safety manipulation
        nextSetting         : std_logic_vector(iSettingMem'range);          --!Setting of next safety manipulation
        nextFrame           : std_logic_vector(iFrameMem'range);            --!Frame of next safety manipulation
        nextMask            : std_logic_vector(iMaskMem'range);             --!Frame mask of next safety manipulation
        lastPackSize        : std_logic_vector(cByteLength-1 downto 0);     --!Packet size of last manipulation
        lastNoOfPackets     : std_logic_vector(2*cByteLength-1 downto 0);   --!Number of manipulated Packets of last manipulation
        delayTaskEn         : std_logic;                                    --!Delay task is mixed with safety tasks
        safetyActive_reg    : std_logic;                                    --!iSafetyActive delayed for edge detection
        currCycle           : std_logic_vector(cByteLength-1 downto 0);     --!Start cycle of the currently active safety task
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=  (readEn              => '0',
                                    safetyTask          => (others=>'0'),
                                    taskout             => (others=>'0'),
                                    nextCycle           => (others=>'1'),--! NextCycle starts with its hightes value and will be overwritten with smaler ones
                                    nextSetting         => (others=>'0'),
                                    nextFrame           => (others=>'0'),
                                    nextMask            => (others=>'1'),--! Mask starts with ones to prevent the comparison to select a wrong frame
                                    lastPackSize        => (others=>'0'),
                                    lastNoOfPackets     => (others=>'0'),
                                    delayTaskEn         => '0',
                                    safetyActive_reg    => '0',
                                    currCycle           => (others=>'0')
                                    );


    signal reg          : tReg; --! Register
    signal reg_next     : tReg; --! Next value of register


    --Signals
    signal safetyActive_posEdge : std_logic;                                --!positive edge of iSafetyActive
    signal safetyTask           : std_logic_vector(cByteLength-1 downto 0); --!safety task from memory


        --! Byte 2: Start position of safety packet
    alias iSettingMem_PacketStart   : std_logic_vector(cByteLength-1 downto 0)
                                        is iSettingMem(iSettingMem'left-cByteLength*1 downto iSettingMem'left-2*cByteLength+1);

        --! Byte 3: Size of safety packet
    alias iSetting_PacketSize       : std_logic_vector(cByteLength-1 downto 0)
                                        is iSettingMem(iSettingMem'left-2*cByteLength downto iSettingMem'left-3*cByteLength+1);

        --! Byte 4+5: Number of manipulated Packets
    alias iSetting_NoOfPackets      : std_logic_vector(2*cByteLength-1 downto 0)
                                        is iSettingMem(iSettingMem'left-3*cByteLength downto iSettingMem'left-5*cByteLength+1);

        --! Byte 6: Start position of SL2 packet
    alias iSettingMem_Packet2Start  : std_logic_vector(cByteLength-1 downto 0)
                                        is iSettingMem(iSettingMem'left-5*cByteLength downto iSettingMem'left-6*cByteLength+1);




begin

    --CHECKING SAFETY TASK ----------------------------------------------------------------------

    --saving task, when task is a safety task
    safetyTask      <= iTaskMem when iTaskMem=cTask.repetition  or iTaskMem=cTask.paLoss  or
                                     iTaskMem=cTask.insertion   or iTaskMem=cTask.incSeq  or
                                     iTaskMem=cTask.incData     or iTaskMem=cTask.paDelay or
                                     iTaskMem=cTask.masquerade  else (iTaskMem'range => '0');

    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - Reset of parameters and next-task-detection at positive edge of iReadEn
    registers :
    process(iClk, iReset, iClearMem)
    begin
        if iReset='1' or iClearMem = '1' then
                reg <=cRegInit;

        elsif rising_edge(iClk) then
            reg<=reg_next;

            --reset of safetyTask, LastPackSize, LastNoOfPackets and NextCycle at rising edge of iReadEn
            if reg.ReadEn='0' and iReadEn='1' then          --reset register at positive edge
                reg.safetyTask      <= cRegInit.safetyTask;
                reg.nextCycle       <= cRegInit.nextCycle;
                reg.lastPackSize    <= cRegInit.lastPackSize;
                reg.lastNoOfPackets <= cRegInit.lastNoOfPackets;
                reg.delayTaskEn     <= cRegInit.delayTaskEn;

            end if;
        end if;
    end process;



    --! @brief Reg_next logic for registers
    --! - Safe parameters for error and signals for edge detection
    --! - Safe parameters of the next task
    --! - Output of safety task, when reading of the memory finished
    next_logic :
    process(reg, safetyTask, iTestActive, iSafetyActive, iReadEn, iCycleMem, iSettingMem,
            iFrameMem, iMaskMem, iCycleNr, iTaskMem, safetyActive_posEdge)
    begin
        reg_next        <= reg;

        --Storing for edge detection
        reg_next.safetyActive_reg   <= iSafetyActive;


        --storing iReadEn for edge detection
        reg_next.readEn <= iReadEn;


        --saving safety task, when register is empty
        if reg.safetyTask       = (cByteLength-1 downto 0=>'0') then
            reg_next.safetyTask <= safetyTask;

        end if;


        --saving last safety task parameters for configuration-error detection
        if safetyTask           /= (cByteLength-1 downto 0=>'0') then
            reg_next.lastPackSize       <= iSetting_packetSize;
            reg_next.lastNoOfPackets    <= iSetting_noOfPackets;

        end if;


        --store task when check is done
        if iReadEn  = '0' then
            reg_next.taskOut    <= reg.safetyTask;

        end if;


        --store start-cycle when test is active
        if safetyActive_posEdge = '1' then
            reg_next.currCycle  <= reg.nextCycle;

        elsif iSafetyActive    = '0' then  --except task is inactive
            reg_next.currCycle  <= cRegInit.currCycle;

        end if;


        --detect number of the next safety task
        if          safetyTask              /=  (cByteLength-1 downto 0=>'0')   then    --is the task a safety one
            if      unsigned(iCycleNr)      <=  unsigned(iCycleMem)     or              --does the task start now or in the future...
                    (iTestActive = '0'      and iSafetyActive = '0' )   then            --... or hasn't the test even started
                if  unsigned(reg.nextCycle) >   unsigned(iCycleMem)     then            --is it the next safety task
                    if iSafetyActive        =   '0'                     then            --is currently no safety manipulation active

                        reg_next.nextCycle          <= iCycleMem;
                        reg_next.nextSetting        <= iSettingMem;
                        reg_next.nextFrame          <= iFrameMem;
                        reg_next.nextMask           <= iMaskMem;

                    end if;
                end if;
            end if;
        end if;


        --set delay flag
        if iTaskMem = cTask.delay then
            reg_next.delayTaskEn    <= '1';

        end if;

    end process;


    --Edge detection
    safetyActive_posEdge    <= '1' when iSafetyActive = '1' and reg.safetyActive_reg = '0' else '0';

    --output
    oSafetyTask         <= reg.taskOut;
    oNextSafetySetting  <= reg.nextSetting;
    oNextSafetyFrame    <= reg.nextFrame;
    oNextSafetyMask     <= reg.nextMask;

    ---------------------------------------------------------------------------------------------



    --ERROR DETECTION ---------------------------------------------------------------------------


    --! @brief Configuration error detection
    --! - Error at different safety tasks
    --! - Error, when mixing a safety task with a delay task
    --! - Error, when packet size differs
    --! - Error, when packet number differs at Incorrect-Sequence
    --! - Error, when packets at Insertion task are overlapping
    --! - Error, when new safety task should start, but current one is still active
    comb_errortask:
    process(safetyTask, reg, iCycleNr, iCycleMem, iSafetyActive)
    begin
        oError_taskConf    <= '0';

        --error when different safety tasks are used
        if safetyTask /= reg.safetyTask then    -- if safety task is different one than the one stored
            oError_taskConf    <= '1';         --error

            if  (safetyTask     /= (cByteLength-1 downto 0=>'0') or
                reg.safetyTask  /= (cByteLength-1 downto 0=>'0'))  then    --exept one of them is zero

                oError_taskConf    <= '0';

            end if;
        end if;


        --error when safety manipulations are mixed with delay manipualtion
        if      reg.safetyTask  /=(safetyTask'range => '0') --safety task
            and reg.DelayTaskEn = '1' then                  --and delay task

            oError_taskConf    <= '1';         --error

        end if;



        --error, when packet size differs
        if      safetyTask           = reg.safetyTask               --at least two safety tasks
            and safetyTask          /= (safetyTask'range => '0')    --not empty
            and reg.lastPackSize    /= iSetting_packetSize then     --with different size

            oError_taskConf    <= '1';         --error

        end if;


        --error, when number of packets differs in Incorrect Sequence manipulation
        if      safetyTask           = reg.safetyTask               --at least two safety tasks
            and safetyTask           = cTask.incSeq                 --at Incorrect Sequence
            and reg.lastNoOfPackets /= iSetting_noOfPackets then    --with different number

            oError_taskConf    <= '1';         --error

        end if;


        --error at overlapping packts at Insertion...
        if safetyTask = cTask.insertion then

            if iSettingMem_packetStart=iSettingMem_packet2Start then    --...when both packets start at the same position
                oError_taskConf    <= '1';         --error
            end if;

            --Packet 2 comes first, but packet 1 starts within its range
            if unsigned(iSettingMem_packetStart)>unsigned(iSettingMem_packet2Start) then
                if unsigned(iSettingMem_packetStart)<unsigned(iSettingMem_packet2Start)+unsigned(iSetting_packetSize) then

                    oError_taskConf    <= '1';         --error

                end if;

            else    --Packet 1 comes first, but packet 2 starts within its range
                if unsigned(iSettingMem_packet2Start)<unsigned(iSettingMem_packetStart)+unsigned(iSetting_packetSize) then

                    oError_taskConf    <= '1';         --error

                end if;
            end if;

        end if;


        --check of task overlap: a new safety task has to start, but the last one is still active:
        if              iSafetyActive   =   '1'                             then    --if a safety task is active
            if          safetyTask      /=  (cByteLength-1 downto 0=>'0')   then    --the incomming task a safety one...
                if      iCycleNr        =   iCycleMem                       then    --...of this PL-cycle
                    if  reg.currCycle   /=  iCycleMem                       and     --...which isn't to active one
                        reg.currCycle   /=  cRegInit.currCycle              then    --...while the active register isn't empty

                        oError_taskConf    <= '1';         --error

                    end if;
                end if;
            end if;
        end if;

    end process;


    ---------------------------------------------------------------------------------------------


end two_seg_arch;