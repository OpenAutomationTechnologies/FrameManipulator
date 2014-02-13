-------------------------------------------------------------------------------
--! @file Packet_StartAddrMem.vhd
--! @brief Start adress memory
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

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;



--! This is the entity of the packet start address memory
entity Packet_StartAddrMem is
    generic(
            gPacketAddrWidth    : natural := 14;    --!enough for 500 Packets with the size of 28 Bytes
            gAddrMemoryWidth    : natural := 9      --!Width of address memory, should store at least 500 addresses
            );
    port(
        iClk                : in std_logic;                                     --! clk
        iReset              : in std_logic;                                     --! reset
        iResetPaketBuff     : in std_logic;                                     --! Resets the packet FIFO
        iTwistPacketEx      : in std_logic;                                     --! exchange packets in opposite order
        oErrorAddrBuff      : out std_logic;                                    --! Error: Address-buffer is overwritten while an incorrect-sequence task
        iWrAddrEn           : in std_logic;                                     --! Write current address
        iRdAddrEn           : in std_logic;                                     --! read current address
        iAddrData           : in std_logic_vector(gPacketAddrWidth-1 downto 0); --! Address in
        oAddrData           : out std_logic_vector(gPacketAddrWidth-1 downto 0) --! Address out
        );
end Packet_StartAddrMem;

--! @brief Packet_StartAddrMem architecture
--! @details Start address memory
--! - Store write address and receive new read start address
--! - Address output like a FiFo
--! - Temporary LiFo output at Incorrect-Sequence
--! - Error output at overlapping packets
architecture two_seg_arch of Packet_StartAddrMem is

    --Last write address
    signal lastWrAddr_reg   : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! Register of last write address
    signal lastWrAddr_next  : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! Next value of write address register

    --incorrect sequence override signals
    signal rdAddr           : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! FIFO read address
    signal rdAddrBack       : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! LIFO override address
    signal clearTwistCnter  : std_logic;                                        --! clear LIFO

    --Address FIFO
    signal fifoWrAddr   : std_logic_vector(gAddrMemoryWidth-1 downto 0);        --! Write address of address-memory
    signal fifoRdAddr   : std_logic_vector(gAddrMemoryWidth-1 downto 0);        --! Read address of address-memory

begin


    -- FIFO Control -------------------------------------------------------------------------


    --! @brief Counter for address-memory write address
    --! - Select address for next memory entry
    WrAddrCnter : entity work.FixCnter
    generic map(
                gCntWidth   => gAddrMemoryWidth,
                gStartValue => (gAddrMemoryWidth-1 downto 0 => '0'),
                gInitValue  => to_unsigned(2, gAddrMemoryWidth),        --starts with value 2. It has to be a step ahead, that the read address value is correct
                gEndValue   => (gAddrMemoryWidth-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => iResetPaketBuff,
            iEn     => iWrAddrEn,
            oQ      => fifoWrAddr,
            oOv     => open);


    --! @brief Counter for address-memory read address
    --! - Select address for the output of the next start-address from memory
    RdAddrCnter : entity work.FixCnter
    generic map(
                gCntWidth   => gAddrMemoryWidth,
                gStartValue => (gAddrMemoryWidth-1 downto 0 => '0'),
                gInitValue  => (gAddrMemoryWidth-1 downto 0 => '0'),
                gEndValue   => (gAddrMemoryWidth-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => iResetPaketBuff,
            iEn     => iRdAddrEn,
            oQ      => rdAddr,
            oOv     => open
            );


    -----------------------------------------------------------------------------------------



    -- Incorrect Sequence Override ----------------------------------------------------------

    --! @brief Register for the last write address of the FIFO
    --! - Storing with asynchronous reset
    regs:
    process(iClk,iReset)
    begin
        if iReset='1' then
            lastWrAddr_reg  <= (others => '0');

        elsif rising_edge(iClk) then
            lastWrAddr_reg  <= lastWrAddr_next;

        end if;
    end process;


    --! @brief Logic for the last write address of the FIFO
    --! - Store current address at write enable signal
    combLastWrAddr:
    process(iWrAddrEn, lastWrAddr_reg, fifoWrAddr)
    begin

        lastWrAddr_next     <= lastWrAddr_reg;

        if iWrAddrEn='1' then
            lastWrAddr_next <= fifoWrAddr;

        end if;
    end process;



    --clear when incorrect sequence is inactive
    clearTwistCnter <= not iTwistPacketEx;



    --! @brief Counter for the output of packet start addresses in the reverse sequence
    --! - Start with current write address and counts down
    --! - Reset, when task is over
    TwistCnter : entity work.Basic_DownCnter
    generic map(gCntWidth   => gAddrMemoryWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => clearTwistCnter,
            iEn         => iRdAddrEn,
            iStartValue => lastWrAddr_reg,
            iEndValue   => (others => '0'),
            oQ          => rdAddrBack,
            oOv         => open
            );


    --!selection of Readaddr
    fifoRdAddr  <= rdAddrBack when iTwistPacketEx='1' else rdAddr;

    --!Address-buffer is overwritten while an incorrect-sequence task
    oErrorAddrBuff  <= '1' when rdAddrBack      = fifoWrAddr and
                                iTwistPacketEx  = '1'       else '0';

    -----------------------------------------------------------------------------------------



    -- Memory block -------------------------------------------------------------------------

    --! @brief Memory for packet start address
    --! - Normally like a FiFo
    --! - Temporary a LiFo at Incorrect-Sequence task
    RdAddressMem : entity work.FiFo_File
    generic map(
                gAddrWidth  => gAddrMemoryWidth,
                gDataWidth  => gPacketAddrWidth
                )
    port map(
            iClk    => iClk,
            iWrEn   => iWrAddrEn,
            iWrAddr => fifoWrAddr,
            iWrData => iAddrData,
            iRdAddr => fifoRdAddr,
            oRdData => oAddrData
            );


end two_seg_arch;
