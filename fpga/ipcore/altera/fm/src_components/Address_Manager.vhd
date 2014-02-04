-------------------------------------------------------------------------------
--! @file Address_Manager.vhd
--! @brief The Address_Manager handels the start-address of the Frame_Receiver
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


--! This is the entity of the address handler of the frame buffer
entity Address_Manager is
    generic(
            gAddrDataWidth  : natural:=11;              --! Address width of the frame buffer
            gDelayDataWidth : natural:=6*cByteLength;   --! Width of setting from delay-manipulation
            gNoOfDelFrames  : natural:=255              --! Maximal number of delayed frames
            );
    port(
        iClk                : in std_logic;     --! clk
        iReset              : in std_logic;     --! reset
        --control signals
        iStartFrameStorage  : in std_logic;     --! frame position can be stored
        iFrameEnd           : in std_logic;     --! frame reached its end => endaddress is valid
        iFrameIsSoC         : in std_logic;     --! current frame is a SoC
        iTestSync           : in std_logic;     --! sync: Test started
        iTestStop           : in std_logic;     --! Test abort
        iNextFrame          : in std_logic;     --! frame_creator is ready for new data
        oStartNewFrame      : out std_logic;    --! new frame data is vaild
        --manipulations
        iDelaySetting       : in std_logic_vector(gDelayDataWidth-1 downto 0);  --! setting for delaying frames
        iTaskDelayEn        : in std_logic;                                     --! task: delay frames
        iTaskCrcEn          : in std_logic;                                     --! task: distort crc ready to be stored
        oDistCrcEn          : out std_logic;                                    --! task: new frame receives a distorted crc
        --memory management
        iDataInEndAddr      : in std_logic_vector(gAddrDataWidth-1 downto 0);   --! end position of current frame
        oDataInStartAddr    : out std_logic_vector(gAddrDataWidth-1 downto 0);  --! start position of next incoming frame
        oDataOutStartAddr   : out std_logic_vector(gAddrDataWidth-1 downto 0);  --! start position of next created frame
        oDataOutEndAddr     : out std_logic_vector(gAddrDataWidth-1 downto 0);  --! end position of next created frame
        oError_addrBuffOv   : out std_logic                                     --! error: address-buffer-overflow
    );
end Address_Manager;


--! @brief Address_Manager architecture
--! @details The Address_Manager handels the start-address of the Frame_Receiver
--! - Invalid and dropped frames are overwritten by the next frame. The accepted ones start
--!   after the last end-address.
--! - The delay-task is also processed here. A delayed frame receives a timestamp and get
--!   stored with it. Once it is loaded, the Address_Manager waits until it has passed this
--!   point of time.
--! - The loaded addresses are then stored and passed on to the Frame_Creator with the CRC-
--!   distortion flag (which is stored with the end-address).
architecture two_seg_arch of Address_Manager is

    --constants
    constant cSize_Time     : natural:=gDelayDataWidth-cByteLength+1;   --! Width of the delay parameter. +1 in case of overflow

    --Fifo address and word width
    constant cBuffAddrWidth : natural:=LogDualis((2**gAddrDataWidth)/60*2); --! Fifo address width. Every frame uses two entries of the fifo --TODO framesize => package
    constant cBuffWordWidth : natural:=gAddrDataWidth+cSize_Time;           --! Fifo word width


    signal startAddrStorage :std_logic; --! start address storage of the current frame

    signal delayTime        : std_logic_vector(cSize_Time-1 downto 0);      --! delay timestamp for the incoming frame

    --received fifo data
    signal addrOutData      : std_logic_vector(gAddrDataWidth-1 downto 0);  --! address for new frame
    signal frameTimestamp   : std_logic_vector(cSize_Time-1 downto 0);      --! frame timestamp
    signal currentTime      : std_logic_vector(cSize_Time-1 downto 0);      --! current time
    signal delFrameLoaded   : std_logic;                                    --! a delayed frame was loaded

    --Fifo signals
    signal fifoWr           : std_logic;    --! write data
    signal fifoRd           : std_logic;    --! read data
    signal fifoFull         : std_logic;    --! fifo overflow
    signal fifoEmpty        : std_logic;    --! fifo empty
    signal fifoDataReady    : std_logic;    --! fifo data is ready

    --fifo data
    signal wrFifoData       : std_logic_vector(cBuffWordWidth-1 downto 0);  --! data in
    signal rdFifoData       : std_logic_vector(cBuffWordWidth-1 downto 0);  --! data out


