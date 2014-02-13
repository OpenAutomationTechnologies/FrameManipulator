-------------------------------------------------------------------------------
--! @file Packet_Buffer.vhd
--! @brief Packet handler for openSAFETY tasks
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



--! This is the entity of the top-module for exchanging and manipulating safety packets.
entity Packet_Buffer is
    generic(
            gSafetySetting      : natural :=5*cByteLength;  --!Size of safety setting
            gPacketAddrWidth    : natural := 14;            --!enough for 500 Packets with the size of 28 Bytes
            gAddrMemoryWidth    : natural := 9              --!Width of address memory, should store at least 500 addresses
            );
    port(
        iClk                     : in std_logic;     --! clk
        iReset                   : in std_logic;     --! reset
        -- Operation signals
        iResetPaketBuff         : in std_logic;     --!Resets the packet FIFO and removes the packet lag
        iStopTest               : in std_logic;     --!abort of a series of test
        oSafetyActive           : out std_logic;    --!safety manipulations are active
        oError_packetBuffOv     : out std_logic;    --!Error: Overflow packet-buffer
        -- Manipulation signals
        iTaskSafetyEn           : in std_logic;                                     --!task: safety packet manipulation
        iExchangeData           : in std_logic;                                     --!exchange packet data
        iSafetyFrame            : in std_logic;                                     --!current frame matches to the current or last safety task
        iFrameIsSoc             : in std_logic;                                     --!current frame is a SoC
        iManiSetting            : in std_logic_vector(gSafetySetting-1 downto 0);   --!settings of the manipulations
        oPacketExchangeEn       : out std_logic;                                    --!Start of the exchange of the safety packet
        oPacketExtension        : out std_logic;                                    --!Exchange will be extended for several tacts
        oPacketStart            : out std_logic_vector(cByteLength-1 downto 0);     --!Start of safety packet
        oPacketSize             : out std_logic_vector(cByteLength-1 downto 0);     --!Size of safety packet
        -- Data streams
        iFrameData              : in std_logic_vector(cByteLength-1 downto 0);      --!Data of the current frame
        oPacketData             : out std_logic_vector(cByteLength-1 downto 0)      --!Data of the safety packet
     );
end Packet_Buffer;


