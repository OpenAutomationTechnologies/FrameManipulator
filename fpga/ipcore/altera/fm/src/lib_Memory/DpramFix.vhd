-------------------------------------------------------------------------------
--! @file DpramFix.vhd
--! @brief Dual port RAM with identical ports by altera wizard
--! @details This is the DPRAM intended for synthesis on Altera platforms only.
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
--    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, inCLUDinG, BUT NOT
--    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. in NO EVENT SHALL THE
--    COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, inDIRECT,
--    inCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (inCLUDinG,
--    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--    LOSS OF USE, DATA, OR PROFITS; OR BUSinESS inTERRUPTION) HOWEVER
--    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER in CONTRACT, STRICT
--    LIABILITY, OR TORT (inCLUDinG NEGLIGENCE OR OTHERWISE) ARISinG in
--    ANY WAY out OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--    POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------



--! Use standard ieee library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric functions
use ieee.numeric_std.all;

--! Use altera megafunction lib
library altera_mf;
--! Use altera megafunction
use altera_mf.altera_mf_components.all;


--! This is the entity of the dual port RAM
entity DpramFix is
    generic(
            gWordWidth  : natural := 8; --! Width of data
            gAddrWidth  : natural := 11 --! Width of address
            );
    port(
        iAddress_a  : in std_logic_vector (gAddrWidth-1 downto 0);  --! Address port A
        iAddress_b  : in std_logic_vector (gAddrWidth-1 downto 0);  --! Address port B
        iClock      : in std_logic  := '1';                         --! clock
        iData_a     : in std_logic_vector (gWordWidth-1 downto 0);  --! Data in port A
        iData_b     : in std_logic_vector (gWordWidth-1 downto 0);  --! Data in port B
        iRden_a     : in std_logic  := '1';                         --! Read enable port A
        iRden_b     : in std_logic  := '1';                         --! Read enable port B
        iWren_a     : in std_logic  := '0';                         --! Write enable port A
        iWren_b     : in std_logic  := '0';                         --! Write enable port B
        oQ_a        : out std_logic_vector (gWordWidth-1 downto 0); --! Data out port A
        oQ_b        : out std_logic_vector (gWordWidth-1 downto 0)  --! Data out port B
        );
end DpramFix;


--! @brief DpramFix architecture
--! @details Generated DPRAM from altera wizard
--! - With read enable
--! - With no byte enable
--! - Register at output Q
architecture rtl of DpramFix is

    signal sub_wire0    : std_logic_vector (gWordWidth-1 downto 0); --! temporary signal
    signal sub_wire1    : std_logic_vector (gWordWidth-1 downto 0); --! temporary signal

begin

    oQ_a   <= sub_wire0(gWordWidth-1 downto 0);
    oQ_b   <= sub_wire1(gWordWidth-1 downto 0);

    --! @brief altera altsyncram
    altsyncram_component : altsyncram
    generic map(
        address_reg_b                       => "CLOCK0",
        clock_enable_input_a                => "BYPASS",
        clock_enable_input_b                => "BYPASS",
        clock_enable_output_a               => "BYPASS",
        clock_enable_output_b               => "BYPASS",
        indata_reg_b                        => "CLOCK0",
        intended_device_family              => "Cyclone IV E",
        lpm_type                            => "altsyncram",
        numwords_a                          => 2**gAddrWidth,
        numwords_b                          => 2**gAddrWidth,
        operation_mode                      => "BIDIR_DUAL_PORT",
        outdata_aclr_a                      => "NONE",
        outdata_aclr_b                      => "NONE",
        outdata_reg_a                       => "CLOCK0",
        outdata_reg_b                       => "CLOCK0",
        power_up_uninitialized              => "FALSE",
        ram_block_type                      => "M9K",
        read_during_write_mode_mixed_ports  => "DONT_CARE",
        read_during_write_mode_port_a       => "NEW_DATA_NO_NBE_READ",
        read_during_write_mode_port_b       => "NEW_DATA_NO_NBE_READ",
        widthad_a                           => gAddrWidth,
        widthad_b                           => gAddrWidth,
        width_a                             => gWordWidth,
        width_b                             => gWordWidth,
        width_byteena_a                     => 1,
        width_byteena_b                     => 1,
        wrcontrol_wraddress_reg_b           => "CLOCK0"
    )
    port map(
        clock0      => iClock,
        wren_a      => iWren_a,
        address_b   => iAddress_b,
        data_b      => iData_b,
        rden_a      => iRden_a,
        wren_b      => iWren_b,
        address_a   => iAddress_a,
        data_a      => iData_a,
        rden_b      => iRden_b,
        q_a         => sub_wire0,
        q_b         => sub_wire1
    );


end rtl;
