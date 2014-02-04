-------------------------------------------------------------------------------
--! @file Packet_Memory.vhd
--! @brief Stores safety packets
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


--! This is the entity of the packet memory
entity Packet_Memory is
    generic(
            gPacketAddrWidth    : natural := 14;    --! enough for 500 Packets with the size of 28 Bytes
            gAddrMemoryWidth    : natural := 9      --! Width of address memory, should store at least 500 addresses
            );
    port(
        iClk                    : in std_logic;                                         --! clk
        iReset                  : in std_logic;                                         --! reset
        iSafetyFrame            : in std_logic;                                         --! current frame matches to the current or last safety task
        iTaskSafety             : in std_logic_vector(cByteLength-1 downto 0);          --! current safety task
        iResetPaketBuff         : in std_logic;                                         --! Resets the packet FIFO and removes the packet lag
        oNumDelPackets          : out std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! Number of delayed packets
        oError_packetBuffOv     : out std_logic;                                        --! Error: Overflow packet-buffer

        iClonePacketEx          : in std_logic;                                 --! exchange current packet with clone
        iZeroPacketEx           : in std_logic;                                 --! exchange current packet with zero pattern
        iTwistPacketEx          : in std_logic;                                 --! exchange packets in opposite order

        iWrEn                   : in std_logic;                                 --! Write data enable
        iRdEn                   : in std_logic;                                 --! Read data enable
        iData                   : in std_logic_vector(cByteLength-1 downto 0);  --! Data stream from packet
        oData                   : out std_logic_vector(cByteLength-1 downto 0)  --! New data stream
        );
end Packet_Memory;