begin

    --FRAME STORING---------------------------------------------------------------------------

    --! @brief delay task handler
    --! - generates delay timestamp for incoming frames
    DelHan : work.Delay_Handler
    generic map(
                gDelayDataWidth => gDelayDataWidth,
                gNoOfDelFrames  => gNoOfDelFrames
                )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iStart              => iStartFrameStorage,
            iFrameIsSoC         => iFrameIsSoC,
            iDelayEn            => iTaskDelayEn,
            iTestSync           => iTestSync,
            iTestStop           => iTestStop,
            iDelayData          => iDelaySetting,
            iDelFrameLoaded     => delFrameLoaded,
            oStartAddrStorage   => startAddrStorage,
            oCurrentTime        => currentTime,
            oDelayTime          => delayTime
            );

    --! @brief address storer
    --! - stores start and end address with delay timestamp and crc distortion flag
    Addr_in : work.StoreAddress_FSM
    generic map(
            gAddrDataWidth  => gAddrDataWidth,
            gSize_Time      => cSize_Time,
            gFiFoBitWidth   => cBuffWordWidth
            )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iStartStorage       => startAddrStorage,
            iFrameEnd           => iFrameEnd,
            iCRCManEn           => iTaskCrcEn,
            iDataInEndAddr      => iDataInEndAddr,
            iDelayTime          => delayTime,
            oDataInStartAddr    => oDataInStartAddr,
            oWr                 => fifoWr,
            oFiFoData           => wrFifoData
            );
    ------------------------------------------------------------------------------------------




    --FIFO------------------------------------------------------------------------------------

    --! @brief Fifo for frame address and timestamp/crc
    FiFo : work.FiFo_top
    generic map(
                gDataWidth  => cBuffWordWidth,
                gAddrWidth  => cBuffAddrWidth,
                gCnt_Mode   => 1
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iRd     => fifoRd,
            iWr     => fifoWr,
            iWrData => wrFifoData,
            oFull   => fifoFull,
            oEmpty  => fifoEmpty,
            oRdData => rdFifoData
            );


    --address-buffer-overflow, when Fifo=full+write
    oError_addrBuffOv   <= '1' when fifoWr='1' and fifoFull='1' else '0';
    ------------------------------------------------------------------------------------------




    --DATA-SPLIT OFF--------------------------------------------------------------------------

    --first bits => Timestamp                           iNextFrame='1' appears only at reading the start address
    frameTimestamp  <= rdFifoData(rdFifoData'left downto gAddrDataWidth) when iNextFrame='1'
                        and iTestStop='0' else (others=>'0');

    --CRC flag                                          iNextFrame='0' appears only at reading the end address
    oDistCrcEn      <= rdFifoData(gAddrDataWidth)  when iNextFrame='0' else '0';

    --last bits => address-data
    addrOutData     <= rdFifoData(gAddrDataWidth-1 downto 0);
    ------------------------------------------------------------------------------------------




    --DELAYING FRAME--------------------------------------------------------------------------

    --Timestamp isn't zero => a delayed frame was loaded => pull counter +1
    delFrameLoaded  <= '1' when frameTimestamp/=(frameTimestamp'range=>'0') else '0';

    --data is ready, when data is available and timestamp has been reached
    fifoDataReady   <= not fifoEmpty when frameTimestamp<=currentTime else '0';
    ------------------------------------------------------------------------------------------




    --DATA OUTPUT-----------------------------------------------------------------------------

    --! @brief storing addresses of the next frame
    Addr_out : work.ReadAddress_FSM
        generic map(
                    gAddrDataWidth  => gAddrDataWidth,
                    gBuffBitWidth   => gAddrDataWidth
                    )
    port map(
            iClk            => iClk,
            iReset          => iReset,
            iFifoData       => addrOutData,
            iDataReady      => fifoDataReady,
            iNextFrame      => iNextFrame,
            oDataOutStart   => oDataOutStartAddr,
            oDataOutEnd     => oDataOutEndAddr,
            oRd             => fifoRd,
            oStart          => oStartNewFrame
            );
    ------------------------------------------------------------------------------------------


end two_seg_arch;