-------------------------------------------------------------------------------
--! @file RXData_to_Byte.vhd
--! @brief Converter for Ethernet Rx-Data from a RMII-PHY to Bytes
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



--! This is the entity of the Ethernet converter
entity RXData_to_Byte is
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iRXDV       : in std_logic;                                 --! RX-data-valid
        iRXD        : in std_logic_vector(1 downto 0);              --! RX-data
        oData       : out std_logic_vector(cByteLength-1 downto 0); --! Byte out
        oEn         : out std_logic;                                --! Byte is complete
        oSync       : out std_logic                                 --! New frame arrived
    );
end RXData_to_Byte;



--! @brief RXData_to_Byte architecture
--! @details Converter for Ethernet Rx-Data from a PHY to Bytes
architecture two_seg_arch of RXData_to_Byte is

    signal data1    : std_logic_vector(3 downto 0); --! data from shift register 1
    signal data2    : std_logic_vector(3 downto 0); --! data from shift register 2
    signal div4_en  : std_logic;                    --! enable Signal every 4th clock
    signal sync     : std_logic;                    --! Synchronise Reset

begin

    --! @brief first shift register for RxD0
    shift1_4bit : entity work.shift_right_register
    generic map (gWidth => 4)
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iD      => iRXD(0),
            oQ      => data1
            );


    --! @brief second shift register for RxD1
    shift2_4bit : entity work.shift_right_register
    generic map (gWidth => 4)
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iD      => iRXD(1),
            oQ      => data2
            );


    --! @brief Synchronizer for the counter
    synchronizer : entity work.sync_RxFrame
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iRXDV   => iRXDV,
            iRXD1   => iRXD(1),
            oSync   => sync
            );


    --! @brief Prescaler for an enable every 4th clock(Data is ready in the Shift register)
    cnt_2bit : entity work.FixCnter
    generic map (
                gCntWidth   => 2,
                gStartValue => (1 downto 0 => '0'),
                gInitValue  => (1 downto 0 => '0'),
                gEndValue   => (1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => sync,
            iEn     => '1',
            oQ      => open,
            oOv     => div4_en
            );


    --! @brief Adder, which generates the Byte from the two shift registers after every enable
    adder : entity work.adder_2121
    generic map(WIDTH_IN => 4)
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iD1     => data1,
            iD2     => data2,
            iEn     => div4_en,
            oQ      => oData
            );


    oSync   <= sync;
    oEn     <= div4_en;

end two_seg_arch;