-------------------------------------------------------------------------------
--! @file FiFo_top.vhd
--! @brief FiFo top-module
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


--! This is the entity of a fifo top-module
entity FiFo_top is
    generic(
            gDataWidth  : natural := 8; --! Word width
            gAddrWidth  : natural := 8; --! Address width
            gCnt_Mode   : natural := 0  --! binary or LFSR(not included yet)
            ); --TODO Change Names of generic
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iRd         : in std_logic;                                 --! Read FiFo
        iWr         : in std_logic;                                 --! Write FiFo
        iWrData     : in std_logic_vector(gDataWidth-1 downto 0);   --! Data in
        oFull       : out std_logic;                                --! FiFo is full
        oEmpty      : out std_logic;                                --! FiFo is empty
        oRdData     : out std_logic_vector(gDataWidth-1 downto 0)   --! Data out
     );
end FiFo_top;



--! @brief FiFo_top architecture
--! @details Top-module of FiFo
--! - Source: RTL Hardware Design Using VHDL
architecture arch of FiFo_top is

    signal rd_addr  : std_logic_vector(gAddrWidth-1 downto 0);  --! Read address
    signal wr_addr  : std_logic_vector(gAddrWidth-1 downto 0);  --! Write address
    signal f_status : std_logic;                                --! Fifo full
    signal wr_fifo  : std_logic;                                --! Write FiFo when not full

begin

    --! @brief Fifo control
    cntr : entity work.fifo_sync_ctrl
    generic map(
                gAddrWidth  => gAddrWidth,
                gCnt_Mode   => gCnt_Mode
                )
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iRd     => iRd,
            iWr     => iWr,
            oWrAddr => wr_addr,
            oRdAddr => rd_addr,
            oFull   => f_status,
            oEmpty  => oEmpty
            );

    wr_fifo <= iWr and (not f_status);
    oFull   <= f_status;

    --! @brief Fifo memory
    reg : entity work.fifo_file
    generic map(
                gDataWidth  => gDataWidth,
                gAddrWidth  => gAddrWidth
                )
    port map(
            iClk    => iClk,
            iWrEn   => wr_fifo,
            iWrAddr => wr_addr,
            iRdAddr => rd_addr,
            iWrData => iWrData,
            oRdData => oRdData
            );

end arch;