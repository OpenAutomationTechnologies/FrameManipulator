-------------------------------------------------------------------------------
--! @file Task_Memory.vhd
--! @brief Memory for the different manipulation tasks
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

--! This is the entity of the task memory
entity Task_Memory is
    generic(gSlaveWordWidth : natural := 4*cByteLength; --! Word width of avalon bus for the transfer of tasks
            gWordWidth      : natural := 8*cByteLength; --! Word width of the tasks
            gSlaveAddrWidth : natural := 11;            --! Address width of avalon bus for the transfer of tasks
            gAddresswidth   : natural := 8              --! Address width of the tasks
            );
    port(
        iClk            : in std_logic;    --! FM clock
        --avalon bus (s_clk domain)
        iS_clk          : in std_logic;                                                   --! Clock of the slave
        iSc_addr         : in std_logic_vector(gSlaveAddrWidth-1 downto 0);                --! Task avalon slave address
        iSc_wrEn         : in std_logic;                                                   --! Task avalon slave write enable
        iSc_rdEn         : in std_logic;                                                   --! Task avalon slave read enable
        iSc_byteEn       : in std_logic_vector((gSlaveWordWidth/cByteLength)-1 DOWNTO 0);  --! Task avalon slave byte enable
        iSc_writeData    : in std_logic_vector(gSlaveWordWidth-1 downto 0);                --! Task avalon slave data write
        oSc_ReadData     : out std_logic_vector(gSlaveWordWidth-1 downto 0);               --! Task avalon slave read data
        --memory signals
        iTaskAddr       : in std_logic_vector(gAddresswidth-1 downto 0);        --! Address of the current task
        iClTaskMem      : in std_logic;                                         --! Delete task
        oSettingData    : out std_logic_vector(2*gWordWidth-1 downto 0);        --! output task setting
        oCompFrame      : out std_logic_vector(gWordWidth-1 downto 0);          --! output task frame
        oCompMask       : out std_logic_vector(gWordWidth-1 downto 0)           --! output task
    );
end Task_Memory;



--! @brief Task_Memory architecture
--! @details Memory for the different manipulation tasks
--! - Shared memory interface between the Framemanipulator and its POWERLINK Slave
--! - Stores the tasks
--! - It consists of 4 DPRams, which act like one big memory for the avalon slave. The
--!   four DPRams are selected by the first two bits of the avalon slave address with
--!   a data size of 32 bit.
--! - The Framemanipulator receives the data of all 4 DPRams at once with a word size
--!   of 64 bits.
architecture two_seg_arch of Task_Memory is

    signal slaveWriteEn     : std_logic_vector(3 downto 0);               --! write enable
    signal slaveSelEn       : std_logic_vector(2 downto 0);               --! DPRam Selection
    signal slaveWrTaskAddr  : std_logic_vector(gAddresswidth downto 0);   --! write address
    signal rdTaskMem        : std_logic;                                  --! read task

    --data output for PL-Slave
    signal slaveReadData0   : std_logic_vector(gWordWidth/2-1 downto 0);  --! data of PDRam 0
    signal slaveReadData1   : std_logic_vector(gWordWidth/2-1 downto 0);  --! data of PDRam 1
    signal slaveReadData2   : std_logic_vector(gWordWidth/2-1 downto 0);  --! data of PDRam 2
    signal slaveReadData3   : std_logic_vector(gWordWidth/2-1 downto 0);  --! data of PDRam 3

