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


end framemanipulatorPkg;

package body framemanipulatorPkg is



end framemanipulatorPkg;