--! @brief Packet Memory architecture
--! @details Memory for safety packets
--! - Stores safety packets
--! - Output of safety packets in correct or reverse order
--! - Delete packets at Loss or Delay task
--! - Error output at overflow of the packet buffer
architecture two_seg_arch of Packet_Memory is

    --!register definition
    type tReg is record
        wrEn                    : std_logic;                                        --!register for edge detection
        safetyFrame             : std_logic;                                        --!register for edge detection
        safetyFrame_posEdge_reg : std_logic;                                        --!delayed edge
        packetLag               : std_logic;                                        --!packets are delayed
        wrStart                 : std_logic_vector(gPacketAddrWidth-1 downto 0);    --!Start address for storing data into the memory
    end record;

    constant cRegInit   : tReg :=(
                                wrEn                    => '0',
                                safetyFrame             => '0',
                                safetyFrame_posEdge_reg => '0',
                                packetLag               => '0',
                                wrStart                 => (gPacketAddrWidth-1 downto 0 => '0')
                                );

    signal reg      : tReg; --! Registers
    signal reg_next : tReg; --! Next value of registers


    signal wrEn_negEdge         : std_logic;    --!neagtive edge of iWrEn
    signal safetyFrame_posEdge  : std_logic;    --!positive edge of iSafetyFrame

    signal enLagCnt             : std_logic;    --!Count up one more packet, which will be delayed


    --Packet Memory FIFO
    signal dataMemory       : std_logic_vector(cByteLength-1 downto 0);         --! Data from Memory
    signal wrStartAddr      : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Start address of next stored packet
    signal rdStartAddr      : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Start address of next read packet
    signal wrAddr           : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Write address
    signal rdAddr           : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Read address

    signal rdAddrEn         : std_logic;    --! Load start address of next packet to put out
    signal wrAddrEn         : std_logic;    --! Store current start address of stored packet

    signal errorAddrBuff    : std_logic;    --! Overlapping addresses, could happen at to big incorrect sequence task
    signal packetBuffOv     : std_logic;    --! Packet buffer overflow
    signal addrBuffOv       : std_logic;    --! Address memory overflow

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    regist:
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;


    -- Edge detections ----------------------------------------------------------------------

    reg_next.wrEn                       <= iWrEn;
    reg_next.safetyFrame                <= iSafetyFrame;
    reg_next.safetyFrame_posEdge_reg    <= safetyFrame_posEdge;


    wrEn_negEdge        <= '1' when iWrEn           = '0' and reg.wrEn          = '1'
                            else '0';


    safetyFrame_posEdge <= '1' when iSafetyFrame    = '1' and reg.safetyFrame   = '0'
                            else '0';

    -----------------------------------------------------------------------------------------



    -- Address counter ----------------------------------------------------------------------

    --! @brief Counter for memory
    --! - Select address for packet memory to store and exchange packets
    --! - Prescales the counting to fit to the stream
    PacketAddressLogic : work.Packet_MemCnter
    generic map(gPacketAddrWidth    => gPacketAddrWidth)
    port map(
            iClk            => iClk,
            iReset          => iReset,
            iWrEn           => iWrEn,
            iRdEn           => iRdEn,
            iWrStartAddr    => wrStartAddr,
            iRdStartAddr    => rdStartAddr,
            oWrAddr         => wrAddr,
            oRdAddr         => rdAddr
            );


    -----------------------------------------------------------------------------------------



    -- Memory for packets -------------------------------------------------------------------

    --! @brief Packet memory
    --! - RAM with the packet data
    PacketRAM : work.FiFo_File
    generic map(
                gAddrWidth  => gPacketAddrWidth,
                gDataWidth  => cByteLength
                )
    port map(
            iClk    => iClk,
            iWrEn   => iWrEn,
            iWrAddr => wrAddr,
            iWrData => iData,
            iRdAddr => rdAddr,
            oRdData => dataMemory
            );


    --! @brief Data output
    --! - Transferes data to the memory to the stream
    --! - Pass data, when stored packet should also be send
    --! - Kill packet at Packet-Loss or -Delay task
    combDataOut:
    process(dataMemory, iWrEn, iRdEn, reg, iZeroPacketEx, iData, iClonePacketEx)
    begin
        oData   <= dataMemory;  --Output data from Memory


        --Data output is data input, when packet will be exchanged and lag doesn't exist
        if iWrEn = '1' and iRdEn = '1'  and reg.packetLag = '0' then
            if iClonePacketEx = '0' then                                --except output is a clone
                oData   <= iData;

            end if;
        end if;


        --Zeros at packet delay manipulation
        if iZeroPacketEx= '1' then
            oData   <= (others => '0');

        end if;

    end process;

    -----------------------------------------------------------------------------------------



    -- Address logic ------------------------------------------------------------------------

    --! @brief Packet start address handling
    --! - Start address don't change at tasks without creating a delay
    --! - Store next write-start address
    --! - Define read- and write-enable for address memory
    --! - Disable reading of new packet at Repetition and Packet-Delay task
    combAddr :
    process(iClonePacketEx, iZeroPacketEx, reg, wrEn_negEdge, safetyFrame_posEdge,
            wrAddr, iTaskSafety)
    begin

        wrStartAddr     <= (others => '0');

        rdAddrEn        <= '0';
        wrAddrEn        <= '0';

        enLagCnt        <= '0';


        reg_next.wrStart    <= reg.wrStart;


        if  iTaskSafety = cTask.repetition  or
            iTaskSafety = cTask.incSeq      or
            iTaskSafety = cTask.paDelay    then

            wrStartAddr     <= reg.wrStart;
            rdAddrEn        <= reg.safetyFrame_posEdge_reg; --delayed edge, that it can be disabled with iClonePacketEx and iZeroPacketEx
            wrAddrEn        <= wrEn_negEdge;


            --Store current write adress, at the end of the access
            if WrEn_negEdge     = '1' then
                reg_next.wrStart    <= wrAddr;

            end if;


            if  iClonePacketEx  = '1'   or      --exchange packet with clone...
                iZeroPacketEx   = '1'   then    --or zero patting

                rdAddrEn        <= '0';             --reading new packet is disabled
                enLagCnt        <= wrEn_negEdge;    --one more packet will be delayed

            end if;

        end if;

    end process;



    --! @brief Start adress memory
    --! - Store write address and receive new read start address
    --! - Address output like a Fifo
    --! - Temporary Lifo output at Incorrect-Sequence
    --! - Error output at overlapping packets
    RdAddressMem : work.Packet_StartAddrMem
    generic map(
                gPacketAddrWidth    => gPacketAddrWidth,
                gAddrMemoryWidth    => gAddrMemoryWidth
                )
    port map(
            iClk            => iClk,
            iReset          => iReset,
            iResetPaketBuff => iResetPaketBuff,
            iTwistPacketEx  => iTwistPacketEx,
            oErrorAddrBuff  => errorAddrBuff,
            iWrAddrEn       => wrAddrEn,
            iRdAddrEn       => rdAddrEn,
            iAddrData       => wrAddr,
            oAddrData       => rdStartAddr
            );


    -----------------------------------------------------------------------------------------



    -- Packet Lag ---------------------------------------------------------------------------

    --! @brief Lag between packets flag
    --! - Set at occured delay of packets
    --! - Reset at memory reset
    combPacketLag :
    process(reg, EnLagCnt, iResetPaketBuff)
    begin
        reg_next.packetLag      <= reg.packetLag;

        if  EnLagCnt    = '1'   then
            reg_next.packetLag <= '1';

        end if;


        if iResetPaketBuff = '1' then
            reg_next.packetLag <= '0';

        end if;

    end process;



    --! @brief Counter for the Number of delayed packets
    --! - Overflow of counter occures at the same time as the overflow of the address memory
    lagCnter : work.Basic_Cnter
    generic map(gCntWidth   => gAddrMemoryWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => iResetPaketBuff,
            iEn         => enLagCnt,
            iStartValue => (others => '0'),
            iEndValue   => (others => '1'),
            oQ          => oNumDelPackets,
            oOv         => addrBuffOv   --Maximal number of delayed packets is also the number of stored addresses => Overflow is the same
            );


    -----------------------------------------------------------------------------------------



    -- Error Output -------------------------------------------------------------------------

    --!error, when the write address outruns the read address and the lag began
    packetBuffOv    <= '1' when unsigned(rdAddr)=unsigned(wrAddr)+1 and
                                reg.packetLag='1' else '0';

    --! Error at packet buffer and address buffer overflow
    oError_packetBuffOv   <= '1' when packetBuffOv='1' or addrBuffOv='1' or errorAddrBuff='1' else '0';

end two_seg_arch;
