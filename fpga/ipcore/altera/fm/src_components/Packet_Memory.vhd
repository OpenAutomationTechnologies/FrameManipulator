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
        clk, reset              : in std_logic;                                         --! clk, reset
        iSafetyFrame            : in std_logic;                                         --! current frame matches to the current or last safety task
        iTaskSafety             : in std_logic_vector(cByteLength-1 downto 0);          --! current safety task
        iResetPaketBuff         : in std_logic;                                         --! Resets the packet FIFO and removes the packet lag
        oNumDelPackets          : out std_logic_vector(gAddrMemoryWidth-1 downto 0);    --! Number of delayed packets
        oError_Packet_Buff_OV   : out std_logic;                                        --! Error: Overflow packet-buffer

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


    --! @brief RAM for the packet data
    component FiFo_File
        generic(
                B   : natural:=8;       --! number of Bits
                W   : natural:=8        --! number of address bits
                );
        port(
            clk     : in std_logic;                         --! clk
            iWrEn   : in std_logic;                         --! Write enable
            iWrAddr : in std_logic_vector(W-1 downto 0);    --! Write address
            iRdAddr : in std_logic_vector(W-1 downto 0);    --! Read address
            iWrData : in std_logic_vector(B-1 downto 0);    --! Write data
            oRdData : out std_logic_vector(B-1 downto 0)    --! Read data
        );
    end component;


    --! @brief Counter for the packet memory
    component Packet_MemCnter
        generic(gPacketAddrWidth    : natural := 14);   --!enough for 500 Packets with the size of 28 Bytes
        port(
            clk, reset          : in std_logic;
            iWrEn               : in std_logic;                                         --! Write memory enable
            iRdEn               : in std_logic;                                         --! Read memory enable
            iWrStartAddr        : in std_logic_vector(gPacketAddrWidth-1 downto 0);     --! Start address of stored packet
            iRdStartAddr        : in std_logic_vector(gPacketAddrWidth-1 downto 0);     --! Start address of exchanged packet
            oWrAddr             : out std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Current address of stored packet
            oRdAddr             : out std_logic_vector(gPacketAddrWidth-1 downto 0)     --! Current address of exchanged packet
            );
    end component;


    --! @brief Memory for the start address
    component Packet_StartAddrMem
        generic(
                gPacketAddrWidth    : natural := 14;    --!enough for 500 Packets with the size of 28 Bytes
                gAddrMemoryWidth    : natural := 9      --!Width of address memory, should store at least 500 addresses
                );
        port(
            clk, reset          : in std_logic;
            iResetPaketBuff     : in std_logic;                                     --!Resets the packet FIFO
            iTwistPacketEx      : in std_logic;                                     --!exchange packets in opposite order
            oErrorAddrBuff      : out std_logic;                                    --!Error: Address-buffer is overwritten while an incorrect-sequence task
            iWrAddrEn           : in std_logic;                                     --!Write current address
            iRdAddrEn           : in std_logic;                                     --!read current address
            iAddrData           : in std_logic_vector(gPacketAddrWidth-1 downto 0); --!Address in
            oAddrData           : out std_logic_vector(gPacketAddrWidth-1 downto 0) --!Address out
            );
    end component;


    --! @brief Counter to determine the lag of delayed packets
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
            clk, reset  : in std_logic;
            iClear      : in std_logic;
            iEn         : in std_logic;
            iStartValue : in std_logic_vector(gCntWidth-1 downto 0);
            iEndValue   : in std_logic_vector(gCntWidth-1 downto 0);
            oQ          : out std_logic_vector(gCntWidth-1 downto 0);
            oOv         : out std_logic
        );
    end component;


    --!register definition
    type tReg is record
        WrEn                    : std_logic;                                        --!register for edge detection
        SafetyFrame             : std_logic;                                        --!register for edge detection
        SafetyFrame_posEdge_reg : std_logic;                                        --!delayed edge
        PacketLag               : std_logic;                                        --!packets are delayed
        WrStart                 : std_logic_vector(gPacketAddrWidth-1 downto 0);    --!Start address for storing data into the memory
    end record;

    constant cRegInit   : tReg :=(
                                WrEn                    => '0',
                                SafetyFrame             => '0',
                                SafetyFrame_posEdge_reg => '0',
                                PacketLag               => '0',
                                WrStart                 => (gPacketAddrWidth-1 downto 0 => '0')
                                );

    signal reg      : tReg; --! Registers
    signal reg_next : tReg; --! Next value of registers


    signal WrEn_negEdge         : std_logic;    --!neagtive edge of iWrEn
    signal SafetyFrame_posEdge  : std_logic;    --!positive edge of iSafetyFrame

    signal EnLagCnt             : std_logic;    --!Count up one more packet, which will be delayed


    --Packet Memory FIFO
    signal DataMemory       : std_logic_vector(cByteLength-1 downto 0);         --! Data from Memory
    signal WrStartAddr      : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Start address of next stored packet
    signal RdStartAddr      : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Start address of next read packet
    signal WrAddr           : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Write address
    signal RdAddr           : std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Read address

    signal RdAddrEn         : std_logic;    --! Load start address of next packet to put out
    signal WrAddrEn         : std_logic;    --! Store current start address of stored packet

    signal ErrorAddrBuff    : std_logic;    --! Overlapping addresses, could happen at to big incorrect sequence task
    signal PacketBuffOv     : std_logic;    --! Packet buffer overflow
    signal AddrBuffOv       : std_logic;    --! Address memory overflow

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    regist:
    process(clk, reset)
    begin
        if reset='1' then
            reg <= cRegInit;

        elsif rising_edge(clk) then
            reg <= reg_next;

        end if;
    end process;


    -- Edge detections ----------------------------------------------------------------------

    reg_next.WrEn                       <= iWrEn;
    reg_next.SafetyFrame                <= iSafetyFrame;
    reg_next.SafetyFrame_posEdge_reg    <= SafetyFrame_posEdge;


    WrEn_negEdge        <= '1' when iWrEn           = '0' and reg.WrEn          = '1'
                            else '0';


    SafetyFrame_posEdge <= '1' when iSafetyFrame    = '1' and reg.SafetyFrame   = '0'
                            else '0';

    -----------------------------------------------------------------------------------------



    -- Address counter ----------------------------------------------------------------------

    --! @brief Counter for memory
    --! - Select address for packet memory to store and exchange packets
    --! - Prescales the counting to fit to the stream
    PacketAddressLogic : Packet_MemCnter
    generic map(gPacketAddrWidth    => gPacketAddrWidth)
    port map(
            clk             => clk,
            reset           => reset,
            iWrEn           => iWrEn,
            iRdEn           => iRdEn,
            iWrStartAddr    => WrStartAddr,
            iRdStartAddr    => RdStartAddr,
            oWrAddr         => WrAddr,
            oRdAddr         => RdAddr
            );


    -----------------------------------------------------------------------------------------



    -- Memory for packets -------------------------------------------------------------------

    --! @brief Packet memory
    --! - RAM with the packet data
    PacketRAM : FiFo_File
    generic map(
                W => gPacketAddrWidth,
                B => cByteLength
                )
    port map(
            clk     => clk,
            iWrEn   => iWrEn,
            iWrAddr => WrAddr,
            iWrData => iData,
            iRdAddr => RdAddr,
            oRdData => DataMemory
            );


    --! @brief Data output
    --! - Transferes data to the memory to the stream
    --! - Pass data, when stored packet should also be send
    --! - Kill packet at Packet-Loss or -Delay task
    combDataOut:
    process(DataMemory, iWrEn, iRdEn, reg, iZeroPacketEx, iData, iClonePacketEx)
    begin
        oData   <= DataMemory;  --Output data from Memory


        --Data output is data input, when packet will be exchanged and lag doesn't exist
        if iWrEn = '1' and iRdEn = '1'  and reg.PacketLag = '0' then
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
    process(iClonePacketEx, iZeroPacketEx, reg, WrEn_negEdge, SafetyFrame_posEdge,
            WrAddr, iTaskSafety)
    begin

        WrStartAddr     <= (others => '0');

        RdAddrEn        <= '0';
        WrAddrEn        <= '0';

        EnLagCnt        <= '0';


        reg_next.WrStart    <= reg.WrStart;


        if  iTaskSafety = cTask.Repetition  or
            iTaskSafety = cTask.IncSeq      or
            iTaskSafety = cTask.PaDelay    then

            WrStartAddr     <= reg.WrStart;
            RdAddrEn        <= reg.SafetyFrame_posEdge_reg; --delayed edge, that it can be disabled with iClonePacketEx and iZeroPacketEx
            WrAddrEn        <= WrEn_negEdge;


            --Store current write adress, at the end of the access
            if WrEn_negEdge     = '1' then
                reg_next.WrStart    <= WrAddr;

            end if;


            if  iClonePacketEx  = '1'   or      --exchange packet with clone...
                iZeroPacketEx   = '1'   then    --or zero patting

                RdAddrEn        <= '0';             --reading new packet is disabled
                EnLagCnt        <= WrEn_negEdge;    --one more packet will be delayed

            end if;

        end if;

    end process;



    --! @brief Start adress memory
    --! - Store write address and receive new read start address
    --! - Address output like a Fifo
    --! - Temporary Lifo output at Incorrect-Sequence
    --! - Error output at overlapping packets
    RdAddressMem : Packet_StartAddrMem
    generic map(
                gPacketAddrWidth    => gPacketAddrWidth,
                gAddrMemoryWidth    => gAddrMemoryWidth
                )
    port map(
            clk             => clk,
            reset           => reset,
            iResetPaketBuff => iResetPaketBuff,
            iTwistPacketEx  => iTwistPacketEx,
            oErrorAddrBuff  => ErrorAddrBuff,
            iWrAddrEn       => WrAddrEn,
            iRdAddrEn       => RdAddrEn,
            iAddrData       => WrAddr,
            oAddrData       => RdStartAddr
            );


    -----------------------------------------------------------------------------------------



    -- Packet Lag ---------------------------------------------------------------------------

    --! @brief Lag between packets flag
    --! - Set at occured delay of packets
    --! - Reset at memory reset
    combPacketLag:
    process(reg, EnLagCnt, iResetPaketBuff)
    begin
        reg_next.PacketLag      <= reg.PacketLag;

        if  EnLagCnt    = '1'   then
            reg_next.PacketLag <= '1';

        end if;


        if iResetPaketBuff = '1' then
            reg_next.PacketLag <= '0';

        end if;

    end process;



    --! @brief Counter for the Number of delayed packets
    --! - Overflow of counter occures at the same time as the overflow of the address memory
    lagCnter : Basic_Cnter
    generic map(gCntWidth   => gAddrMemoryWidth)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => iResetPaketBuff,
            iEn         => EnLagCnt,
            iStartValue => (others => '0'),
            iEndValue   => (others => '1'),
            oQ          => oNumDelPackets,
            oOv         => AddrBuffOv   --Maximal number of delayed packets is also the number of stored addresses => Overflow is the same
            );


    -----------------------------------------------------------------------------------------



    -- Error Output -------------------------------------------------------------------------

    --!error, when the write address outruns the read address and the lag began
    PacketBuffOv    <= '1' when unsigned(RdAddr)=unsigned(WrAddr)+1 and
                                reg.PacketLag='1' else '0';

    --! Error at packet buffer and address buffer overflow
    oError_Packet_Buff_OV   <= '1' when PacketBuffOv='1' or AddrBuffOv='1' or ErrorAddrBuff='1' else '0';

end two_seg_arch;
