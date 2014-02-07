-------------------------------------------------------------------------------
--! @file end_of_frame_detection.vhd
--! @brief Listens to the RX Data Valid signal and saves the address of the last Byte
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

--! This is the entity of the Ethernet frame end detection
entity end_of_frame_detection is
    generic(
            gBuffAddrWidth  : natural := 11 --! Address width of frame buffer
            );
    port(
        iClk        : in std_logic;                                     --! clk
        iReset      : in std_logic;                                     --! reset
        iRXDV       : in std_logic;                                     --! Data valid signal for end detection
        iAddr       : in std_logic_vector(gBuffAddrWidth-1 downto 0);   --! Current frame-buffer address
        iStartAddr  : in std_logic_vector(gBuffAddrWidth-1 downto 0);   --! Start address of the stored frame

        iCutEn      : in std_logic;                                     --! Cut manipulation is enabled
        iCutData    : in std_logic_vector(gBuffAddrWidth-1 downto 0);   --! Size of the truncated frame

        oEndAddr    : out std_logic_vector(gBuffAddrWidth-1 downto 0);  --! End address of the stored frame
        oFrameEnd   : out std_logic                                     --! End has been reached
    );
end end_of_frame_detection;


--! @brief end_of_frame_detection architecture
--! @details Detects the end of a frame and stores its end-address
--! - Detects frame end with RX-data-valid
--! - Stores end address of the frame
--! - Manipulates end address at cut-task
architecture Behave of end_of_frame_detection is

    --register for the last Edge detection
    signal addr_reg     : std_logic_vector(gBuffAddrWidth-1 downto 0);  --! Register of address
    signal addr_next    : std_logic_vector(gBuffAddrWidth-1 downto 0);  --! Next value of address register
    signal rxD_reg      : std_logic_vector(2 downto 0);                 --! In shift register stored RX data valid signal

    signal cutAddr  : std_logic_vector(gBuffAddrWidth-1 downto 0);  --! Manipulated end address of the truncated frame
    signal newAddr  : std_logic_vector(gBuffAddrWidth-1 downto 0);  --! Next Address

    --register for end of frame
    signal end_reg  : std_logic;    --! Register of reached-end signal
    signal end_next : std_logic;    --! Next value of end signal register

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            addr_reg    <= (others => '0');
            end_reg     <= '0';

        elsif rising_edge(iClk) then
            addr_reg    <= addr_next;
            end_reg     <= end_next;

        end if;
    end process;


    --! @brief shift register to save the last values of RXDV
    RX_shift : entity work.shift_right_register
    generic map(gWidth  => 3)
    port map(
            iClk    => iClk,
            iReset  => iReset,
            iD      => iRXDV,
            oQ      => rxD_reg
            );


    cutAddr     <=std_logic_vector(unsigned(iStartAddr)+unsigned(iCutData)+5);   -- +4 cause of CRC   +1 for end

    end_next    <= '1' when (rxD_reg="000") or
                            (iCutEn ='1' and (iAddr=cutAddr or (unsigned(iCutData)+5<(unsigned(iAddr)-unsigned(iStartAddr)))))
                            else end_reg and iCutEn;

    newAddr     <= iAddr when   (rxD_reg    = "000") or
                                iCutEn      = '0'
                                else cutAddr;

    addr_next   <= newAddr when end_next    = '1' and
                                end_reg     = '0'
                                else addr_reg;

    oEndAddr    <= addr_reg;
    oFrameEnd   <= '1' when end_reg='1' else '0';

end Behave;