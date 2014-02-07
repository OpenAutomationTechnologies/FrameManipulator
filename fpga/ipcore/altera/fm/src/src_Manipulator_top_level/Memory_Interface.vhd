-------------------------------------------------------------------------------
--! @file Memory_Interface.vhd
--! @brief Toplevel of Interface between FM and PL-Slace
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


--! This is the entity of the top-module with the interface between FM and PL-Slace
entity Memory_Interface is
    generic(
            gSlaveTaskWordWidth     : natural := 4*cByteLength; --! Word width of avalon bus for the transfer of tasks
            gSlaveTaskAddrWidth     : natural := 8;             --! Address width of avalon bus for the transfer of tasks
            gTaskWordWidth          : natural := 8*cByteLength; --! Word width of the tasks
            gTaskAddrWidth          : natural := 5;             --! Address width of the tasks
            gSlaveControlWordWidth  : natural := cByteLength;   --! Word width of avalon bus for FM control
            gSlaveControlAddrWidth  : natural := 1              --! Address width of avalon bus for FM control
            );
    port(
        iClk                    : in std_logic;                                             --! clk
        iReset                  : in std_logic;                                             --! reset
        iS_clk                  : in std_logic;                                             --! avalon bus clock domain
        --Avalon Slave Task Memory
        iSt_address              : in std_logic_vector(gSlaveTaskAddrWidth-1 downto 0);                --! Task avalon slave address
        iSt_writedata            : in std_logic_vector(gSlaveTaskWordWidth-1 downto 0);                --! Task avalon slave data write
        iSt_write                : in std_logic;                                                       --! Task avalon slave write enable
        iSt_read                 : in std_logic;                                                       --! Task avalon slave read enable
        oSt_readdata             : out std_logic_vector(gSlaveTaskWordWidth-1 downto 0);               --! Task avalon slave read data
        iSt_byteenable           : in std_logic_vector((gSlaveTaskWordWidth/cByteLength)-1 downto 0);  --! Task avalon slave byte enable
        --Avalon Slave Contol Memory
        iSc_address              : in std_logic_vector(gSlaveControlAddrWidth-1 downto 0);             --! FM-control avalon slave address
        iSc_writedata            : in std_logic_vector(gSlaveControlWordWidth-1 downto 0);             --! FM-control avalon slave data write
        iSc_write                : in std_logic;                                                       --! FM-control avalon slave write enable
        iSc_read                 : in std_logic;                                                       --! FM-control avalon slave read enable
        oSc_readdata             : out std_logic_vector(gSlaveControlWordWidth-1 downto 0);            --! FM-control avalon slave read data
        iSc_byteenable           : in std_logic_vector(gSlaveControlWordWidth/cByteLength-1 downto 0); --! FM-control avalon slave byte enable
        --status signals
        iError_addrBuffOv       : in std_logic;                                             --!Error: Overflow address-buffer
        iError_frameBuffOv      : in std_logic;                                             --!Error: Overflow data-buffer
        iError_packetBuffOv     : in std_logic;                                             --!Error: Overflow packet-buffer
        iError_taskConf         : in std_logic;                                             --!Error: Wrong task configuration
        oStartTest              : out std_logic;                                            --!start a new series of test
        oStopTest               : out std_logic;                                            --!aborts the current test
        oClearMem               : out std_logic;                                            --!clear all tasks
        oResetPaketBuff         : out std_logic;                                            --!Resets the packet FIFO and removes the packet lag
        iTestActive             : in std_logic;                                             --!Series of test is active
        --task signals
        iRdTaskAddr             : in std_logic_vector(gTaskAddrWidth-1 downto 0);           --!task selection
        oTaskSettingData        : out std_logic_vector(2*gTaskWordWidth-1 downto 0);        --!settings of the task
        oTaskCompFrame          : out std_logic_vector(gTaskWordWidth-1 downto 0);          --!header-data of the manipulated frame
        oTaskCompMask           : out std_logic_vector(gTaskWordWidth-1 downto 0)           --!mask-data of the manipulated frame
    );
