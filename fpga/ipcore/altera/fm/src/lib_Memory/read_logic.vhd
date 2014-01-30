-------------------------------------------------------------------------------
--! @file read_logic.vhd
--! @brief A read logic for memories
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



--! This is the entity of a read logic for memories
entity read_logic is
    generic(
            gPrescaler  : natural := 4; --! Prescaler value
            gAddrWidth  : natural := 11 --! Width of address
            );
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iEn         : in std_logic;                                 --! Enable module
        iSync       : in std_logic;                                 --! Synchronous reset
        iStartAddr  : in std_logic_vector(gAddrWidth-1 downto 0);   --! Start address
        oRdEn       : out std_logic;                                --! Read enable
        oAddr       : out std_logic_vector(gAddrWidth-1 downto 0)   --! Read address
     );
end read_logic;

--! @brief read_logic architecture
--! @details A read logic for memories with prescaler
architecture two_seg_arch of read_logic is

    signal preEn    : std_logic;    --! prescaled Enable

    signal addr         : std_logic_vector(oAddr'range);    --! New read address
    signal addr_next    : std_logic_vector(oAddr'range);    --! Delayed read address

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            addr_next   <= (others=>'0');

        elsif rising_edge(iClk) then
            addr_next   <= addr;    -- TODO realy needed?

        end if;
    end process;


    --! @brief Include prescaler
    Prescale:
    if gPrescaler>1 generate

        signal cntpre   : std_logic_vector(LogDualis(gPrescaler)-1 downto 0) := (others=>'0');  --! counter value of prescaler

    begin


        --! @brief Prescaler via counter
        difpre_clk : entity work.FixCnter
        generic map (
                    gCntWidth   => LogDualis(gPrescaler),
                    gStartValue => (LogDualis(gPrescaler)-1 downto 0 => '0'),
                    gInitValue  => (LogDualis(gPrescaler)-1 downto 0 => '0'),
                    gEndValue   => to_unsigned(gPrescaler-1,LogDualis(gPrescaler))
                    )
        port map (
                iClk    => iClk,
                iReset  => iReset,
                iClear  => iSync,
                iEn     => iEn,
                oQ      => cntpre,
                oOv     => open
                );

        preEn   <='1' when cntpre=(cntpre'range=>'0') and iEn='1' else '0';

    end generate;



    --! @brief Prescaler disabled
    WithoutPrescale:
    if gPrescaler<=1 generate

        preEn   <='1' when iEn='1' else '0';

    end generate;



    --! @brief Address counter
    buffer_clk : entity work.Basic_Cnter
    generic map (gCntWidth => gAddrWidth)
    port map (
            iClk        => iClk,
            iReset      => iReset,
            iClear      => iSync,
            iEn         => preEn,
            iStartValue => iStartAddr,
            iEndValue   => (others=>'1'),
            oQ          => addr,
            oOv         => open
            );


    oAddr   <= addr;
    oRdEn   <= '1' when addr/=addr_next else '0';   --edge detection

end two_seg_arch;
