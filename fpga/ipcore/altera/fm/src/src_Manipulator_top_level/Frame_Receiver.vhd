-------------------------------------------------------------------------------
--! @file Frame_Receiver.vhd
--! @brief Receives the incoming frame and stores it on the data-buffer
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
--! use fm library
use work.framemanipulatorPkg.all;

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;


--! This is the entity to receive the incoming frame and stores it on the data-buffer.
entity Frame_Receiver is
    generic(
            gBuffAddrWidth      : natural :=11;                                 --! Address with of frame buffer
            gEtherTypeFilter    : std_logic_vector :=X"88AB_0800_0806"          --! filter for allowed EtherTypes
            );
    port(
        iClk                : in std_logic;                                     --! clk
        iReset              : in std_logic;                                     --! reset
        iRXDV               : in std_logic;                                     --! frame data valid
        iRXD                : in std_logic_vector(1 downto 0);                  --! frame data (2bit)
        --write data
        oData               : out std_logic_vector(cByteLength-1 downto 0);     --! frame data (1byte)
        oWrBuffAddr         : out std_logic_vector(gBuffAddrWidth-1 downto 0);  --! write address
        oWrBuffEn           : out std_logic;                                    --! write data-memory enable
        iDataStartAddr      : in std_logic_vector(gBuffAddrWidth-1 downto 0);   --! first byte of frame data
        oDataEndAddr        : out std_logic_vector(gBuffAddrWidth-1 downto 0);  --! last byte of frame data
        --truncate frame
        iTaskCutEn          : in std_logic;                                     --! cut task enabled
        iTaskCutData        : in std_logic_vector(gBuffAddrWidth-1 downto 0);   --! cut task setting
        --start process-unit
        oStartFrameProcess  : out std_logic;                                    --! valid frame received
        oFrameEnded         : out std_logic;                                    --! frame ended
        oFrameSync          : out std_logic                                     --! synchronization signal
    );
end Frame_Receiver;


--! @brief Frame_Receiver architecture
--! @details Receives the incoming frame and stores it on the data-buffer
--! - Only frames with a valid preamble and one of the Ethertypes of gEtherTypeFilter
--!   activates the start signal "oStartFrame" for the next process units.
--! - It starts to write the data to the memory, starting with the address iDataStartAddr.
--!   This position is sent by the process unit and overwrites invalid or dropped frames to
--!   save some memory.
--! - It also processes the truncate task for the selected frames and changes the address
--!   of the last byte of the data-buffer.
architecture two_seg_arch of Frame_Receiver is

    --! Ethertype filter as downto-std_logic_vector
    constant cEtherTypeFilter   : std_logic_vector(gEtherTypeFilter'length-1 downto 0) := gEtherTypeFilter;

    --! Number of Ethertype filter
    constant cNumbFilter        : natural := gEtherTypeFilter'length/cEth.SizeEtherType;

    signal data                 : std_logic_vector(cByteLength-1 downto 0);         --! Data stream of the frame in Bytes
    signal sync                 : std_logic;                                        --! Synchronization signal at the start of a frame

    signal enWL                 : std_logic;                                        --! Enable write module to store frame
    signal wraddr               : std_logic_vector(gBuffAddrWidth-1 downto 0);      --! Write address of frame buffer

    signal etherType            : std_logic_vector(cEth.SizeEtherType-1 downto 0);  --! Ethertype of current frame
    signal preambleOk           : std_logic:='0';                                   --! Preamble of frame is valid
    signal collectorFinished    : std_logic;                                        --! Ethertype is read from frame

    signal frameEnd             : std_logic;                                        --! Reached end of incoming frame

    signal matchFilter          : std_logic_vector(cNumbFilter-1 downto 0);         --! Filter(x) does match

    signal startFrameProcess_reg    : std_logic;    --! Register of oStartFrameProcess to reduce path delay
    signal startFrameProcess_next   : std_logic;    --! Next value of register


begin

    --! @brief data width converter
    --! - converted data output             => oData
    --! - generates synchronization signal  => oSync
    Rx : entity work.RXData_to_Byte
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iRXDV   => iRXDV,
            iRXD    => iRXD,
            oData   => data,
            oEn     => open,
            oSync   => sync
            );


    --! @brief preamble checker
    --! - valid preamble detected  =>  oPreOk
    PreCheck : entity work.Preamble_check
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iRXD    => iRXD,
            iRXDV   => iRXDV,
            iSync   => sync,
            oPreOk  => preambleOk
            );


    --! @brief Ethertype collector
    --! - collected data            =>  oFrameData
    --! - collector has finisched   =>  oCollectorFinished
    EtherType_Collector : entity work.Frame_collector
    generic map(
                gFrom   => cEth.StartEtherType,
                gTo     => cEth.EndEtherType
                )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iData               => data,
            iSync               => sync,
            oFrameData          => etherType,
            oCollectorFinished  => collectorFinished
            );


    --! Check of the Ethertype with the predefined values
    EthertypeMatch :
    for i in MatchFilter'range generate

        matchFilter(i)  <=  '1' when etherType = cEtherTypeFilter(cEth.sizeEtherType*(i+1)-1 downto cEth.sizeEtherType*i) else '0';

    end generate EthertypeMatch;



    --write logic is enabled and stores data utill the frame has ended
    enWL    <= not frameEnd;

    --! @brief Memory write logic
    --! - gPrescaler = 4
    WL : entity work.write_logic
    generic map(
                gPrescaler  => 4,  --writes data every fourth tick
                gAddrWidth  => gBuffAddrWidth
                )
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iSync       => sync,
            iEn         => enWL,
            iStartAddr  => iDataStartAddr,
            oAddr       => wraddr,
            oWrEn       => oWrBuffEn);


    --! @brief frame end detection
    --! - detects the end of the frame                      =>  oFrameEnd
    --! - as well as the memory-address of the last byte    =>  oEndAddr
    --! - also truncates the frame in the cut-frame-task    =>  iCutEn, iCutData
    end_of_frame : entity work.end_of_frame_detection
    generic map(gBuffAddrWidth  => gBuffAddrWidth)
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iRXDV       => iRXDV,
            iAddr       => wraddr,
            iStartAddr  => iDataStartAddr,
            iCutEn      => iTaskCutEn,
            iCutData    => iTaskCutData,
            oEndAddr    => oDataEndAddr,
            oFrameEnd   => frameEnd
            );


    --  frame process can start, when the collection has finished with Preamble and one of the valid Ethertypes
    startFrameProcess_next  <= '1' when collectorFinished='1' and preambleOk='1' and reduceOr(matchFilter)='1' else '0';


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            startFrameProcess_reg   <= '0';

        elsif rising_edge(iClk) then
            startFrameProcess_reg   <= startFrameProcess_next;

        end if;
    end process;

    oStartFrameProcess  <= startFrameProcess_reg;


    --signal output
    oFrameEnded <= frameEnd;
    oData       <= data;
    oWrBuffAddr <= wraddr;
    oFrameSync  <= sync;

end two_seg_arch;


