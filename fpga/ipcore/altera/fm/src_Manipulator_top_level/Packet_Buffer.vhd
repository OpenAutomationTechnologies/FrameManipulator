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
--! use global library
use work.global.all;


--! This is the entity of the top-module for exchanging and manipulating safety packets.
entity Packet_Buffer is
    generic(
            gSafetySetting      : natural :=5*cByteLength;  --!Size of safety setting
            gPacketAddrWidth    : natural := 14;            --!enough for 500 Packets with the size of 28 Bytes
            gAddrMemoryWidth    : natural := 9              --!Width of address memory, should store at least 500 addresses
            );
    port(
        clk, reset              : in std_logic;     --! clk, reset
        -- Operation signals
        iResetPaketBuff         : in std_logic;     --!Resets the packet FIFO and removes the packet lag
        iStopTest               : in std_logic;     --!abort of a series of test
        oSafetyActive           : out std_logic;    --!safety manipulations are active
        oError_Packet_Buff_OV   : out std_logic;    --!Error: Overflow packet-buffer
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

    --! @brief Control of the safety packet manipulation
    component PacketControl_FSM
        port(
            clk, reset          : in std_logic;
            iSafetyTask         : in std_logic_vector(cByteLength-1 downto 0);  --!current safety task
            iTaskSafetyEn       : in std_logic;                                 --!task: safety packet manipulation
            iStopTest           : in std_logic;                                 --!abort of a series of test
            iResetPaketBuff     : in std_logic;                                 --!Resets the packet FIFO and removes the packet lag
            oPacketExchangeEn   : out std_logic;                                --!Start of the exchange of the safety packet
            oPacketExtension    : out std_logic;                                --!Exchange will be extended for several tacts
            oSafetyActive       : out std_logic;                                --!safety manipulations are active

            iNewTask            : in std_logic;     --!current manipulation task changed
            iSn2Pre             : in std_logic;     --!SN2 packet arrives before DUT packet
            iDutNoPaGap         : in std_logic;     --!there is no gap after DUT packet
            iSnNoPaGap          : in std_logic;     --!there is no gap after SN2 packet
            iExchangeData       : in std_logic;     --!exchange packet data
            iLagReached         : in std_logic;     --!reached required number of delayed packets

            iSafetyFrame        : in std_logic;     --!current frame matches to the current or last safety task
            iFrameIsSoc         : in std_logic;     --!current frame is a SoC

            iCntEnd             : in std_logic;     --!all packets were manipulated
            oCntEn              : out std_logic;    --!enable packet counter
            oCntClear           : out std_logic;    --!reset packet counter

            oStore              : out std_logic;    --!store current frame data into memory
            oRead               : out std_logic;    --!load data from current memory
            oClonePacketEx      : out std_logic;    --!exchange current packet with clone
            oZeroPacketEx       : out std_logic;    --!exchange current packet with zero pattern
            oTwistPacketEx      : out std_logic;    --!exchange packets in opposite order

            oPacketStartSoc     : out std_logic;    --!change manipulation start to SoC Timestamp
            oPacketStartPayload : out std_logic;    --!change manipulation start to safety packet payload
            oPacketStartSN2     : out std_logic     --!change manipulation start to SN2
            );
    end component;


    --! @brief Packet Memory.
    component Packet_Memory
        generic(gPacketAddrWidth    : natural := 14;    --!enough for 500 Packets with the size of 28 Bytes
                gAddrMemoryWidth    : natural := 9);    --!Width of address memory, should store at least 500 addresses
        port(
            clk, reset              : in std_logic;
            iSafetyFrame            : in std_logic;                                         --!current frame matches to the current or last safety task
            iTaskSafety             : in std_logic_vector(cByteLength-1 downto 0);          --!current safety task
            iResetPaketBuff         : in std_logic;                                         --!Resets the packet FIFO and removes the packet lag
            oNumDelPackets          : out std_logic_vector(gAddrMemoryWidth-1 downto 0);    --!Number of delayed packets
            oError_Packet_Buff_OV   : out std_logic;                                        --!Error: Overflow packet-buffer

            iClonePacketEx          : in std_logic;    --!exchange current packet with clone
            iZeroPacketEx           : in std_logic;    --!exchange current packet with zero pattern
            iTwistPacketEx          : in std_logic;    --!exchange packets in opposite order

            iWrEn                   : in std_logic;
            iRdEn                   : in std_logic;
            iData                   : in std_logic_vector(cByteLength-1 downto 0);
            oData                   : out std_logic_vector(cByteLength-1 downto 0)
            );
    end component;


    --! @brief Counter for the safety frames
    component Basic_Cnter
        generic(
                gCntWidth   : natural := 2  --! Width of the coutner
                );
        port(
            clk, reset  : in std_logic;                                 --! clk, reset
            iClear      : in std_logic;                                 --! Synchronous reset
            iEn         : in std_logic;                                 --! Cnt Enable
            iStartValue : in std_logic_vector(gCntWidth-1 downto 0);    --! Init value
            iEndValue   : in std_logic_vector(gCntWidth-1 downto 0);    --! End value
            oQ          : out std_logic_vector(gCntWidth-1 downto 0);   --! Current value
            oOv         : out std_logic                                 --! Overflow
        );
    end component;



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
        SocReg          : std_logic;                                    --!Register for edge detection of iFrameIsSoc
        TaskSafety      : std_logic_vector(cByteLength-1 downto 0);     --!Current safety task
        PacketStart     : std_logic_vector(cByteLength-1 downto 0);     --!Start position of safety packet
        PacketSize      : std_logic_vector(cByteLength-1 downto 0);     --!Size of safety packet
        NoOfPackets     : std_logic_vector(2*cByteLength-1 downto 0);   --!Number of manipulated Packets
        Packet2Start    : std_logic_vector(cByteLength-1 downto 0);     --!Start position of SL2 packet
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                SocReg          => '0',
                                TaskSafety      => (others=>'0'),
                                PacketStart     => (others=>'0'),
                                PacketSize      => (others=>'0'),
                                NoOfPackets     => (others=>'0'),
                                Packet2Start    => (others=>'0')
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers

    -- Flags
    signal DutNoPaGap       : std_logic;    --!there is no gap after DUT packet
    signal SnNoPaGap        : std_logic;    --!there is no gap after the SN packet
    signal Sn2Pre           : std_logic;    --!SN2 packet arrives bevore DUT packet
    signal NewTask          : std_logic;    --!task has changed
    signal LagReached       : std_logic;    --!reached required number of delayed packets

    signal NumDelPackets    : std_logic_vector(gAddrMemoryWidth-1 downto 0);    --!Number of delayed packets


    -- signals for counting the safety frames
    signal FrameCntEnd      : std_logic;                                --!all packets were manipulated
    signal FrameCntClear    : std_logic;                                --!reset of cnter, when no task is active
    signal FrameCntEn       : std_logic;                                --!cnter enabled, when safety frame is incoming
    signal FrameCnt         : std_logic_vector(reg.NoOfPackets'range);  --!number of incomming frames

    -- temporary signals
    signal PacketData_temp  : std_logic_vector(oPacketData'range);      --! Temporary signal of oPacketData

    -- Data signals
    signal storeData            : std_logic;                                --! Store data stream
    signal readData             : std_logic;                                --! Send data from packet memory
    signal memoryData           : std_logic_vector(cByteLength-1 downto 0); --! Data from packet memory
    signal ClonePacketEx        : std_logic;                                --! Clone incoming safety packet
    signal ZeroPacketEx         : std_logic;                                --! Remove incomng safety packet
    signal TwistPacketEx        : std_logic;                                --! Put out safety packets in reverse order

    -- Packet manipulation Flags
    signal PacketStartSoc       : std_logic;    --! Manipulation starts at SoC Timestamp
    signal PacketStartPayload   : std_logic;    --! Manipulation starts at safety packet payload
    signal PacketStartSN2       : std_logic;    --! Manipulation starts at packet of the second SN

begin


    -----------------------------------------------------------------------------------------

    --Registers

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            reg <= cRegInit;

        elsif rising_edge(clk) then
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
        reg_next.SocReg     <= iFrameIsSoc;

        --if safty task starts (positive edge of iFrameIsSoc)
        if (reg.SocReg   = '0' and iFrameIsSoc   = '1') then
            --store Settings:
            reg_next.TaskSafety     <= iManiSetting_TaskSafety;
            reg_next.PacketStart    <= iManiSetting_PacketStart;
            reg_next.PacketSize     <= iManiSetting_PacketSize;
            reg_next.NoOfPackets    <= iManiSetting_NoOfPackets;
            reg_next.Packet2Start   <= iManiSetting_Packet2Start;

            --update task, when changed
            if  reg.TaskSafety /= iManiSetting_TaskSafety then
                NewTask <= '1';

            end if;

        end if;

    end process;

    --!there is no gap after the DUT packet
    DutNoPaGap  <= '1' when (unsigned(reg.PacketStart) =
                            unsigned(reg.Packet2Start)  +   unsigned(reg.PacketSize))
                        else '0';

    --!there is no gap after the SN packet
    SnNoPaGap   <= '1' when (unsigned(reg.Packet2Start) =
                            unsigned(reg.PacketStart)   +   unsigned(reg.PacketSize))
                        else '0';

    --!SN2 packet arrives bevore DUT packet
    Sn2Pre      <= '1' when unsigned(reg.PacketStart)   >   unsigned(reg.Packet2Start)
                        else '0';

    --!There should be at least as many packets delayed
    LagReached  <= '1' when unsigned(NumDelPackets)     >=  unsigned(reg.NoOfPackets)
                        else '0';


    --! @brief Control of the safety packet manipulation
    --! - Handles the different tasks
    --! - Controls data stream and storage of data
    Control : PacketControl_FSM
    port map(
            clk                => clk,
            reset               => reset,
            iSafetyTask         => reg.TaskSafety,
            iTaskSafetyEn       => iTaskSafetyEn,
            iStopTest           => iStopTest,
            iResetPaketBuff     => iResetPaketBuff,
            oPacketExchangeEn   => oPacketExchangeEn,
            oPacketExtension    => oPacketExtension,
            oSafetyActive       => oSafetyActive,

            iNewTask            => NewTask,
            iDutNoPaGap         => DutNoPaGap,
            iSnNoPaGap          => SnNoPaGap,
            iSn2Pre             => Sn2Pre,
            iExchangeData       => iExchangeData,
            iLagReached         => LagReached,

            iSafetyFrame        => iSafetyFrame,
            iFrameIsSoc         => iFrameIsSoc,

            iCntEnd             => FrameCntEnd,
            oCntEn              => FrameCntEn,
            oCntClear           => FrameCntClear,

            oStore              => storeData,
            oRead               => readData,
            oClonePacketEx      => ClonePacketEx,
            oZeroPacketEx       => ZeroPacketEx,
            oTwistPacketEx      => TwistPacketEx,

            oPacketStartSoc     => PacketStartSoc,
            oPacketStartPayload => PacketStartPayload,
            oPacketStartSN2     => PacketStartSN2
            );


    -----------------------------------------------------------------------------------------



    -- Manipulation Logic -------------------------------------------------------------------

    --! @brief Change of packet start and size
    --! - Changing payload at Incorrect-Data task
    --! - Collects data from SoC at Masquerade task
    --! - Collects safety packet from other SN at Insertion task
    combManiEn :
    process(reg, PacketStartPayload, PacketStartSoc, PacketStartSN2)
    begin

        oPacketStart        <= reg.PacketStart;
        oPacketSize         <= reg.PacketSize;


        if PacketStartPayload = '1' then    --manipulation of packet payload

            oPacketStart    <= std_logic_vector(cFirstPayloadByte +
                                            unsigned(reg.PacketStart));     --manipulation of the payload
            oPacketSize     <= (0=>'1',others=>'0');                        --with the first byte

        end if;


        if PacketStartSoc='1' then          --collecting of SoC time
            oPacketStart        <= cSocTimeStart;

        end if;


        if PacketStartSN2='1' then          --collecting data of SN2
            oPacketStart        <= reg.Packet2Start;

        end if;
    end process;


    -----------------------------------------------------------------------------------------


    --Counting the safety frames-------------------------------------------------------------

    --! @brief Safety frame counter
    --! - Counts every safety frame, when active
    --! - Reset at inactive manipulation
    frameCnter:Basic_Cnter
    generic map(gCntWidth   => reg.NoOfPackets'length)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => FrameCntClear,
            iEn         => FrameCntEn,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => FrameCnt,
            oOv         => open
            );


    --oOv can't be used. NoOfPackets can change anytime
    FrameCntEnd <= '1' when unsigned(FrameCnt)>=unsigned(reg.NoOfPackets) else '0';

    -----------------------------------------------------------------------------------------


    --Packet data----------------------------------------------------------------------------

    --! @brief Control of data stream
    --! - Manipulate stream at Insertion task
    --! - Pass data stream, when it will only be stored into the memory
    --! - Exchange stream with memory data, when needed
    comb_data:
    process(iFrameData, storeData, readData, memoryData, PacketStartPayload)
    begin
        PacketData_temp     <= (others=>'0');       --Also output at manipulation Loss

        if PacketStartPayload='1' then
            PacketData_temp <= not iFrameData;      --Incorrect Data with toggeling the first payload byte

        end if;


        if (storeData='1' and readData='0') then    --Pass frame data at data collection
            PacketData_temp <= iFrameData;

        end if;


        if readData='1' then
            PacketData_temp <= memoryData;

        end if;

    end process;

    oPacketData <= PacketData_temp;


    --! @brief Packet Memory
    --! - Stores safety packets
    --! - Output of safety packets in correct or reverse order
    --! - Delete packets at Loss or Delay task
    --! - Error output at overflow of the packet buffer
    PacketRAM : Packet_Memory
    generic map(gPacketAddrWidth    => gPacketAddrWidth,
                gAddrMemoryWidth    => gAddrMemoryWidth)
    port map(
            clk                     => clk,
            reset                   => reset,
            iSafetyFrame            => iSafetyFrame,
            iTaskSafety             => reg.TaskSafety,
            iResetPaketBuff         => iResetPaketBuff,
            oNumDelPackets          => NumDelPackets,
            oError_Packet_Buff_OV   => oError_Packet_Buff_OV,

            iClonePacketEx          => ClonePacketEx,
            iZeroPacketEx           => ZeroPacketEx,
            iTwistPacketEx          => TwistPacketEx,

            iWrEn                   => storeData,
            iRdEn                   => readData,
            iData                   => iFrameData,
            oData                   => memoryData
            );



end two_seg_arch;