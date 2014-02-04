-------------------------------------------------------------------------------
--! @file FiFo_File.vhd
--! @brief RAM with single port
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


--! This is the entity of a RAM with a single port
entity FiFo_File is --TODO Rename to SinglePortRAM
    generic(
            gDataWidth  : natural:=8;   --! Word width
            gAddrWidth  : natural:=8    --! Address width
            );
    port(
        iClk    : in std_logic;                                 --! clock
        iWrEn   : in std_logic;                                 --! Write FiFo
        iWrAddr : in std_logic_vector(gAddrWidth-1 downto 0);   --! Write address
        iRdAddr : in std_logic_vector(gAddrWidth-1 downto 0);   --! Read address
        iWrData : in std_logic_vector(gDataWidth-1 downto 0);   --! Write data
        oRdData : out std_logic_vector(gDataWidth-1 downto 0)   --! Read data
        );
end FiFo_File;


--! @brief FiFo_File architecture
--! @details RAM with single port
--! - Source: RTL Hardware Design Using VHDL
--! - Updated for usage of M9Ks of Altera FPGAs instead of LCs
--! - Register at read address
architecture arch_Altera of FiFo_File is

    --! Typedef RAM array
    type reg_file_type is array (2**gAddrWidth-1 downto 0) of
        std_logic_vector(gDataWidth-1 downto 0);

    signal array_reg    : reg_file_type := (others=>(others=>'0')); --! RAM array
    signal rdAddr_reg   : std_logic_vector(gAddrWidth-1 downto 0);  --! Register of read address


begin

    --! @brief Memory
    --! - Register array without reset
    process(iClk)
    begin
        if rising_edge(iClk) then
            if iWrEn='1' then
                array_reg(to_integer(unsigned(iWrAddr)))<=iWrData;

            end if;

            rdAddr_reg<=iRdAddr;

        end if;
    end process;

    oRdData <= array_reg(to_integer(unsigned(rdAddr_reg)));

end arch_Altera;