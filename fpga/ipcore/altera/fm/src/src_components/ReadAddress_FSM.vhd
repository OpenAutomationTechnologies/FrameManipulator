-------------------------------------------------------------------------------
--! @file ReadAddress_FSM.vhd
--! @brief FSM for reading the frame addresss Fifo
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


--! Entity of the FSM for reading the frame addresss Fifo
entity ReadAddress_FSM is
    generic(
            gAddrDataWidth  : natural := 11;    --! Address width of the frame buffer
            gBuffBitWidth   : natural := 16     --! Width of the FiFo data
            );
    port(
        iClk            : in std_logic;     --! clk
        iReset          : in std_logic;     --! reset
        --control signals
        iNextFrame      : in std_logic;     --! frame-creator is ready for new data
        iDataReady      : in std_logic;     --! address data is ready
        oStart          : out std_logic;    --! start new frame
        --fifo signals
        oRd             : out std_logic;                                    --! read fifo
        iFifoData       : in std_logic_vector(gBuffBitWidth-1 downto 0);    --! fifo data
        --new frame positions
        oDataOutStart   : out std_logic_vector(gAddrDataWidth-1 downto 0);  --! start address of new frame
        oDataOutEnd     : out std_logic_vector(gAddrDataWidth-1 downto 0)   --! end address of new frame
    );
end ReadAddress_FSM;


--! @brief ReadAddress_FSM architecture
--! @details FSM for reading the Fifo and storing the addresses from the fifo
--! - It starts a new frame when the Frame-Creator and new frame-data addresses are ready.
architecture two_seg_arch of ReadAddress_FSM is

    --! Typedef for states
    type tMcState is
        (
        sIdle,                  --! Wait for ready-signal from the Frame-Creator
        sWaitNewFrameData,   --! Wait for new frame data/start address
        sStartFrame,           --! Stores start address
        sWaitEndAddr,         --! Wait for valid end position
        sRdEndAddr            --! Stores end address
        );

    signal state_reg    : tMcState; --! Current state
    signal state_next   : tMcState; --! Next state

    --register: start address of new frame
    signal next_dataOutStart    : std_logic_vector(gAddrDataWidth-1 downto 0);  --! Next start address
    signal reg_dataOutStart     : std_logic_vector(gAddrDataWidth-1 downto 0);  --! Start address of new frame

    --register: end address of new frame
    signal next_dataOutEnd  : std_logic_vector(gAddrDataWidth-1 downto 0);  --! Next end address
    signal reg_dataOutEnd   : std_logic_vector(gAddrDataWidth-1 downto 0);  --! End address of new frame

begin

    --register

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg_dataOutEnd      <= (others=>'0');
            reg_dataOutStart    <= (others=>'0');
            state_reg           <= sIdle;

        elsif rising_edge(iClk) then
            reg_dataOutEnd      <= next_dataOutEnd;
            reg_dataOutStart    <= next_dataOutStart;
            state_reg           <= state_next;

        end if;
    end process;


    --! @brief next state logic
    process(state_reg,iDataReady,iNextFrame)
    begin
       case state_reg is

            when sIdle=>
                if iNextFrame='1' then                  --if Frame-Creator is ready
                    state_next  <= sWaitNewFrameData;    --check of new frame data

                else
                    state_next  <= sIdle;

                end if;

            when sWaitNewFrameData=>
                if iDataReady='1' then          --if new data is ready
                    state_next  <= sStartFrame;    --start a new frame

                else
                    state_next  <= sWaitNewFrameData;

                end if;

            when sStartFrame=>
                state_next  <= sWaitEndAddr;  --goto: wait for end address

            when sWaitEndAddr=>
                if iDataReady='1' then          --if data is ready
                    state_next  <= sRdEndAddr;    --read end address

                else
                    state_next  <= sWaitEndAddr;

                end if;

            when sRdEndAddr=>
                state_next  <= sIdle;               --goto: idle

        end case;
    end process;

    --! @brief Moore output
    process(state_reg,reg_dataOutStart,reg_dataOutEnd,iFifoData)
    begin

        --store addresses
        next_dataOutStart   <= reg_dataOutStart;
        next_dataOutEnd     <= reg_dataOutEnd;

        oDataOutStart   <= reg_dataOutStart;
        oDataOutEnd     <= reg_dataOutEnd;
        oRd             <= '0';
        oStart          <= '0';

        case state_reg is
            when sIdle=>
                null;

            when sWaitNewFrameData=>
                null;

            when sStartFrame=>                     --start new frame
                oRd                 <= '1';         --read fifo
                oStart              <= '1';         --set start signal
                oDataOutStart       <= iFifoData;   --store start address
                next_dataOutStart   <= iFifoData;

            when sWaitEndAddr=>
                null;

            when sRdEndAddr=>                 --read end address
                oRd             <= '1';         --read fifo
                oDataOutEnd     <= iFifoData;   --store end address
                next_dataOutEnd <= iFifoData;

        end case;

    end process;

end two_seg_arch;