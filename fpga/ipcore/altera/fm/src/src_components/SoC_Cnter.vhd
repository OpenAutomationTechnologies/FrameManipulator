-------------------------------------------------------------------------------
--! @file SoC_Cnter.vhd
--! @brief Counter of POWERLINK cycles via SoC frames
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


--! This is the entity of the module for counting POWERLINK cycles via SoC frames
entity SoC_Cnter is
    generic(gCnterWidth : natural := 8);                            --! Width of Counter
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iTestSync   : in std_logic;                                 --! sync for counter reset
        iFrameSync  : in std_logic;                                 --! sync for new incoming frame
        iEn         : in std_logic;                                 --! counter enable
        iData       : in std_logic_vector(gCnterWidth-1 downto 0);  --! frame-data
        oFrameIsSoc : out std_logic;                                --! current frame is a SoC
        oSocCnt     : out std_logic_vector(gCnterWidth-1 downto 0)  --! number of received SoCs
    );
end SoC_Cnter;


--! @brief SoC_Cnter architecture
--! @details A Counter for Ethernet POWERLINK Cycles with recoginizing the SoC Frames
architecture two_seg_arch of SoC_Cnter is

    signal cntEn                : std_logic;                                --! Counter Enable
    signal collectorFinished    : std_logic;                                --! messageType has received
    signal messageType          : std_logic_vector(cByteLength-1 downto 0); --! value of messageType

    --Edge Detection
    signal next_frameFit    : std_logic;    --! Next value for register
    signal reg_frameFit     : std_logic;    --! Register of fitting frame (SoC)

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg_frameFit    <= '0';

        elsif rising_edge(iClk) then
            reg_frameFit    <= next_frameFit;

        end if;
    end process;


    --! @brief Collector for POWERLINK SoC
    messageType_Collector : entity work.Frame_collector
    generic map(
                gFrom   => cEth.StartmessageType,
                gTo     => cEth.StartmessageType
                )
    port map(
            iClk                => iClk,
            iReset              => iReset,
            iData               => iData,
            iSync               => iFrameSync,
            oFrameData          => messageType,
            ocollectorFinished  => collectorFinished
            );


    --Frame is SoC, when messageType=SoC and data is valid
    next_frameFit   <= collectorFinished when messageType = cEth.messageTypeSoC else '0';

    --Edge Detection for Counter
    cntEn   <= '1' when iEn='1' and next_frameFit='1' and reg_frameFit='0' else '0';


    --! @brief Cycle Counter
    Cnter : entity work.Basic_Cnter
    generic map(gCntWidth=>gCnterWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => iTestSync,
            iEn         => cntEn,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => oSocCnt,
            oOv         => open
            );


    --current frame is Soc output
    oFrameIsSoc <= reg_frameFit;

end two_seg_arch;