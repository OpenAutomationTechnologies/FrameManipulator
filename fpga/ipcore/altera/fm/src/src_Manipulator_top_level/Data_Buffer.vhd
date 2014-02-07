-------------------------------------------------------------------------------
--! @file Data_Buffer.vhd
--! @brief Data buffer for frames
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
--! use fm library
use work.framemanipulatorPkg.all;


--! This is the entity of the frame buffer
entity Data_Buffer is
    generic(
            gDataWidth          : natural := cByteLength;   --! Width of frame stream
            gDataAddrWidth      : natural := 11;            --! Width of address
            gNoOfHeadMani       : natural := 8;             --! Maximal number of manipulated Bytes from frame header
            gTaskWordWidth      : natural := 8*cByteLength; --! Width of task setting
            gManiSettingWidth   : natural := 14*cByteLength --! Width of whole setting
            );
    port
    (
        iClk                    : in std_logic;                                         --! clk
        iReset                  : in std_logic;                                         --! reset
        iData                   : in std_logic_vector(gDataWidth-1 downto 0);           --! write data    Port A
        iRdAddress              : in std_logic_vector(gDataAddrWidth-1 downto 0);       --! read address  Port B
        iRdEn                   : in std_logic;                                         --! read enable   Port B
        iWrAddress              : in std_logic_vector(gDataAddrWidth-1 downto 0);       --! write address Port A
        iWrEn                   : in std_logic  := '0';                                 --! write enable  Port A
        oData                   : out std_logic_vector(gDataWidth-1 downto 0);          --! read data     Port B
        oError_frameBuffOv      : out std_logic;                                        --! Error flag, when overflow occurs

        iManiSetting            : in std_logic_vector(gManiSettingWidth-1 downto 0);    --! header manipulation setting
        iTaskManiEn             : in std_logic;                                         --! header manipulation enable
        iDataStartAddr          : in std_logic_vector(gDataAddrWidth-1 downto 0)        --! start byte of manipulated header
    );
end Data_Buffer;




--! @brief Data_Buffer architecture
--! @details This is the frame buffer
--! - Dual port memory. Write access for the incoming frame-data on port A. Read access for
--!   the created frame, as well as header manipulation, on port B.
--! - The header manipulation setting is stored at the edge of the task enable signal. The
--!   manipulation of up to 8 different bytes are done on port B, while there is no read
--!   access.
architecture two_seg_arch of Data_Buffer is

    --! size selection of the selection counter
    constant cCntWidth  : natural:=LogDualis(gNoOfHeadMani+1);


    --! Typedef for registers
    type tReg is record
        taskManiEn      : std_logic;                                                        --! Register for detection for iTaskManiEn
        dataStartAddr   : std_logic_vector(gDataAddrWidth-1 downto 0);                      --! Start Byte of manipulated frame header
        maniOffset      : std_logic_vector(gManiSettingWidth-gTaskWordWidth-1 downto 0);    --! Offsets of header manipulation
        maniWords       : std_logic_vector(gTaskWordWidth-1 downto 0);                      --! New header data
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                taskManiEn      => '0',
                                dataStartAddr   => (others=>'0'),
                                maniOffset      => (others=>'0'),
                                maniWords       => (others=>'0')
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers


    signal taskManiEn_posEdge   : std_logic;    --! positive edge of iTaskManiEn

    --Selected Data of the Register-----
    signal selManiOffset    : std_logic_vector(cParam.SizeManiHeaderOffset-1 downto 0); --! Selected offset of manipulation task
    signal selManiWords     : std_logic_vector(cParam.SizeManiHeaderData-1 downto 0);   --! Selected data of manipulation task

    --Selection of several Bytes---------
    signal cntEn    : std_logic;                                    --! Enable counter to select to exchange header data
    signal selData  : std_logic_vector(cCntWidth-1 downto 0);       --! Select signal

    --Usage of Port B--------------------
    signal wrEnB    : std_logic;                                    --! Write enable for header manipulation at port B
    signal addressB : std_logic_vector(gDataAddrWidth-1 downto 0);  --! Address for header manipulation at port B



    --! Offset setting of header manipulation
    alias iManiSetting_offset   : std_logic_vector(gManiSettingWidth-gTaskWordWidth-1 downto 0)
                                        is iManiSetting(gManiSettingWidth-1 downto gTaskWordWidth);

    --! New data setting of header manipulation
    alias iManiSetting_words    : std_logic_vector(gTaskWordWidth-1 downto 0)
                                        is iManiSetting(gTaskWordWidth-1 downto 0);

