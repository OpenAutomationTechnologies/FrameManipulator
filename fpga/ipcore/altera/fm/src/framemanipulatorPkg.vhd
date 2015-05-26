-------------------------------------------------------------------------------
--! @file framemanipulatorPkg.vhd
--
--! @brief Framemanipulator package
--
--! @details This is the Framemanipulator package providing common types and constants.
-------------------------------------------------------------------------------
--
--       Copyright (C) 2013 B&R
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



--! This is the package for the Ethernet Framemanipulator
package framemanipulatorPkg is


    ---------------------------------------------------------------------------
    -- FM Control
    ---------------------------------------------------------------------------
    --! Definition operation register 0x3000/1
    type tOperation is record
        start       : natural; --! Start series of test
        stop        : natural; --! Stop series of test
        clearMem    : natural; --! Clear task memory
        clearErrors : natural; --! Clear error flags
        clearPaket  : natural; --! Clear packet memory
    end record;

    --! Set predefined value for operation flags
    constant cOp  : tOperation :=(
                                start       => 0,
                                stop        => 1,
                                clearMem    => 2,
                                clearErrors => 3,
                                clearPaket  => 4
                                );

    --! Definition status register 0x3000/2
    type tStatus is record
        testActive  : natural;  --! Test is active
        erDataOv    : natural;  --! Overflow at data buffer
        erFrameOv   : natural;  --! Overflow at address buffer
        erPacketOv  : natural;  --! Overflow at packet buffer
        erTaskConf  : natural;  --! Wrong safety task configuration occurred
    end record;

    --! Set predefined value for status flags
    constant cSt  : tStatus :=(
                                testActive  => 0,
                                erDataOv    => 4,
                                erFrameOv   => 5,
                                erPacketOv  => 6,
                                erTaskConf  => 7
                                );

    ---------------------------------------------------------------------------
    -- Manipulation Tasks
    ---------------------------------------------------------------------------
    --! Definition manipulation tasks
    type tTasks is record
        --! Normal ones
        drop        : std_logic_vector(cByteLength-1 downto 0); --! Drop frame
        delay       : std_logic_vector(cByteLength-1 downto 0); --! Delay frame
        mani        : std_logic_vector(cByteLength-1 downto 0); --! Manipulate frame data
        crc         : std_logic_vector(cByteLength-1 downto 0); --! Distort the CRC
        cut         : std_logic_vector(cByteLength-1 downto 0); --! Truncate frame
        --! Safety ones
        repetition  : std_logic_vector(cByteLength-1 downto 0); --! Repeat safety packets
        paLoss      : std_logic_vector(cByteLength-1 downto 0); --! Delete safety packets
        insertion   : std_logic_vector(cByteLength-1 downto 0); --! Change safety packet with another one
        incSeq      : std_logic_vector(cByteLength-1 downto 0); --! Put out packets in the reverse order
        incData     : std_logic_vector(cByteLength-1 downto 0); --! Distort safety packet payload to create an incorrect CRC
        paDelay     : std_logic_vector(cByteLength-1 downto 0); --! Delay safety packets
        masquerade  : std_logic_vector(cByteLength-1 downto 0); --! Exchange packets with random data
    end record;

    --! Set predefined value for manipulation tasks
    constant cTask  : tTasks :=(
                                drop        => X"01",
                                delay       => X"02",
                                mani        => X"04",
                                crc         => X"08",
                                cut         => X"10",
                                repetition  => X"81",
                                paLoss      => X"82",
                                insertion   => X"83",
                                incSeq      => X"84",
                                incData     => X"85",
                                paDelay     => X"86",
                                masquerade  => X"87"
                                );


    ---------------------------------------------------------------------------
    -- FM Delay Types
    ---------------------------------------------------------------------------
    --! Definition of the different types of delay
    type tDelayType is record
        pass    : std_logic_vector(cByteLength-1 downto 0); --! Pass all frames
        delete  : std_logic_vector(cByteLength-1 downto 0); --! Delete all
        passSoC : std_logic_vector(cByteLength-1 downto 0); --! Pass only SoCs
    end record;

    --! Set predefined value for operation flags
    constant cDelayType : tDelayType :=(
                                pass    => X"01",
                                delete  => X"02",
                                passSoC => X"04"
                                );


    ---------------------------------------------------------------------------
    -- FM Size of needed Settings
    ---------------------------------------------------------------------------
    --! Definition of task setting size
    type tSettingSize is record
        delay   : natural;  --! Size of needed setting for delay task
        safety  : natural;  --! Size of needed setting for safety task
    end record;

    --! Set predefined value for setting size
    constant cSettingSize   : tSettingSize :=(
                                delay   => 5*cByteLength,   --! 5 Byte Delay setting
                                safety  => 6*cByteLength    --! 6 Byte Safety setting
                                );


    ---------------------------------------------------------------------------
    -- FM parameters
    ---------------------------------------------------------------------------
    --! Definition of FM parameters
    type tParameters is record
        noDelFrames             : natural;  --! Maximal number of delayed frame tasks
        noOfHeadMani            : natural;  --! Number of manipulated header bytes
        sizeManiHeaderOffset    : natural;  --! Size of the offsets for manipulation task
        sizeManiHeaderData      : natural;  --! Size of the data for manipulation task
        safetyPackSelCntWidth   : natural;  --! Width of counter to select packet: 11 bit to change the whole frame
    end record;

    --! Set predefined value for FM parameters
    constant cParam   : tParameters :=(
                                noDelFrames             => 255,         --! Maximal number of delayed frames
                                noOfHeadMani            => 8,           --! 8 Manipulated Bytes per manipulation task
                                sizeManiHeaderOffset    => 6,           --! 6 bit per offset
                                sizeManiHeaderData      => cByteLength, --! 1 Byte
                                safetyPackSelCntWidth   => 11           --! 11 bit to change the whole frame
                                );


    ---------------------------------------------------------------------------
    -- Ethernet parameters
    ---------------------------------------------------------------------------
    --! Definition of POWERLINK Ethernet parameters
    type tEth is record
        filterEtherType     : std_logic_vector(8*cByteLength-1 downto 0);   --! Frame Ethertypes which are allowed to pass the FM
        startFrameFilter    : natural;                                      --! First Byte of the frame to identify it via object 0x3003
        endFrameFilter      : natural;                                      --! Last Byte of the frame to identify it via object 0x3003
        sizeEtherType       : natural;                                      --! Size of EtherType
        startEtherType      : natural;                                      --! Start Byte of EtherType
        endEtherType        : natural;                                      --! Start Byte of EtherType
        startMessageType    : natural;                                      --! Position of POWERLINK MessageType
        messageTypeSoC      : std_logic_vector(cByteLength-1 downto 0);     --! MessageType for SoCs
    end record;

    --! Set predefined value for setting size
    constant cEth   : tEth :=(
                                filterEtherType     => X"88AB_0800_0806_3E3F",   --! POWERLINK V2, IP, ARP and POWERLINK V1 frames are valid
                                startFrameFilter    => 15,                  --! Filter starts with Messagetype
                                endFrameFilter      => 22,                  --! StartFrameFilter+8Byte-1
                                sizeEtherType       => 2*cByteLength,       --! 2 Bytes
                                startEtherType      => 13,                  --! Starts at Byte 13
                                endEtherType        => 14,                  --! End at Byte 14
                                startMessageType    => 15,                  --! At Byte 15
                                messageTypeSoC      => X"01"
                                );


    ---------------------------------------------------------------------------
    -- Frame create timing parameters
    ---------------------------------------------------------------------------
    --! Definition of timing parameters for frame creation
    type tFrameCreateTime is record
        cntWidth    : natural;  --! Width of time counter
        preamble    : natural;  --! Clock cycles to create the Preamble
        preReadTime : natural;  --! Clock cycles to compensate the delay of the read operation
        crcTime     : natural;  --! Clock cycles to create the CRC
        ipgTime     : natural;  --! Clock cycles to keep the Inter packet gap of 960 ns
    end record;

    --! Set predefined value for timing parameters for frame creation
    constant cCreateTime    : tFrameCreateTime :=(
                                cntWidth    => 6,
                                preamble    => 31,  --! 8Byte => 8Byte*8Bit/2Width => 32
                                preReadTime => 5,   --! Forerun of the reading logic of 5 cycles
                                crcTime     => 15,  --! 4Byte => 4Byte*8Bit/2Width => 16
                                ipgTime     => 44   --! Whole delay of 960ns => here 880ns + process time
                                );

end framemanipulatorPkg;

package body framemanipulatorPkg is



end framemanipulatorPkg;