begin

    --Isolate the selection of the Buffers from the address line----------------------------------------
    slaveSelEn      <= iSc_addr(iSc_addr'left downto iSc_addr'left-1)&iSc_wrEn; --! first two address-bits => DPRam selection + WriteEnable
    slaveWrTaskAddr <= iSc_addr(gAddresswidth downto 0);                     --! remaining address-bits => real address



    --Aktivate the different Buffer for Port A ---------------------------------------------------------
    with slaveSelEn select --last bit=1 => write
        slaveWriteEn<=  "0001" when "001",  --write 00 => PDRam 0
                        "0010" when "011",  --write 01 => PDRam 1
                        "0100" when "101",  --write 10 => PDRam 2
                        "1000" when "111",  --write 11 => PDRam 3
                        "0000" when others;


    rdTaskMem   <= not iClTaskMem;


    --Mapping of the four Buffers ---------------------------------------------------------------------

    --! @brief First Memory
    --! - Object 0x3001 Setting 1
    ManiDataBuffer1 : entity work.DpramAdjustable
    generic map(
                gAddresswidthA  => gAddresswidth+1,
                gAddresswidthB  => gAddresswidth,
                gWordWidthA     => gWordWidth/2,
                gWordWidthB     => gWordWidth
                )
    port map(
            iClock_a    => iS_clk,
            iClock_b    => iClk,
            --port A PL-Slave
            iAddress_a  => slaveWrTaskAddr,
            iByteena_a  => iSc_byteEn,
            iData_a     => iSc_writeData,
            iWren_a     => slaveWriteEn(0),
            iRden_a     => iSc_rdEn,
            --port B FM
            iAddress_b  => iTaskAddr,
            iByteena_b  => (others=>'1'),
            iData_b     => (others=>'0'),
            iWren_b     => iClTaskMem,
            iRden_b     => rdTaskMem,
            --output
            oQ_a        => slaveReadData0,
            oQ_b        => oSettingData(2*gWordWidth-1 downto gWordWidth)   --first 8Byte
            );


    --! @brief Second Memory
    --! - Object 0x3002 Setting 2
    ManiDataBuffer2 : entity work.DpramAdjustable
    generic map(
                gAddresswidthA  => gAddresswidth+1,
                gAddresswidthB  => gAddresswidth,
                gWordWidthA     => gWordWidth/2,
                gWordWidthB     => gWordWidth
                )
    port map(
            iClock_a    => iS_clk,
            iClock_b    => iClk,
            --port A PL-Slave
            iAddress_a  => slaveWrTaskAddr,
            iByteena_a  => iSc_byteEn,
            iData_a     => iSc_writeData,
            iWren_a     => slaveWriteEn(1),
            iRden_a     => iSc_rdEn,
            --port B FM
            iAddress_b  => iTaskAddr,
            iByteena_b  => (others=>'1'),
            iData_b     => (others=>'0'),
            iWren_b     => iClTaskMem,
            iRden_b     => rdTaskMem,
            --output
            oQ_a        => slaveReadData1,
            oQ_b        => oSettingData(gWordWidth-1 downto 0)  --second 8Byte
            );


    --! @brief Third Memory
    --! - Object 0x3003 Frame data
    CompFrameBuffer : entity work.DpramAdjustable
    generic map(
                gAddresswidthA  => gAddresswidth+1,
                gAddresswidthB  => gAddresswidth,
                gWordWidthA     => gWordWidth/2,
                gWordWidthB     => gWordWidth
                )
    port map(
            iClock_a    => iS_clk,
            iClock_b    => iClk,
            --port A PL-Slave
            iAddress_a  => slaveWrTaskAddr,
            iByteena_a  => iSc_byteEn,
            iData_a     => iSc_writeData,
            iWren_a     => slaveWriteEn(2),
            iRden_a     => iSc_rdEn,
            --port B FM
            iAddress_b  => iTaskAddr,
            iByteena_b  => (others=>'1'),
            iData_b     => (others=>'0'),
            iWren_b     => iClTaskMem,
            iRden_b     => rdTaskMem,
            --output
            oQ_a        => slaveReadData2,
            oQ_b        => oCompFrame
            );


    --! @brief Fourth Memory
    --! - Object 0x3003 Mask data
    CompMaskBuffer : entity work.DpramAdjustable
    generic map(
                gAddresswidthA  => gAddresswidth+1,
                gAddresswidthB  => gAddresswidth,
                gWordWidthA     => gWordWidth/2,
                gWordWidthB     => gWordWidth
                )
    port map(
            iClock_a     => iS_clk,
            iClock_b     => iClk,
            --port A PL-Slave
            iAddress_a   => slaveWrTaskAddr,
            iByteena_a   => iSc_byteEn,
            iData_a      => iSc_writeData,
            iWren_a      => slaveWriteEn(3),
            iRden_a      => iSc_rdEn,
            --port B FM
            iAddress_b   => iTaskAddr,
            iByteena_b   => (others=>'1'),
            iData_b      => (others=>'0'),
            iWren_b      => iClTaskMem,
            iRden_b      => rdTaskMem,
            --output
            oQ_a         => slaveReadData3,
            oQ_b         => oCompMask
            );



    --Select the Output data for Port A ----------------------------------------------------------------
    with slaveSelEn select --last bit=0 => read
        oSc_ReadData<=   slaveReadData0 when "000", --read 00 => DPRam 0
                        slaveReadData1 when "010", --read 01 => DPRam 1
                        slaveReadData2 when "100", --read 10 => DPRam 2
                        slaveReadData3 when "110", --read 11 => DPRam 3
                        (others=>'0') when others;



end two_seg_arch;