--! @brief Packet_Buffer architecture
--! @details This is the top-module for exchanging and manipulating safety packets.
architecture two_seg_arch of Packet_Buffer is

    -- Definitions
    --!First byte of the safety Payload (+4 = Byte Number 5). If Payload doesn't exist, it's the first subframe CRC
    constant cFirstPayloadByte  : natural := 4;


    --!Start of the SoC Timestamp at Byte 21
    constant cSocTimeStart      : std_logic_vector(cByteLength-1 downto 0)
                                    := std_logic_vector(to_unsigned(21,cByteLength));



    -- Selecting safety parameters
    --! Byte 1: Start position of safety packet
    alias iManiSetting_TaskSafety      : std_logic_vector(cByteLength-1 downto 0)
                                        is iManiSetting(iManiSetting'left downto iManiSetting'left-cByteLength+1);

    --! Byte 2: Start position of safety packet
    alias iManiSetting_PacketStart      : std_logic_vector(cByteLength-1 downto 0)
                                        is iManiSetting(iManiSetting'left-cByteLength downto iManiSetting'left-2*cByteLength+1);

    --! Byte 3: Size of safety packet
    alias iManiSetting_PacketSize       : std_logic_vector(cByteLength-1 downto 0)
                                        is iManiSetting(iManiSetting'left-2*cByteLength downto iManiSetting'left-3*cByteLength+1);

    --! Byte 4+5: Number of manipulated Packets
    alias iManiSetting_NoOfPackets      : std_logic_vector(2*cByteLength-1 downto 0)
                                        is iManiSetting(iManiSetting'left-3*cByteLength downto iManiSetting'left-5*cByteLength+1);

    --! Byte 6: Start position of SL2 packet
    alias iManiSetting_Packet2Start     : std_logic_vector(cByteLength-1 downto 0)
                                        is iManiSetting(iManiSetting'left-5*cByteLength downto iManiSetting'left-6*cByteLength+1);


    --! Typedef for registers
    type tReg is record
        socReg          : std_logic;                                    --!Register for edge detection of iFrameIsSoc
        taskSafety      : std_logic_vector(cByteLength-1 downto 0);     --!Current safety task
        packetStart     : std_logic_vector(cByteLength-1 downto 0);     --!Start position of safety packet
        packetSize      : std_logic_vector(cByteLength-1 downto 0);     --!Size of safety packet
        noOfPackets     : std_logic_vector(2*cByteLength-1 downto 0);   --!Number of manipulated Packets
        packet2Start    : std_logic_vector(cByteLength-1 downto 0);     --!Start position of SL2 packet
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                socReg          => '0',
                                taskSafety      => (others=>'0'),
                                packetStart     => (others=>'0'),
                                packetSize      => (others=>'0'),
                                noOfPackets     => (others=>'0'),
                                packet2Start    => (others=>'0')
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers

    -- Flags
    signal dutNoPaGap       : std_logic;    --!there is no gap after DUT packet
    signal snNoPaGap        : std_logic;    --!there is no gap after the SN packet
    signal sn2Pre           : std_logic;    --!SN2 packet arrives bevore DUT packet
    signal newTask          : std_logic;    --!task has changed
    signal lagReached       : std_logic;    --!reached required number of delayed packets

    signal numDelPackets    : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --!Number of delayed packets


    -- signals for counting the safety frames
    signal frameCntEnd      : std_logic;                                --!all packets were manipulated
    signal frameCntClear    : std_logic;                                --!reset of cnter, when no task is active
    signal frameCntEn       : std_logic;                                --!cnter enabled, when safety frame is incoming
    signal frameCnt         : std_logic_vector(reg.NoOfPackets'range);  --!number of incomming frames

    -- temporary signals
    signal packetData_temp  : std_logic_vector(oPacketData'range);      --! Temporary signal of oPacketData

    -- Data signals
    signal storeData            : std_logic;                                --! Store data stream
    signal readData             : std_logic;                                --! Send data from packet memory
    signal memoryData           : std_logic_vector(cByteLength-1 downto 0); --! Data from packet memory
    signal clonePacketEx        : std_logic;                                --! Clone incoming safety packet
    signal zeroPacketEx         : std_logic;                                --! Remove incomng safety packet
    signal twistPacketEx        : std_logic;                                --! Put out safety packets in reverse order

    -- Packet manipulation Flags
    signal packetStartSoc       : std_logic;    --! Manipulation starts at SoC Timestamp
    signal packetStartPayload   : std_logic;    --! Manipulation starts at safety packet payload
    signal packetStartSN2       : std_logic;    --! Manipulation starts at packet of the second SN

begin


    -----------------------------------------------------------------------------------------

    --Registers

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


    --! @brief Reg_next logic for registers
    --! - Storing safety parameters at incoming SoC
    --! - Detect the changing of the safety task
    comb_reg :
    process (reg, iFrameIsSoC, iManiSetting)
    begin

        NewTask     <= '0';

        reg_next            <= reg;
        reg_next.socReg     <= iFrameIsSoc;

        --if safty task starts (positive edge of iFrameIsSoc)
        if (reg.socReg   = '0' and iFrameIsSoc   = '1') then
            --store Settings:
            reg_next.taskSafety     <= iManiSetting_TaskSafety;
            reg_next.packetStart    <= iManiSetting_PacketStart;
            reg_next.packetSize     <= iManiSetting_PacketSize;
            reg_next.noOfPackets    <= iManiSetting_NoOfPackets;
            reg_next.packet2Start   <= iManiSetting_Packet2Start;

            --update task, when changed
            if  reg.taskSafety /= iManiSetting_TaskSafety then
                NewTask <= '1';

            end if;

        end if;

    end process;

    --!there is no gap after the DUT packet
    dutNoPaGap  <= '1' when (unsigned(reg.packetStart) =
                            unsigned(reg.packet2Start)  +   unsigned(reg.packetSize))
                        else '0';

    --!there is no gap after the SN packet
    snNoPaGap   <= '1' when (unsigned(reg.packet2Start) =
                            unsigned(reg.packetStart)   +   unsigned(reg.packetSize))
                        else '0';

    --!SN2 packet arrives bevore DUT packet
    sn2Pre      <= '1' when unsigned(reg.packetStart)   >   unsigned(reg.packet2Start)
                        else '0';

    --!There should be at least as many packets delayed
    lagReached  <= '1' when unsigned(numDelPackets)     >=  unsigned(reg.noOfPackets)
                        else '0';


    --! @brief Control of the safety packet manipulation
    --! - Handles the different tasks
    --! - Controls data stream and storage of data
    Control : entity work.PacketControl_FSM
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iSafetyTask         => reg.taskSafety,
            iTaskSafetyEn       => iTaskSafetyEn,
            iStopTest           => iStopTest,
            iResetPaketBuff     => iResetPaketBuff,
            oPacketExchangeEn   => oPacketExchangeEn,
            oPacketExtension    => oPacketExtension,
            oSafetyActive       => oSafetyActive,

            iNewTask            => newTask,
            iDutNoPaGap         => dutNoPaGap,
            iSnNoPaGap          => snNoPaGap,
            iSn2Pre             => sn2Pre,
            iExchangeData       => iExchangeData,
            iLagReached         => lagReached,

            iSafetyFrame        => iSafetyFrame,
            iFrameIsSoc         => iFrameIsSoc,

            iCntEnd             => frameCntEnd,
            oCntEn              => frameCntEn,
            oCntClear           => frameCntClear,

            oStore              => storeData,
            oRead               => readData,
            oClonePacketEx      => clonePacketEx,
            oZeroPacketEx       => zeroPacketEx,
            oTwistPacketEx      => twistPacketEx,

            oPacketStartSoc     => packetStartSoc,
            oPacketStartPayload => packetStartPayload,
            oPacketStartSN2     => packetStartSN2
            );


    -----------------------------------------------------------------------------------------



    -- Manipulation Logic -------------------------------------------------------------------

    --! @brief Change of packet start and size
    --! - Changing payload at Incorrect-Data task
    --! - Collects data from SoC at Masquerade task
    --! - Collects safety packet from other SN at Insertion task
    combManiEn :
    process(reg, packetStartPayload, packetStartSoc, packetStartSN2)
    begin

        oPacketStart        <= reg.packetStart;
        oPacketSize         <= reg.packetSize;


        if packetStartPayload = '1' then    --manipulation of packet payload

            oPacketStart    <= std_logic_vector(cFirstPayloadByte +
                                            unsigned(reg.packetStart));     --manipulation of the payload
            oPacketSize     <= (0=>'1',others=>'0');                        --with the first byte

        end if;


        if packetStartSoc='1' then          --collecting of SoC time
            oPacketStart        <= cSocTimeStart;

        end if;


        if packetStartSN2='1' then          --collecting data of SN2
            oPacketStart        <= reg.packet2Start;

        end if;
    end process;


    -----------------------------------------------------------------------------------------


    --Counting the safety frames-------------------------------------------------------------

    --! @brief Safety frame counter
    --! - Counts every safety frame, when active
    --! - Reset at inactive manipulation
    frameCnter : entity work.FixCnter
    generic map(
                gCntWidth   => reg.NoOfPackets'length,
                gStartValue => (reg.NoOfPackets'range => '0'),
                gInitValue  => (reg.NoOfPackets'range => '0'),
                gEndValue   => (reg.NoOfPackets'range => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => frameCntClear,
            iEn     => frameCntEn,
            oQ      => frameCnt,
            oOv     => open
            );


    --oOv can't be used. NoOfPackets can change anytime
    frameCntEnd <= '1' when unsigned(frameCnt)>=unsigned(reg.noOfPackets) else '0';

    -----------------------------------------------------------------------------------------


    --Packet data----------------------------------------------------------------------------

    --! @brief Control of data stream
    --! - Manipulate stream at Insertion task
    --! - Pass data stream, when it will only be stored into the memory
    --! - Exchange stream with memory data, when needed
    comb_data:
    process(iFrameData, storeData, readData, memoryData, PacketStartPayload)
    begin
        packetData_temp     <= (others=>'0');       --Also output at manipulation Loss

        if packetStartPayload='1' then
            packetData_temp <= not iFrameData;      --Incorrect Data with toggeling the first payload byte

        end if;


        if (storeData='1' and readData='0') then    --Pass frame data at data collection
            packetData_temp <= iFrameData;

        end if;


        if readData='1' then
            packetData_temp <= memoryData;

        end if;

    end process;

    oPacketData <= packetData_temp;


    --! @brief Packet Memory
    --! - Stores safety packets
    --! - Output of safety packets in correct or reverse order
    --! - Delete packets at Loss or Delay task
    --! - Error output at overflow of the packet buffer
    PacketRAM : entity work.Packet_Memory
    generic map(gPacketAddrWidth    => gPacketAddrWidth,
                gAddrMemoryWidth    => gAddrMemoryWidth)
    port map(
            iClk                    => iClk,
            iReset                  => iReset,
            iSafetyFrame            => iSafetyFrame,
            iTaskSafety             => reg.TaskSafety,
            iResetPaketBuff         => iResetPaketBuff,
            oNumDelPackets          => numDelPackets,
            oError_packetBuffOv     => oError_packetBuffOv,

            iClonePacketEx          => clonePacketEx,
            iZeroPacketEx           => zeroPacketEx,
            iTwistPacketEx          => twistPacketEx,

            iWrEn                   => storeData,
            iRdEn                   => readData,
            iData                   => iFrameData,
            oData                   => memoryData
            );



end two_seg_arch;