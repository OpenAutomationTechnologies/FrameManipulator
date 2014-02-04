-------------------------------------------------------------------------------
--! @file Byte_to_TXData.vhd
--! @brief Convertes an 1Byte Stream to the Ethernet TXData of a RMII-PHY
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


--! This is the entity of the Byte to RMII converter
entity Byte_to_TXData is
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iData       : in std_logic_vector(cByteLength-1 downto 0);  --! Byte in
        oTXD        : out std_logic_vector(1 downto 0)              --! TXD RMII out
    );
end Byte_to_TXData;


--! @brief Byte_to_TXData architecture
--! @details Convertes an 1Byte Stream to the Ethernet TXData
architecture two_seg_arch of Byte_to_TXData is

    signal sync     : std_logic;                                --! Synchronise Reset
    signal cnt      : std_logic_vector(1 downto 0);             --! Select signal of Mux
    signal data     : std_logic_vector(cByteLength-1 downto 0); --! Delayed data
    signal txD_reg  : std_logic_vector(1 downto 0);             --! TX-data with register

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            oTXD    <= (others => '0');

        elsif rising_edge(iClk) then
            oTXD    <= txD_reg;

        end if;
    end process;


    --! @brief Synchronize the module to the data stream
    syncronizer : work.sync_newData
    generic map (gWidth  => cByteLength)
    port map (
            iClk    => iClk,
            iReset  => iReset,
            iData   => iData,
            oData   => data,
            oSync   => sync
            );


    --! @brief Multiplexer selection
    cnt_2bit : work.Basic_Cnter      --Counter, which controlls the DMux
    generic map (gCntWidth  => 2)
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iClear      => sync,
            iEn         => '1',
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => cnt,
            oOv         => open
            );


    --! @brief Multiplexer
    DMux8to2 : work.Mux2D
    generic map(
                gWordsWidth => 2,
                gWordsNo    => 4,
                gWidthSel   => 2
                )
    port map(
            iData   => data,
            iSel    => cnt,
            oWord   => txD_reg
            );


end two_seg_arch;