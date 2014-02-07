-------------------------------------------------------------------------------
--! @file Frame_Creator.vhd
--! @brief Creates a new frame, when iStartNewFrame is set
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


--! This is the entity of the top-module for creating an ethernet frame
entity Frame_Creator is
    generic(gDataBuffAddrWidth      : natural :=11; --! Address width of frame buffer
            gSafetyPackSelCntWidth  : natural :=8   --! Width of counter to select safety packet
            );
    port(
        iClk                : in std_logic;         --! clk
        iReset              : in std_logic;         --! reset

        iStartNewFrame      : in std_logic;         --! data for a new frame is available
        oNextFrame          : out std_logic;        --! frame-creator is ready for new data
        iDistCrcEn          : in std_logic;         --! task: distortion of frame-CRC
        --Read data buffer
        iDataStartAddr      : in std_logic_vector(gDataBuffAddrWidth-1 downto 0);   --! Position of the first frame-byte
        iDataEndAddr        : in std_logic_vector(gDataBuffAddrWidth-1 downto 0);   --! Position of the last
        iData               : in std_logic_vector(cByteLength-1 downto 0);          --! frame-data
        oRdBuffAddr         : out std_logic_vector(gDataBuffAddrWidth-1 downto 0);  --! read address of data-memory
        oRdBuffEn           : out std_logic;                                        --! read-enable
        --Safety packet exchange
        iPacketExchangeEn   : in std_logic;                                 --! Start of the exchange of the safety packet
        iPacketStart        : in std_logic_vector(cByteLength-1 downto 0);  --! Start of safety packet
        iPacketSize         : in std_logic_vector(cByteLength-1 downto 0);  --! Size of safety packet
        iPacketData         : in std_logic_vector(cByteLength-1 downto 0);  --! Data of the new safety packet
        iPacketExtension    : in std_logic;                                 --! Exchange will be extended for several tacts
        oExchangeData       : out std_logic;                                --! Exchanging safety data
        --Output
        oTxData             : out std_logic_vector(1 downto 0); --! frame-output-data
        oTxDV               : out std_logic                     --! frame-output-data-valid
    );
end Frame_Creator;



--! @brief Frame_Creator architecture
--! @details This is the top-module for creating a new frame
--! - Creates a new frame, when iStartNewFrame is set. It generates a new Preamble and a
--!   valid or manipulated CRC. The frame-data are collected from iDataStartAddr to
--!   iDataEndAddr.
--! - Once a frame was sent out, it activates oNextFrame to receive the next one. Thereby,
--!   the IPG (Inter Packet Gap) is considered by a small delay.
architecture two_seg_arch of Frame_Creator is

    signal preambleActive   : std_logic;    --! Preamble will be generated
    signal readBuffActive   : std_logic;    --! Frame will be read from buffer
    signal preReadBuff      : std_logic;    --! Pre-read of frame buffer
    signal crcActive        : std_logic;    --! CRC will be generated

    signal readaddr         : std_logic_vector(gDataBuffAddrWidth-1 downto 0);  --! Read address of frame buffer
    signal nStartReader     : std_logic;                                        --! Start reading data from frame buffer (low active)
    signal readdone         : std_logic;                                        --! Reading finished

    signal txdSelection     : std_logic_vector(1 downto 0);             --! Select data stream
    signal exchangeData     : std_logic;                                --! Exchange safety packet from stream

    signal frameData        : std_logic_vector(cByteLength-1 downto 0); --! Data of new frame
    signal txdPre           : std_logic_vector(1 downto 0);             --! Stream of Preamble
    signal txdBuff          : std_logic_vector(1 downto 0);             --! Stream of new freame
    signal txdCrc           : std_logic_vector(1 downto 0);             --! Stream of calculated CRC

    signal temp_txdMux      : std_logic_vector(cByteLength-1 downto 0); --! Finished stream (temp)

begin


    --frame-data is read, when the last data byte has been reached
    readdone    <= '1' when readaddr=std_logic_vector(unsigned(iDataEndAddr)-3) else '0';
        --minus 4 Bytes to cut the old CRC plus 1 for readaddr>EndAddr


    --! @brief create new frame FSM
    --! - starts with the iFrameStart signal
    --! - selection of the different signals with oSelectTX
    --! - PreReadBuff to eliminate problems with delays of the DPRam and read logic
    FSM : entity work.Frame_Create_FSM
    generic map(gSafetyPackSelCntWidth  => gSafetyPackSelCntWidth)
    port map(
        iClk                => iClk,
        iReset              => iReset,
        iFrameStart         => iStartNewFrame,
        iReadBuffDone       => readdone,
        iPacketExchangeEn   => iPacketExchangeEn,
        iPacketStart        => iPacketStart,
        iPacketSize         => iPacketSize,
        oPreambleActive     => preambleActive,
        oPreReadBuff        => preReadBuff,
        oExchangeData       => exchangeData,
        oReadBuffActive     => readBuffActive,
        oCrcActive          => crcActive,
        oSelectTX           => txdSelection,
        oNextFrame          => oNextFrame,
        oTXDV               => oTXDV
        );

    oExchangeData   <= ExchangeData;

    --! @brief preamble generator
    Preamble : entity work.Preamble_Generator
    port map (
            iClk                => iClk,
            iReset              => iReset,
            iPreambleActive     => preambleActive,
            oTXD                => txdPre
            );


    --enables the read-logic via negative logic
    nStartReader    <= not (ReadBuffActive or PreReadBuff);


    --! @brief read frame-data logic
    --! - starts reading from the address of the first byte of the memory   => iDataStartAddr
    RL : entity work.read_logic
    generic map(
                gPrescaler  => 4,
                gAddrWidth  => gDataBuffAddrWidth
                )
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iEn         => '1',
            iSync       => nStartReader,
            iStartAddr  => iDataStartAddr,
            oRdEn       => oRdBuffEn,
            oAddr       => readaddr
            );


    FrameData   <= iPacketData when ExchangeData='1' or iPacketExtension='1' else iData;

    --! @brief byte to 2bit converter
    --! - converts the frame data to a width of two bits
    Byte_to_Tx : entity work.Byte_to_TXData
    port map (
            iClk    => iClk,
            iReset  => iReset,
            iData   => frameData,
            oTXD    => txdBuff
            );


    --! @brief CRC_calculator
    --! - iReadBuff_Active  => CRC is calculated
    --! - iCrcActive       => CRC is shifted out
    --! - iCRCMani          => CRC is distorted
    CRC_calc : entity work.CRC_calculator
        port map (
            iClk                => iClk,
            iReadBuffActive     => readBuffActive,
            iCrcActive          => crcActive,
            iTXD                => txdBuff,
            iCRCMani            => iDistCrcEn,
            oTXD                => txdCrc
            );



    --collection of the different streams for the multiplexer
    temp_txdMux <= txdBuff & txdCrc & txdPre & "00";


    --! @brief Stream selector
    --! - selects the active stream by TXD_Selection of the FSM
    TXDMux : entity work.Mux2D
    generic map(
                gWordsWidth => 2,
                gWordsNo    => 4,
                gWidthSel   => 2
                )
    port map(
            iData   => temp_txdMux,
            iSel    => txdSelection,
            oWord   => oTxData
            );


    oRdBuffAddr <= readaddr;


end two_seg_arch;