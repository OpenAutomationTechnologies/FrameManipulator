-------------------------------------------------------------------------------
--! @file Packet_MemCnter.vhd
--! @brief Counter for memory
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


--! This is the entity of the address counter for the packet memory
entity Packet_MemCnter is
    generic(gPacketAddrWidth    : natural := 14);   --! enough for 500 Packets with the size of 28 Bytes
    port(
        clk, reset          : in std_logic;                                         --! clk, reset
        iWrEn               : in std_logic;                                         --! Write memory enable
        iRdEn               : in std_logic;                                         --! Read memory enable
        iWrStartAddr        : in std_logic_vector(gPacketAddrWidth-1 downto 0);     --! Start address of stored packet
        iRdStartAddr        : in std_logic_vector(gPacketAddrWidth-1 downto 0);     --! Start address of exchanged packet
        oWrAddr             : out std_logic_vector(gPacketAddrWidth-1 downto 0);    --! Current address of stored packet
        oRdAddr             : out std_logic_vector(gPacketAddrWidth-1 downto 0)     --! Current address of exchanged packet
        );
end Packet_MemCnter;


--! @brief PacketMemCnter architecture
--! @details Counter for memory
--! - Select address for packet memory to store and exchange packets
--! - Prescales the counting to fit to the stream
architecture two_seg_arch of Packet_MemCnter is

    --! @brief Counter for prescaler and address selection
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

    --clear signal of counters
    signal WrCntClear   : std_logic;    --! Clear write address counter
    signal RdCntClear   : std_logic;    --! Clear read address counter

    --Prescaler of address counters
    signal WrPreCnt     : std_logic;    --! Prescaler of write address
    signal RdPreCnt     : std_logic;    --! Prescaler of read address


begin


    --Clear Counter, when memory is unused
    WrCntClear  <= not iWrEn;
    RdCntClear  <= not iRdEn;


    --! @brief Prescaler for write address
    --! - Factor four to match stream
    WrPre : Basic_Cnter
    generic map(gCntWidth   => 2)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => WrCntClear,
            iEn         => '1',
            iStartValue => "00",
            iEndValue   => (others => '1'),
            oQ          => open,
            oOv         => WrPreCnt
            );


    --! @brief Counter for write address
    --! - Select address for packet memory to store packets
    WrCnter : Basic_Cnter
    generic map(gCntWidth   => gPacketAddrWidth)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => WrCntClear,
            iEn         => WrPreCnt,
            iStartValue => iWrStartAddr,
            iEndValue   => (others => '1'),
            oQ          => oWrAddr,
            oOv         => open
            );



    --! @brief Prescaler for read address
    --! - Factor four to match stream
    --! - Start with the value of one to compensate the delay of the memory
    RdPre : Basic_Cnter
    generic map(gCntWidth   => 2)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => RdCntClear,
            iEn         => '1',
            iStartValue => "01",
            iEndValue   => (others => '1'),
            oQ          => open,
            oOv         => RdPreCnt
            );


    --! @brief Counter for read address
    --! - Select address for packet memory to exchange packets
    RdCnter : Basic_Cnter
    generic map(gCntWidth   => gPacketAddrWidth)
    port map(
            clk         => clk,
            reset       => reset,
            iClear      => RdCntClear,
            iEn         => RdPreCnt,
            iStartValue => iRdStartAddr,
            iEndValue   => (others => '1'),
            oQ          => oRdAddr,
            oOv         => open
            );


end two_seg_arch;
