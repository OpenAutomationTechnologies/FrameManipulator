-------------------------------------------------------------------------------
--! @file Frame_Create_FSM.vhd
--! @brief FSM for creating Ethernet frames and the TXDV signal
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
--! use global library
use work.global.all;


--! This is the entity of the FSM for creating Ethernet frames and the TXDV signal
entity Frame_Create_FSM is
    generic(
            gSafetyPackSelCntWidth  : natural :=8   --! Width of counter to select safety packet
            );
    port(
        iClk                : in std_logic;                     --! clk
        iReset              : in std_logic;                     --! reset

        iFrameStart         : in std_logic;                     --! start of a new frame
        iReadBuffDone       : in std_logic;                     --! buffer reading has reched the last position

        iPacketExchangeEn   : in std_logic;                                 --! Start of the exchange of the safety packet
        iPacketStart        : in std_logic_vector(cByteLength-1 downto 0);  --! Start of safety packet
        iPacketSize         : in std_logic_vector(cByteLength-1 downto 0);  --! Size of safety packet
        oExchangeData       : out std_logic;                                --! Exchanging safety data

        oPreambleActive     : out std_logic;                    --! activate preamble_generator
        oPreReadBuff        : out std_logic;                    --! activate pre-reading
        oReadBuffActive     : out std_logic;                    --! activate reading from data-buffer
        oCrcActive          : out std_logic;                    --! activate CRC calculation

        oSelectTX           : out std_logic_vector(1 downto 0); --! selection beween the preamble, payload and crc
        oNextFrame          : out std_logic;                    --! FSM is ready for new data
        oTXDV               : out std_logic                     --! TX Data Valid
     );
end Frame_Create_FSM;


--! @brief Frame_Create_FSM architecture
--! @details The FSM for creating Ethernet frames and the TXDV signal
architecture Behave of Frame_Create_FSM is

    constant cCntWidth  : natural:=6;   --! Width of time counter TODO transfer to FM package

    --timings: -- TODO transfer to FM package
    constant cPramble_Time  : natural := 31;    --! 8Byte => 8Byte*8Bit/2Width => 32
    constant cPre_Read_Time : natural := 5;     --! Forerun of the reading logic of 5 cycles
    constant cCRC_Time      : natural := 15;    --! 4Byte => 4Byte*8Bit/2Width => 16
    constant cIPG_Time      : natural := 43;    --! Whole delay of 960ns => here 880ns + process time


    --States
    type tMcState is
            (
            sIdle,          --! ready for the next frame-data
            sPreamble,      --! starts the Preamble_Generator
            sPre_read,      --! pre-start of Read Logic to compensate delay
            sRead,          --! loads and converts frame payload
            sSafetyRead,    --! Activate safety packet exchange
            sCrc,           --! starts CRC_calculator
            sWait_IPG       --! waits a few cycles to keep the Inter Packet Gap of 960ns
            );

    signal state_reg    : tMcState; --! Current state
    signal state_next   : tMcState; --! Next state

    --counter variables
    signal clearCnt     : std_logic;                                            --! Clear of timing counter
    signal clearPCnt    : std_logic;                                            --! Clear of packet counter
    signal cnt          : std_logic_vector(cCntWidth-1 downto 0);               --! Counter for timings
    signal pCnt         : std_logic_vector(gSafetyPackSelCntWidth-1 downto 0);  --! Byte counter for packet exchange
    signal pCntPre      : std_logic;                                            --! Prescaler for packet counter