end Memory_Interface;



--! @brief Memory_Interface architecture
--! @details Toplevel of Interface between FM and PL-Slace
--! - Transfer of the FM configuration via Avalon bus
--! - Transfer of the control and status register via Avalon bus
architecture two_seg_arch of Memory_Interface is

    signal clearMem : std_logic;                                    --! Start clearing the task memory
    signal clTask   : std_logic;                                    --! Clear task
    signal taskAddr : std_logic_vector(gTaskAddrWidth-1 downto 0);  --! Task address


begin


    ------------------------------------------------------------------------------------------
    --! @brief Control register
    --! - Transfer of operations from PL-Slave to FM
    --! - Transfer of status- and error-flags to PL-Slave
    C_Reg : entity work.Control_Register
    generic map(
                gWordWidth      => gSlaveControlWordWidth,
                gAddresswidth   => gSlaveControlAddrWidth
                )
    port map(
            iClk                    => iClk,
            iS_Clk                  => iS_Clk,
            iReset                  => iReset,
            --operations
            oStartTest              => oStartTest,
            oStopTest               => oStopTest,
            oClearMem               => clearMem,
            oResetPaketBuff         => oResetPaketBuff,
            iTestActive             => iTestActive,
            --Error messages
            iError_addrBuffOv       => iError_AddrBuffOv,
            iError_frameBuffOv      => iError_frameBuffOv,
            iError_packetBuffOv     => iError_packetBuffOv,
            iError_taskConf         => iError_taskConf,
            --avalon bus (s_clk-domain)
            iSt_addr                => iSc_address,
            iSt_writeData           => iSc_writedata,
            iSt_wrEn                => iSc_write,
            iSt_rdEn                => iSc_read,
            iSt_byteEn              => iSc_byteenable,
            oSt_ReadData            => oSc_readdata
            );

    oClearMem   <= ClearMem;



    ------------------------------------------------------------------------------------------
    --! @brief Clear up task memory
    --! - Deletes all tasks
    T_Mem_Res : entity work.Task_Mem_Reset
    generic map(gAddrWidth  => gTaskAddrWidth)
    port map(
            iClk            => iClk,
            iReset          => iReset,
            iRdAddress      => iRdTaskAddr,
            iClearMem       => clearMem,
            oTaskMemAddr    => taskAddr,
            oEnClear        => clTask
            );


    ------------------------------------------------------------------------------------------
    --! @brief Task memory
    --! - Port A: PL-Slave: one memory with 32bit word-width and the avalon bus clock domain
    --! - Port B: FM:   three memories with 64bit word-width and 50MHz ethernet clock domain
    --! - Task selection with iTaskAddr
    --! - Clear task with iClTaskMem
    --! - Task data: oSettingData, oCompFrame and oCompMask
    T_Memory : entity work.Task_Memory
    generic map(
                gSlaveWordWidth => gSlaveTaskWordWidth,
                gWordWidth      => gTaskWordWidth,
                gSlaveAddrWidth => gSlaveTaskAddrWidth,
                gAddresswidth   => gTaskAddrWidth
                )
    port map (
            iClk            => iClk,
            iS_clk          => iS_clk,
            --avalon bus (s_clk domain)
            iSc_addr        => iSt_address,
            iSc_writeData   => iSt_writedata,
            iSc_wrEn        => iSt_write,
            iSc_rdEn        => iSt_read,
            oSc_ReadData    => oSt_readdata,
            iSc_byteEn      => iSt_byteenable,
            --memory signals
            iClTaskMem      => clTask,
            iTaskAddr       => taskAddr,
            oSettingData    => oTaskSettingData,
            oCompFrame      => oTaskCompFrame,
            oCompMask       => oTaskCompMask
            );


end two_seg_arch;