begin

    --! @brief Buffer for Frames
    --! - Port A: incoming frame-data
    --! - Port B: outgoing frame-data and frame header manipulation
    FBuffer : entity work.DpramFix
    generic map(
                gWordWidth  => gDataWidth,
                gAddrWidth  => gDataAddrWidth
                )
    port map(
            iClock      => iClk,
            iAddress_a  => iWrAddress,
            iData_a     => iData,
            iWren_a     => iWrEn,
            iRden_a     => '0',
            oQ_a        => open,
            iAddress_b  => addressB,
            iData_b     => selManiWords,
            iWren_b     => wrEnB,
            iRden_b     => iRdEn,
            oQ_b        => oData
            );


    --Edge Detection of Manipulation Enable-------------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;


    --! @brief Next register value
    --! - Storing of iTaskManiEn for edge detection
    --! - Storing of manipulation setting at edge
    nextComb :
    process(reg, iTaskManiEn, taskManiEn_posEdge, iDataStartAddr, iManiSetting)
    begin
        reg_next    <= reg;

        reg_next.taskManiEn <= iTaskManiEn;

        if TaskManiEn_posEdge='1' then
            reg_next.dataStartAddr  <= iDataStartAddr;
            reg_next.maniOffset     <= iManiSetting_Offset;
            reg_next.maniWords      <= iManiSetting_Words;

        end if;

    end process;


    taskManiEn_posEdge  <= '1' when reg.taskManiEn = '0' and iTaskManiEn = '1' else '0';


    --Counter for Data Selection-------------------------------------------------------------------
    CntEn<= '1' when iRdEn='0' and unsigned(SelData) < gNoOfHeadMani else '0';
    --is counting, when the buffer isn't read at the moment

    --! @brief Counter to select manipulation data with its offset
    --! - Count up, when port B isn't used for reading frame data
    SelCntr : entity work.Basic_Cnter
    generic map(gCntWidth   => cCntWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => taskManiEn_posEdge,
            iEn         => cntEn,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => selData,
            oOv         => open
            );


    --DeMultiplexer to select the Data-------------------------------------------------------------
    --! @brief Multiplexer for manipulation offset
    OffsetMux : entity work.Mux2D
    generic map(
                gWordsWidth => cParam.sizeManiHeaderOffset,
                gWordsNo    => gNoOfHeadMani,
                gWidthSel   => cCntWidth
                )
    port map(
            iData   => reg.maniOffset,
            iSel    => selData,
            oWord   => selManiOffset
            );


    --! @brief Multiplexer for manipulation data
    WordMux : entity work.Mux2D
    generic map(
                gWordsWidth => cParam.sizeManiHeaderData,
                gWordsNo    => gNoOfHeadMani,
                gWidthSel   => cCntWidth
                )
    port map(
            iData   => reg.maniWords,
            iSel    => selData,
            oWord   => selManiWords
            );


    --Usage of Port B------------------------------------------------------------------------------
    wrEnB       <= '1' when cntEn='1' and selManiOffset/=(selManiOffset'range =>'0') else '0';
        --Write Enabled when Manipulation is active(CntEn) and a Manipulation exists(Offset not 00..0)

    addressB    <= std_logic_vector(unsigned(reg.dataStartAddr)+unsigned(selManiOffset)) when wrEnB='1' else iRdAddress;
        --selection between write-manipulation- and read-address


    --Error flag is set, when an overflow occurs
    oError_frameBuffOv  <= '1' when unsigned(iRdAddress)=unsigned(iWrAddress)+1 else '0';

end two_seg_arch;