begin

    --! @brief counter for timings
    FSM_Cnter : work.Basic_Cnter
    generic map(gCntWidth   => cCntWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => clearCnt,
            iEn         => '1',
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => cnt,
            oOv         => open
            );


    --! @brief prescaler for safety counter
    --! - starts with Ov to eliminate register delay
    Packet_Prescaler : work.Basic_Cnter
    generic map(gCntWidth   => 2)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => clearPCnt,
            iEn         => '1',
            iStartValue => "11",
            iEndValue   => (others=>'1'),
            oQ          => open,
            oOv         => pCntPre
            );


    --! @brief safety counter for packet exchange
    --! - starts with value 1
    Packet_Cnter : work.Basic_Cnter
    generic map(gCntWidth   => gSafetyPackSelCntWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => clearPCnt,
            iEn         => pCntPre,
            iStartValue => (0=>'1',others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => pCnt,
            oOv         => open
            );


    --state register

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            state_reg <= sIdle;

        elsif rising_edge(iClk) then
            state_reg <= state_next;

        end if;
    end process;


    --! @brief next-state logic
    process(state_reg, iFrameStart, iReadBuffDone,cnt,pCnt,iPacketExchangeEn,iPacketStart,iPacketSize)
    begin
        case state_reg is

            when sIdle =>
                if iFrameStart='1' then
                    state_next  <= sPreamble;   --start of preamble after start

                else
                    state_next  <= sIdle;

                end if;

            when sPreamble =>
                if cnt=std_logic_vector(to_unsigned(cPramble_Time-cPre_Read_Time,cnt'length)) then
                    state_next  <= sPre_read;   --pre-read after constant timing

                else
                    state_next  <= sPreamble;

                end if;

            when sPre_read =>
                if iReadBuffDone='1' then
                    state_next  <= sCrc;    --goto CRC, when there's no payload (e.g. frame cut to size of 0)

                elsif cnt=std_logic_vector(to_unsigned(cPramble_Time,cnt'length)) then
                    state_next  <= sRead;   --read after timing

                else
                    state_next  <= sPre_read;

                end if;

            when sRead =>
                if iReadBuffDone='1' then
                    state_next  <= sCrc;    --start CRC after reaching the end

                elsif (iPacketExchangeEn='1' and unsigned(pCnt)=unsigned(iPacketStart)) then
                    state_next  <= sSafetyRead;

                else
                    state_next  <= sRead;

                end if;

            when sSafetyRead =>
                if unsigned(pCnt)=unsigned(iPacketStart)+unsigned(iPacketSize) then
                    state_next  <= sRead;

                else
                    state_next  <= sSafetyRead;

                end if;

            when sCrc =>
                if cnt=std_logic_vector(to_unsigned(cCRC_Time,Cnt'length)) then
                    state_next  <= sWait_IPG;   --goto waiting after CRC has finished

                else
                    state_next  <= sCrc;

                end if;

            when sWait_IPG =>
                if cnt>std_logic_vector(to_unsigned(cCRC_Time+cIPG_Time,Cnt'length)) and iFrameStart='0' then
                    state_next  <= sIdle;   --goto idle after waiting for the IPG

                else
                    state_next  <= sWait_IPG;

                end if;

        end case;
    end process;


    --! @brief Moore output
    process(state_reg)
    begin

        oPreambleActive     <= '0';
        oReadBuffActive     <= '0';
        oPreReadBuff        <= '0';

        oNextFrame  <= '0';

        clearCnt    <= '0';
        clearPCnt   <= '1';             --always inactive

        case state_reg is
            when sIdle=>                --IDLE:
                clearCnt        <= '1'; --deaktivates Cnter
                oNextFrame      <= '1'; --FSM is ready for new data

            when sPreamble=>            --PREAMBLE
                oPreambleActive <= '1'; --preamble is active

            when sPre_read=>            --PRE-READ
                oPreambleActive <= '1'; --preamble is active
                oPreReadBuff    <= '1'; --Read-Logic is active, too

            when sRead=>                --READ
                clearCnt        <= '1'; --Cnter is inactive
                clearPCnt       <= '0'; --Packet Cnter is active
                oReadBuffActive <= '1'; --Read-Logic is active

            when sSafetyRead=>          --READ
                clearCnt        <= '1'; --Cnter is inactive
                clearPCnt       <= '0'; --Packet Cnter is active
                oReadBuffActive <= '1'; --Read-Logic is active

            when sCrc=>                 --CRC (is Meely to compensate one cycle of delay)
                null;

            when sWait_IPG=>            --WAIT_IPG (doesn't need output)
                null;

        end case;

    end process;


    --Meely Output
    oCrcActive  <= '1' when state_next=sCrc  else '0';    --CRC start


    --! @brief Select TX and TXDV
    process(state_reg,state_next)
    begin
        oSelectTX       <= "00";
        oTXDV           <= '0';
        oExchangeData   <= '0';

        case state_reg is
            when sIdle=>

            when sPreamble=>
                oSelectTX   <= "01";
                oTXDV       <= '1';

            when sPre_read=>
                oSelectTX   <= "01";
                oTXDV       <= '1';

            when sRead=>
                oSelectTX   <= "11";
                oTXDV       <= '1';

            when sSafetyRead=>
                oSelectTX       <= "11";
                oTXDV           <= '1';
                oExchangeData   <= '1';

            when sCrc=>
                --below the case with state_next to save one cycle
                null;

            when sWait_IPG=>
                null;

        end case;

        if state_next=sCrc then
            oSelectTX   <= "10";
            oTXDV       <= '1';

        end if;

    end process;

end Behave;