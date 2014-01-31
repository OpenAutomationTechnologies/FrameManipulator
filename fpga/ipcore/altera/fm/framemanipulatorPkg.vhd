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
--! use global library
use work.global.all;


--! This is the package for the Ethernet Framemanipulator
package framemanipulatorPkg is


    ---------------------------------------------------------------------------
    -- FM Control
    ---------------------------------------------------------------------------
    --! Definition operation register 0x3000/1
    type tOperation is record
        Start       : natural; --! Start series of test
        Stop        : natural; --! Stop series of test
        ClearMem    : natural; --! Clear task memory
        ClearErrors : natural; --! Clear error flags
        ClearPaket  : natural; --! Clear packet memory
    end record;

    --! Set predefined value for operation flags
    constant cOp  : tOperation :=(
                                Start       => 0,
                                Stop        => 1,
                                ClearMem    => 2,
                                ClearErrors => 3,
                                ClearPaket  => 4
                                );

    --! Definition status register 0x3000/2
    type tStatus is record
        TestActive  : natural;  --! Test is active
        ErDataOv    : natural;  --! Overflow at data buffer
        ErFrameOv   : natural;  --! Overflow at address buffer
        ErPacketOv  : natural;  --! Overflow at packet buffer
        ErTaskConf  : natural;  --! Wrong safety task configuration occurred
    end record;

    --! Set predefined value for status flags
    constant cSt  : tStatus :=(
                                TestActive  => 0,
                                ErDataOv    => 4,
                                ErFrameOv   => 5,
                                ErPacketOv  => 6,
                                ErTaskConf  => 7
                                );

    ---------------------------------------------------------------------------
    -- Manipulation Tasks
    ---------------------------------------------------------------------------
    --! Definition manipulation tasks
    type tTasks is record
        --! Normal ones
        Drop        : std_logic_vector(cByteLength-1 downto 0); --! Drop frame
        Delay       : std_logic_vector(cByteLength-1 downto 0); --! Delay frame
        Mani        : std_logic_vector(cByteLength-1 downto 0); --! Manipulate frame data
        Crc         : std_logic_vector(cByteLength-1 downto 0); --! Distort the CRC
        Cut         : std_logic_vector(cByteLength-1 downto 0); --! Truncate frame
        --! Safety ones
        Repetition  : std_logic_vector(cByteLength-1 downto 0); --! Repeat safety packets
        PaLoss      : std_logic_vector(cByteLength-1 downto 0); --! Delete safety packets
        Insertion   : std_logic_vector(cByteLength-1 downto 0); --! Change safety packet with another one
        IncSeq      : std_logic_vector(cByteLength-1 downto 0); --! Put out packets in the reverse order
        IncData     : std_logic_vector(cByteLength-1 downto 0); --! Distort safety packet payload to create an incorrect CRC
        PaDelay     : std_logic_vector(cByteLength-1 downto 0); --! Delay safety packets
        Masquerade  : std_logic_vector(cByteLength-1 downto 0); --! Exchange packets with random data
    end record;

    --! Set predefined value for manipulation tasks
    constant cTask  : tTasks :=(
                                Drop        => X"01",
                                Delay       => X"02",
                                Mani        => X"04",
                                Crc         => X"08",
                                Cut         => X"10",
                                Repetition  => X"81",
                                PaLoss      => X"82",
                                Insertion   => X"83",
                                IncSeq      => X"84",
                                IncData     => X"85",
                                PaDelay     => X"86",
                                Masquerade  => X"87"
                                );


    ---------------------------------------------------------------------------
    -- FM Delay Types
    ---------------------------------------------------------------------------
    --! Definition of the different types of delay
    type tDelayType is record
        Pass    : std_logic_vector(cByteLength-1 downto 0); --! Pass all frames
        Delete  : std_logic_vector(cByteLength-1 downto 0); --! Delete all
        PassSoC : std_logic_vector(cByteLength-1 downto 0); --! Pass only SoCs
    end record;

    --! Set predefined value for operation flags
    constant cDelayType : tDelayType :=(
                                Pass    => X"01",
                                Delete  => X"02",
                                PassSoC => X"04"
                                );


    ---------------------------------------------------------------------------
    -- FM Size of needed Settings
    ---------------------------------------------------------------------------
    --! Definition of task setting size
    type tSettingSize is record
        Delay   : natural;  --! Size of needed setting for delay task
        Safety  : natural;  --! Size of needed setting for safety task
    end record;

    --! Set predefined value for setting size
    constant cSettingSize   : tSettingSize :=(
                                Delay   => 5*cByteLength,   --! 5 Byte Delay setting
                                Safety  => 6*cByteLength    --! 6 Byte Safety setting
                                );


    ---------------------------------------------------------------------------
    -- FM parameters
    ---------------------------------------------------------------------------
    --! Definition of FM parameters
    type tParameters is record
        NoDelFrames             : natural;  --! Maximal number of delayed frame tasks
        NoOfHeadMani            : natural;  --! Number of manipulated header bytes
        SizeManiHeaderOffset    : natural;  --! Size of the offsets for manipulation task
        SizeManiHeaderData      : natural;  --! Size of the data for manipulation task
        SafetyPackSelCntWidth   : natural;  --! Width of counter to select packet: 11 bit to change the whole frame
    end record;

    --! Set predefined value for FM parameters
    constant cParam   : tParameters :=(
                                NoDelFrames             => 255,         --! Maximal number of delayed frame tasks
                                NoOfHeadMani            => 8,           --! 8 Manipulated Bytes per manipulation task
                                SizeManiHeaderOffset    => 6,           --! 6 bit per offset
                                SizeManiHeaderData      => cByteLength, --! 1 Byte
                                SafetyPackSelCntWidth   => 11           --! 11 bit to change the whole frame
                                );


    ---------------------------------------------------------------------------
    -- Ethernet parameters
    ---------------------------------------------------------------------------
    --! Definition of POWERLINK Ethernet parameters
    type tEth is record
        FilterEtherType     : std_logic_vector(6*cByteLength-1 downto 0);   --! Frame Ethertypes which are allowed to pass the FM
        StartFrameFilter    : natural;                                      --! First Byte of the frame to identify it via object 0x3003
        EndFrameFilter      : natural;                                      --! Last Byte of the frame to identify it via object 0x3003
        SizeEtherType       : natural;                                      --! Size of EtherType
        StartEtherType      : natural;                                      --! Start Byte of EtherType
        EndEtherType        : natural;                                      --! Start Byte of EtherType
        StartMessageType    : natural;                                      --! Position of POWERLINK MessageType
        MessageTypeSoC      : std_logic_vector(cByteLength-1 downto 0);     --! MessageType for SoCs
    end record;

    --! Set predefined value for setting size
    constant cEth   : tEth :=(
                                FilterEtherType     => X"88AB_0800_0806",   --! POWERLINK, IP and ARP frames are valid
                                StartFrameFilter    => 15,                  --! Filter starts with Messagetype
                                EndFrameFilter      => 22,                  --! StartFrameFilter+8Byte-1
                                SizeEtherType       => 2*cByteLength,       --! 2 Bytes
                                StartEtherType      => 13,                  --! Starts at Byte 13
                                EndEtherType        => 14,                  --! End at Byte 14
                                StartMessageType    => 15,                  --! At Byte 15
                                MessageTypeSoC      => X"01"
                                );


end framemanipulatorPkg;

package body framemanipulatorPkg is



end framemanipulatorPkg;