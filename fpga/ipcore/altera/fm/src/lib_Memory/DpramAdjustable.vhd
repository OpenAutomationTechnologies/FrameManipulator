-------------------------------------------------------------------------------
--! @file DpramAdjustable.vhd
--! @brief Dual port RAM with different ports by altera wizard
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

--! Use altera megafunction lib
library altera_mf;
--! Use altera megafunction
use altera_mf.altera_mf_components.all;

--! Use work library
library work;

--! Common library
library libcommon;
--! Use common library global package
use libcommon.global.all;



--! This is the entity of the dual port RAM with different ports
entity DpramAdjustable is
    generic(
            gAddresswidthA  : natural := 7;     --! Width of address port A
            gAddresswidthB  : natural := 6;     --! Width of address port B
            gWordWidthA     : natural := 32;    --! Width of data port A
            gWordWidthB     : natural := 64     --! Width of data port B
            );
    port
    (
        iAddress_a  : in std_logic_vector (gAddresswidthA-1 downto 0);                                --! Address port A
        iAddress_b  : in std_logic_vector (gAddresswidthB-1 downto 0);                                --! Address port B
        iByteena_a  : in std_logic_vector ((gWordWidthA/cByteLength)-1 downto 0) :=  (others => '1'); --! Byte enable port A
        iByteena_b  : in std_logic_vector ((gWordWidthB/cByteLength)-1 downto 0) :=  (others => '1'); --! Byte enable port B
        iClock_a    : in std_logic  := '1';                                                           --! clock port A
        iClock_b    : in std_logic;                                                                   --! clock port B
        iData_a     : in std_logic_vector (gWordWidthA-1 downto 0);                                   --! Data in port A
        iData_b     : in std_logic_vector (gWordWidthB-1 downto 0);                                   --! Data in port B
        iRden_a     : in std_logic := '1';                                                            --! Read enable port A
        iRden_b     : in std_logic := '1';                                                            --! Read enable port B
        iWren_a     : in std_logic := '0';                                                            --! Write enable port A
        iWren_b     : in std_logic := '0';                                                            --! Write enable port B
        oQ_a        : out std_logic_vector (gWordWidthA-1 downto 0);                                  --! Data out port A
        oQ_b        : out std_logic_vector (gWordWidthB-1 downto 0)                                   --! Data out port B
    );
end DpramAdjustable;


--! @brief DpramAdjustable architecture
--! @details Generated DPRAM from altera wizard
--! - With different address and word width
--! - With read enable
--! - With byte enable
--! - No register at output Q
architecture rtl of DpramAdjustable is

    signal sub_wire0    : std_logic_vector (gWordWidthA-1 downto 0);    --! temporary signal
    signal sub_wire1    : std_logic_vector (gWordWidthB-1 downto 0);    --! temporary signal

begin

    oQ_a   <= sub_wire0(gWordWidthA-1 downto 0);
    oQ_b   <= sub_wire1(gWordWidthB-1 downto 0);

    altsyncram_component : altsyncram
    generic map(
        address_reg_b                   => "CLOCK1",
        byte_size                       => 8,
        clock_enable_input_a            => "BYPASS",
        clock_enable_input_b            => "BYPASS",
        clock_enable_output_a           => "BYPASS",
        clock_enable_output_b           => "BYPASS",
        indata_reg_b                    => "CLOCK1",
        intended_device_family          => "Cyclone IV E",
        lpm_type                        => "altsyncram",
        numwords_a                      => 2**gAddresswidthA,
        numwords_b                      => 2**gAddresswidthB,
        operation_mode                  => "BIDIR_DUAL_PORT",
        outdata_aclr_a                  => "NONE",
        outdata_aclr_b                  => "NONE",
        outdata_reg_a                   => "UNREGISTERED",
        outdata_reg_b                   => "UNREGISTERED",
        power_up_uninitialized          => "FALSE",
        ram_block_type                  => "M9K",
        read_during_write_mode_port_a   => "NEW_DATA_NO_NBE_READ",
        read_during_write_mode_port_b   => "NEW_DATA_NO_NBE_READ",
        widthad_a                       => gAddresswidthA,
        widthad_b                       => gAddresswidthB,
        width_a                         => gWordWidthA,
        width_b                         => gWordWidthB,
        width_byteena_a                 => (gWordWidthA/8),
        width_byteena_b                 => (gWordWidthB/8),
        wrcontrol_wraddress_reg_b       => "CLOCK1"
    )
    port map(
        byteena_a   => iByteena_a,
        byteena_b   => iByteena_b,
        clock0      => iClock_a,
        wren_a      => iWren_a,
        clock1      => iClock_b,
        rden_a      => iRden_a,
        wren_b      => iWren_b,
        address_a   => iAddress_a,
        data_a      => iData_a,
        rden_b      => iRden_b,
        address_b   => iAddress_b,
        data_b      => iData_b,
        q_a         => sub_wire0,
        q_b         => sub_wire1
    );



end rtl;
