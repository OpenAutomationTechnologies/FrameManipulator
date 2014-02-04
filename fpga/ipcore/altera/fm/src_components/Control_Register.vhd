
-------------------------------------------------------------------------------
--! @file Control_Register.vhd
--! @brief Shared interface between the Framemanipulator and its POWERLINK Slave
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


--! This is the entity for the interface between the Framemanipulator and its POWERLINK Slave
entity Control_Register is
    generic(
            gWordWidth      : natural :=cByteLength;    --! Word width of avalon bus for FM control
            gAddresswidth   : natural :=1               --! Address width of avalon bus for FM control
            );
    port(
        iClk                    : in std_logic;                                     --! clk
        iReset                  : in std_logic;                                     --! reset
        iS_clk                  : in std_logic;                                     --! Clock of the slave
        --Controls
        oStartTest              : out std_logic;                                    --! Start new series of test
        oStopTest               : out std_logic;                                    --! Stop current sereis of test
        oClearMem               : out std_logic;                                    --! clear all tasks
        oResetPaketBuff         : out std_logic;                                    --! Opertaion:aborts the current test
        iTestActive             : in std_logic;                                     --! Status: Test is active
        --Error messages
        iError_addrBuffOv       : in std_logic;                                     --! Error: Address-buffer overflow
        iError_frameBuffOv      : in std_logic;                                     --! Error: Data-buffer overflow
        iError_packetBuffOv     : in std_logic;                                     --! Error: Overflow packet-buffer
        iError_taskConf         : in std_logic;                                     --! Error: Wrong task configuration
        --avalon bus (s_clk-domain)
        iSt_addr                : in std_logic_vector(gAddresswidth-1 downto 0);              --! FM-control avalon slave address
        iSt_wrEn                : in std_logic;                                               --! FM-control avalon slave write enable
        iSt_rdEn                : in std_logic;                                               --! FM-control avalon slave read enable
        iSt_byteEn              : in std_logic_vector((gWordWidth/cByteLength)-1 DOWNTO 0);   --! FM-control avalon slave byte enable
        iSt_writeData           : in std_logic_vector(gWordWidth-1 downto 0);                 --! FM-control avalon slave data write
        oSt_ReadData            : out std_logic_vector(gWordWidth-1 downto 0)                 --! FM-control avalon slave read data
    );
end Control_Register;


--! @brief Control_Register architecture
--! @details Control register
--! - Transfer of operations from PL-Slave to FM
--! - Transfer of status- and error-flags to PL-Slave
architecture two_seg_arch of Control_Register is

    --data variables
    signal dataB_out    : std_logic_vector(gWordWidth-1 downto 0);              --! Output Operations from Avalon bus
    signal wren_b       : std_logic;                                            --! Write status endable
    signal rden_b       : std_logic;                                            --! Read operations enable
    signal addr_b       : std_logic_vector(gAddresswidth-1 downto 0);           --! Interface address

    --operation register
    signal operationByte_reg    : std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');   --! Operation register
    signal operationByte_next   : std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');   --! Next operation value

    --status and error register
    signal statusByte_reg   : std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');       --! Status register
    signal statusByte_next  : std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');       --! Next status


    signal writeStatus : std_logic;    --! writes status, when changes occurres
    signal clearErrors  : std_logic;    --! Opertaion: Clear all errors

begin

    --Register Storage---------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            statusByte_reg      <= (others=>'0');
            operationByte_reg   <= (others=>'0');

        elsif rising_edge(iClk) then
            statusByte_reg      <= statusByte_next;
            operationByte_reg   <= operationByte_next;

        end if;
    end process;


    --store test staus (first nibble) D-FF:
    statusByte_next(cSt.TestActive)<=iTestActive;

    --store errors (second nibble) RS-FF:
        --set of bits with error-signal, reset of bits with clear-operation
    statusByte_next(cSt.ErDataOv)   <= (statusByte_reg(cSt.ErDataOv)     or iError_addrBuffOv)
                                                                and not clearErrors;

    statusByte_next(cSt.ErFrameOv)  <= (statusByte_reg(cSt.ErFrameOv)    or iError_frameBuffOv)
                                                                and not clearErrors;

    statusByte_next(cSt.ErPacketOv) <= (statusByte_reg(cSt.ErPacketOv)    or iError_packetBuffOv)
                                                                and not clearErrors;

    statusByte_next(cSt.ErTaskConf) <= (statusByte_reg(cSt.ErTaskConf)    or iError_taskConf)
                                                                and not clearErrors;


    --writes new status, when changes occure
    writeStatus<='0' when statusByte_next=statusByte_reg else '1';

    wren_b<='1' when writeStatus='1' else '0'; --enable write at changes
    rden_b<='1' when writeStatus='0' else '0'; --disable read at changes

    addr_b(0)<='1' when writeStatus='1' else '0';  --Addr 1 = Write Errors, else Read Addr 0 = Operations

    --Memory----------------------------------------------------------

    --! @brief Control memory
    --! - Storing of operations and status/error flags
    ControlMem : work.DpramAdjustable
    generic map(
                gAddresswidthA  => gAddresswidth,
                gAddresswidthB  => gAddresswidth,
                gWordWidthA     => gWordWidth,
                gWordWidthB     => gWordWidth)
    port map(
            iClock_a     => iS_clk,
            iClock_b     => iClk,
            --Port A: PL-Slave
            iAddress_a   => iSt_addr,
            iData_a      => iSt_writeData,
            iWren_a      => iSt_wrEn,
            iRden_a      => iSt_rdEn,
            iByteena_a   => iSt_byteEn,
            oQ_a         => oSt_ReadData,
            --Port B: FM
            iAddress_b   => addr_b,
            iData_b      => statusByte_next,
            iWren_b      => wren_b,
            iRden_b      => rden_b,
            iByteena_b   => (others=>'1'),
            oQ_b         => dataB_out
            );


    --Operation Output------------------------------------------------
    --update register, when data is read
    operationByte_next  <= dataB_out(operationByte_next'range) when rden_b='1' else operationByte_reg;

    oStartTest  <='1' when operationByte_reg(cOp.Start)='1'   and operationByte_reg(cOp.Stop)='0'
                                                            and operationByte_reg(cOp.ClearMem)='0'
                        else '0';

    oStopTest   <='1' when operationByte_reg(cOp.Stop)='1'    or operationByte_reg(cOp.ClearMem)='1'
                                                            or statusByte_reg(7 downto 4)/="0000"
                        else '0';

    oClearMem   <='1' when operationByte_reg(cOp.ClearMem)='1' else '0';

    clearErrors <='1' when operationByte_reg(cOp.clearErrors)='1' else '0';

    oResetPaketBuff <='1' when operationByte_reg(cOp.ClearPaket)='1' else '0';

end two_seg_arch;
