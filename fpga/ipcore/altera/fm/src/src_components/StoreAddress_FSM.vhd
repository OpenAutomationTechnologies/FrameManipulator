-------------------------------------------------------------------------------
--! @file StoreAddress_FSM.vhd
--! @brief FSM for storing the start- and end-position of the frame-data into the fifo
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

--! This is the entity of the FSM for storing the start- and end-position of the frame-data
entity StoreAddress_FSM is
    generic(
            gAddrDataWidth  : natural:=11;              --! Address width of the frame buffer
            gSize_Time      : natural:=5*cByteLength;   --! Delay in 10ns steps
            gFiFoBitWidth   : natural:=52               --! Width of Fifo
            );
    port(
        iClk                : in std_logic;                                     --! clk
        iReset              : in std_logic;                                     --! reset
        --control signals
        iStartStorage       : in std_logic;                                     --! start storing positions
        iFrameEnd           : in std_logic;                                     --! end position is valid
        iDataInEndAddr      : in std_logic_vector(gAddrDataWidth-1 downto 0);   --! end position of the current frame
        oDataInStartAddr    : out std_logic_vector(gAddrDataWidth-1 downto 0);  --! new start position of the next frame
        --tasks
        iCRCManEn           : in std_logic;                                     --! task: crc distortion
        iDelayTime          : in std_logic_vector(gSize_Time-1 downto 0);       --! delay timestamp
        --storing data
        oWr                 : out std_logic;                                    --! write Fifo
        oFiFoData           : out std_logic_vector(gFiFoBitWidth-1 downto 0)    --! Fifo data
    );
end StoreAddress_FSM;


--! @brief StoreAddress_FSM architecture
--! @details FSM for storing the start- and end-position of the frame-data into the fifo
--! - The delay timestamp is connected to the start-address and the CRC-distortion flag
--!   to the end-address.
--! - The Frame-Receiver receives also a new start address for the next frame.
architecture two_seg_arch of StoreAddress_FSM is

    --states
    type tMcState is
        (
        sIdle,      --! Wait for new incoming frame
        sWrStart,   --! Write start address + delay-timestamp to the fifo
        sWait_end,  --! Wait for the valid end address/end of the frame
        sWrEnd,     --! Write end position + CRC-distortion flag
        sWait_stop  --! Wait until the start signal is zero
        );


    signal state_reg    : tMcState; --! State of FSM
    signal state_next   : tMcState; --! Next state of FSM

    --start position register
    signal next_DataInStartAddr : std_logic_vector(gAddrDataWidth-1 downto 0);  --! Next start address
    signal reg_DataInStartAddr  : std_logic_vector(gAddrDataWidth-1 downto 0);  --! Start address of next frame

begin


    --register
    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg_DataInStartAddr <= (others=>'0');
            state_reg           <= sIdle;

        elsif rising_edge(iClk) then
            reg_DataInStartAddr <= next_DataInStartAddr;
            state_reg           <= state_next;

        end if;
    end process;


    --! @brief next state logic
    process(state_reg,iStartStorage,iFrameEnd)
    begin
       case state_reg is

            when sIdle=>
                if iStartStorage='1' then
                    state_next  <= sWrStart;    --when start, then write start position

                else
                    state_next  <= sIdle;

                end if;

            when sWrStart=>
                state_next      <= sWait_end;   --goto wait

            when sWait_end=>
                if iFrameEnd='1' then
                    state_next  <= sWrEnd;      --when end-address is valid, then write end position

                else
                    state_next  <= sWait_end;

                end if;

            when sWrEnd=>
                state_next  <= sWait_stop;      --goto end

            when sWait_stop=>
                if iStartStorage='0' then
                    state_next  <= sIdle;       --goto idle, when start signal is 0

                else
                    state_next  <= sWait_stop;

                end if;

        end case;
    end process;



    --! @brief Moore output
    process(state_reg,reg_DataInStartAddr,iDelayTime,iCRCManEn, iDataInEndAddr)
    begin
        --store and output of new start position
        next_DataInStartAddr    <= reg_DataInStartAddr;
        oDataInStartAddr        <= reg_DataInStartAddr;

        oWr         <= '0';
        oFiFoData   <= (others=>'0');

        case state_reg is
            when sIdle=>

            when sWrStart=>     --writeEnable and fifo-data=delay-timestamp+start position
                oWr         <= '1';
                oFiFoData   <= iDelayTime & reg_DataInStartAddr;

            when sWait_end=>
                null;

            when sWrEnd=>       --writeEnable and fifo-data= CRC Task Flag + end position
                oWr                     <= '1';
                oFiFoData               <= (gFiFoBitWidth-1 downto gAddrDataWidth+1 =>'0')& iCRCManEn & iDataInEndAddr;  --end Address
                next_DataInStartAddr    <= iDataInEndAddr;
                                --start position of the next frame is current end position

            when sWait_stop=>
                null;

        end case;

    end process;



end two_seg_arch;