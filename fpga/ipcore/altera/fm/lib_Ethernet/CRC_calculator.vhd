-------------------------------------------------------------------------------
--! @file CRC_calculator.vhd
--! @brief CRC Calculator for Ethernet frames
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
--    THis SOFTWARE is PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--    "AS is" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT not
--    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--    FOR A PARTICULAR PURPOSE ARE DisCLAIMED. IN NO EVENT SHALL THE
--    COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--    BUT not LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
--    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
--    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWisE) ARisING IN
--    ANY WAY OUT OF THE USE OF THis SOFTWARE, EVEN if ADVisED OF THE
--    POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------


--! Use standard ieee library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric functions
use ieee.numeric_std.all;

--! This is the entity of the crc calculation
entity CRC_calculator is
    port(
        iClk                : in std_logic;                     --! clock
        iReadBuffActive     : in std_logic;                     --! Frame data are read from the memory
        iCrcActive          : in std_logic;                     --! CRC can be put out
        iCRCMani            : in std_logic;                     --! CRC of this frame will be manipulated
        iTXD                : in std_logic_vector(1 downto 0);  --! Data stream in
        oTXD                : out std_logic_vector(1 downto 0)  --! Data stream out
    );
end CRC_calculator;


--! @brief CRC_calculator architecture
--! @details This is the RC Calculator for Ethernet frames
architecture Behave of CRC_calculator is

    signal  crc     : std_logic_vector(31 downto 0);    --! Calculated CRC
    signal  crcDin  : std_logic_vector( 1 downto 0);    --! Stream for calculation

begin


crcDin <= iTXD(1 downto 0) when iCRCMani='0' else not iTXD(1 downto 0);

--! @brief Calculate CRC
Calc :
process ( iClk, crc, crcDin )   is
    variable    H : std_logic_vector(1 downto 0);
    begin

    H(0) := crc(31) xor crcDin(0);
    H(1) := crc(30) xor crcDin(1);


    if rising_edge( iClk )  then

        if iCrcActive = '1'    then   --output
            Crc <= crc(29 downto 0) & "00";

        elsif       iReadBuffActive = '1' then  --calculation

            crc( 0) <=                      H(1);
            crc( 1) <=             H(0) xor H(1);
            crc( 2) <= crc( 0) xor H(0) xor H(1);
            crc( 3) <= crc( 1) xor H(0)         ;
            crc( 4) <= crc( 2)          xor H(1);
            crc( 5) <= crc( 3) xor H(0) xor H(1);
            crc( 6) <= crc( 4) xor H(0)         ;
            crc( 7) <= crc( 5)          xor H(1);
            crc( 8) <= crc( 6) xor H(0) xor H(1);
            crc( 9) <= crc( 7) xor H(0)         ;
            crc(10) <= crc( 8)          xor H(1);
            crc(11) <= crc( 9) xor H(0) xor H(1);
            crc(12) <= crc(10) xor H(0) xor H(1);
            crc(13) <= crc(11) xor H(0)         ;
            crc(14) <= crc(12)                  ;
            crc(15) <= crc(13)                  ;
            crc(16) <= crc(14)          xor H(1);
            crc(17) <= crc(15) xor H(0)         ;
            crc(18) <= crc(16)                  ;
            crc(19) <= crc(17)                  ;
            crc(20) <= crc(18)                  ;
            crc(21) <= crc(19)                  ;
            crc(22) <= crc(20)          xor H(1);
            crc(23) <= crc(21) xor H(0) xor H(1);
            crc(24) <= crc(22) xor H(0)         ;
            crc(25) <= crc(23)                  ;
            crc(26) <= crc(24)          xor H(1);
            crc(27) <= crc(25) xor H(0)         ;
            crc(28) <= crc(26)                  ;
            crc(29) <= crc(27)                  ;
            crc(30) <= crc(28)                  ;
            crc(31) <= crc(29)                  ;

        else                       --else FF
            crc <= x"FFFFFFFF";

        end if;
    end if;
end process Calc;


    oTXD <= not crc(30) & not crc(31);

end Behave;