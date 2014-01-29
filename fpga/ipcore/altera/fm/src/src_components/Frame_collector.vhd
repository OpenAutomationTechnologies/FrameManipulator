-------------------------------------------------------------------------------
--! @file Frame_collector.vhd
--! @brief A component to collect the data of Ethernet frames
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



--! This is the entity of a component to collect the data of Ethernet frames
entity Frame_collector is
    generic(
        gFrom   : natural:=13;  --! First byte of needed frame data
        gTo     : natural:=22   --! Last byte of needed frame data
        );
    port(
        iClk                : in std_logic;                                                 --! clk
        iReset              : in std_logic;                                                 --! reset
        iData               : in std_logic_vector(cByteLength-1 downto 0);                  --! Frame stream
        iSync               : in std_logic;                                                 --! Synchronous iReset
        oFrameData          : out std_logic_vector((gTo-gFrom+1)*cByteLength-1 downto 0);   --! Collected data
        oCollectorFinished  : out std_logic                                                 --! Data is complete
    );
end Frame_collector;


--! @brief Frame_collector architecture
--! @details A component to collect the data of Ethernet frames
architecture two_seg_arch of Frame_collector is

    constant cWidth_ByteCnt : natural := LogDualis(gTo-gFrom+1)+1;  --! Width of the counter for the byte number
    constant cNumCollBytes  : natural := gTo-gFrom+1;               --! Number of bytes of the collected data

    signal div4     : std_logic;                                        --! Prescaler enabled
    signal cnt      : std_logic_vector(LogDualis(gTo+2)-1 downto 0);    --! Number of current Byte of frame
    signal cntout   : std_logic_vector(cWidth_ByteCnt-1 downto 0);      --! Number of needed Byte

    signal filter_end   : std_logic;                                    --! Reached the last Byte (gTo)
    signal cnt_stop     : std_logic;                                    --! Clear Signal after filter_end and iSync
    signal memEn        : std_logic;                                    --! Enable to store the data

    signal reg_q    : std_logic_vector(cNumCollBytes*cByteLength-1 downto 0);   --! Register for output data
    signal reg_next : std_logic_vector(cNumCollBytes*cByteLength-1 downto 0);   --! Register for output data

begin


    --Counting current Byte------------------------------------------------------------------------------------

    --! @brief Prescaler
    --! - stops at the end
    --! - sync at start
    cnt_4 : entity work.FixCnter
    generic map(
                gCntWidth   => 2,
                gStartValue => (1 downto 0 => '0'),
                gInitValue  => (1 downto 0 => '0'),
                gEndValue   => (1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => cnt_stop,
            iEn     => '1',
            oQ      => open,
            oOv     => div4
            );

    --! @brief Counter, which counts the Bytes of the frame stream
    --! - sync at start
    cnt_5bit : entity work.FixCnter
    generic map(
                gCntWidth   => LogDualis(gTo+2),
                gStartValue => (LogDualis(gTo+2)-1 downto 0 => '0'),
                gInitValue  => (LogDualis(gTo+2)-1 downto 0 => '0'),
                gEndValue   => (LogDualis(gTo+2)-1 downto 0 => '1')
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iClear  => iSync,
            iEn     => div4,
            oQ      => cnt,
            oOv     => open
            );


    --Selecting the important Bytes----------------------------------------------------------------------------

    --! @brief Logic to select the wanted Bytes
    cnt_f_t : entity work.From_To_Cnt_Filter
    generic map(
                gFrom       => gFrom,
                gTo         => gTo,
                gWidthIn    => LogDualis(gTo+2),
                gWidthOUT   => cWidth_ByteCnt)
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iCnt    => cnt,
            oCnt    => cntout,
            oEn     => memEn,
            oEnd    => filter_end
            );


    cnt_stop    <= filter_end or iSync; --reset at every new Frame and stop after reaching the last Byte


    --Register to Save the new Data----------------------------------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg_q <= (others=>'0');

        elsif rising_edge(iClk) then
            reg_q <=reg_next;

        end if;
    end process;


    --! @brief Next value logic
    --! - reset at start
    combNext :
    process(iData, reg_q, cntout,memEn,filter_end)
    begin

        reg_next    <= reg_q;

        if (memEn='0' and filter_end='0') then --deleting the last Ethertype
            reg_next    <= (others=>'0');

        elsif (memEn='1' and filter_end='0') then --TODO Rewrite this storage logic with an array
            reg_next((gTo-gFrom-to_integer(unsigned(cntout))+1)*cByteLength-1 downto (gTo-gFrom-to_integer(unsigned(cntout)))*cByteLength)<= iData;
--  e.g.    reg_next(    (10    -                      3    +1)*cByteLength-1 downto (    10    -                       3   )*cByteLength)<= iData;
--  =       reg_next(8*8-1 downto 7*8) =reg_next(63 downto 56)<=iData(7 downto 0);

        end if;

    end process;

    --Output
    oFrameData          <= reg_q;
    oCollectorFinished  <= filter_end;

end two_seg_arch;