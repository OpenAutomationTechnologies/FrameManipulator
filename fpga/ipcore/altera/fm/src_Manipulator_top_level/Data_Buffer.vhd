
-- ******************************************************************************************
-- *                                Data_Buffer                                             *
-- ******************************************************************************************
-- *                                                                                        *
-- * Dual port memory. Write access for the incoming frame-data on port A. Read access for  *
-- * the created frame, as well as header manipulation, on port B.                          *
-- *                                                                                        *
-- * The header manipulation setting is stored at the edge of the task enable signal. The   *
-- * manipulation of up to 8 different bytes are done on port B, while there is no read     *
-- * access.                                                                                *
-- *                                                                                        *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Data_Buffer                             by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Use work library
library work;
--! use global library
use work.global.all;
--! use fm library
use work.framemanipulatorPkg.all;

entity Data_Buffer is
    generic(gDataWidth:         natural:=cByteLength;
            gDataAddrWidth:     natural:=11;
            gNoOfHeadMani:      natural:=8;
            gTaskWordWidth:     natural:=8*cByteLength;
            gManiSettingWidth:  natural:=14*cByteLength
            );
    port
    (
        clk, reset:             in std_logic;
        iData:                  in std_logic_vector(gDataWidth-1 downto 0);         --write data    Port A
        iRdAddress:             in std_logic_vector(gDataAddrWidth-1 downto 0);     --read address  Port B
        iRdEn:                  in std_logic;                                       --read enable   Port B
        iWrAddress:             in std_logic_vector(gDataAddrWidth-1 downto 0);     --write address Port A
        iWrEn:                  in std_logic  := '0';                               --write enable  Port A
        oData:                  out std_logic_vector(gDataWidth-1 downto 0);        --read data     Port B
        oError_Frame_Buff_OV:   out std_logic;                                      --Error flag, when overflow occurs

        iManiSetting:           in std_logic_vector(gManiSettingWidth-1 downto 0);  --header manipulation setting
        iTaskManiEn:            in std_logic;                                       --header manipulation enable
        iDataStartAddr:         in std_logic_vector(gDataAddrWidth-1 downto 0)      --start byte of manipulated header
    );
end Data_Buffer;


architecture two_seg_arch of Data_Buffer is


    --frame-data memory ----------------------------------------------------------------------
    --dual-port-ram without byteenable, with the same clock domain
    component DPRAM_Simple
        generic(gWordWidth:natural:=8;
                gAddrWidth:natural:=11);
        PORT
        (
            address_a   : IN STD_LOGIC_VECTOR (gAddrWidth-1 DOWNTO 0);
            address_b   : IN STD_LOGIC_VECTOR (gAddrWidth-1 DOWNTO 0);
            clock       : IN STD_LOGIC  := '1';
            data_a      : IN STD_LOGIC_VECTOR (gWordWidth-1 DOWNTO 0);
            data_b      : IN STD_LOGIC_VECTOR (gWordWidth-1 DOWNTO 0);
            rden_a      : IN STD_LOGIC  := '1';
            rden_b      : IN STD_LOGIC  := '1';
            wren_a      : IN STD_LOGIC  := '0';
            wren_b      : IN STD_LOGIC  := '0';
            q_a         : OUT STD_LOGIC_VECTOR (gWordWidth-1 DOWNTO 0);
            q_b         : OUT STD_LOGIC_VECTOR (gWordWidth-1 DOWNTO 0)
        );
    end component;


    --select counter -------------------------------------------------------------------------
    --counter for the selecting multiplexer
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
            clk, reset:     in std_logic;
            iClear:         in std_logic;
            iEn   :         in std_logic;
            iStartValue:    in std_logic_vector(gCntWidth-1 downto 0);
            iEndValue:      in std_logic_vector(gCntWidth-1 downto 0);
            oQ:             out std_logic_vector(gCntWidth-1 downto 0);
            oOv:            out std_logic
        );
    end component;


    --select mux -----------------------------------------------------------------------------
    --multiplexer to select the different header manipulations
    component Mux2D
        generic(gWordsWidth: natural:=8;
                gWordsNo:   natural:=8;
                gWidthSel:  natural:=3);
        port(
            iData:  in std_logic_vector(gWordsWidth*gWordsNo-1 downto 0);
            iSel:   in std_logic_vector(gWidthSel-1 downto 0);
            oWord:  out std_logic_vector(gWordsWidth-1 downto 0)
            );
    end component;

    --size selection of the selection counter
    constant cCntWidth:natural:=LogDualis(gNoOfHeadMani+1);


    --! Typedef for registers
    type tReg is record
        TaskManiEn      : std_logic;                                                        --! Register for detection for iTaskManiEn
        DataStartAddr   : std_logic_vector(gDataAddrWidth-1 downto 0);                      --! Start Byte of manipulated frame header
        ManiOffset      : std_logic_vector(gManiSettingWidth-gTaskWordWidth-1 downto 0);    --! Offsets of header manipulation
        ManiWords       : std_logic_vector(gTaskWordWidth-1 downto 0);                      --! New header data
    end record;


    --! Init for registers
    constant cRegInit   : tReg :=(
                                TaskManiEn      => '0',
                                DataStartAddr   => (others=>'0'),
                                ManiOffset      => (others=>'0'),
                                ManiWords       => (others=>'0')
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers


    signal TaskManiEn_posEdge   : std_logic;    --! positive edge of iTaskManiEn

    --Selected Data of the Register-----
    signal SelManiOffset:   std_logic_vector(cParam.SizeManiHeaderOffset-1 downto 0);
    signal SelManiWords:    std_logic_vector(cParam.SizeManiHeaderData-1 downto 0);

    --Selection of several Bytes---------
    signal CntEn:   std_logic;
    signal SelData: std_logic_vector(cCntWidth-1 downto 0);

    --Usage of Port B--------------------
    signal WrEnB:       std_logic;
    signal AddressB:    std_logic_vector(gDataAddrWidth-1 downto 0);

begin

    --Buffer for Frames --------------------------------------------------------------------------
    --Port A: incoming frame-data
    --Port B: outgoing frame-data and frame header manipulation
    FBuffer:DPRAM_Simple
    generic map(gWordWidth=>gDataWidth,
                gAddrWidth=>gDataAddrWidth)
    port map (  clock=>clk,
                address_a=>iWrAddress,  data_a=>iData,          wren_a=>iWrEn,  rden_a=>'0',
                q_a=>open,
                address_b=>AddressB,    data_b=>SelManiWords    ,wren_b=>WrEnB, rden_b=>iRdEn,
                q_b=>oData);


    --Edge Detection of Manipulation Enable-------------------------------------------------------

    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            reg <= cRegInit;

        elsif rising_edge(clk) then
            reg <= reg_next;

        end if;
    end process;


    --! @brief Next register value
    --! - Storing of iTaskManiEn for edge detection
    --! - Storing of manipulation setting at edge
    nextComb :
    process(reg, iTaskManiEn, TaskManiEn_posEdge, iDataStartAddr, iManiSetting)
    begin
        reg_next    <= reg;

        reg_next.TaskManiEn <= iTaskManiEn;

        if TaskManiEn_posEdge='1' then
            reg_next.DataStartAddr  <= iDataStartAddr;
            reg_next.ManiOffset     <= iManiSetting(gManiSettingWidth-1 downto gTaskWordWidth);
            reg_next.ManiWords      <= iManiSetting(gTaskWordWidth-1 downto 0); --TODO alias

        end if;

    end process;




    TaskManiEn_posEdge  <= '1' when reg.TaskManiEn = '0' and iTaskManiEn = '1' else '0';



    --Counter for Data Selection-------------------------------------------------------------------
    CntEn<= '1' when iRdEn='0' and unsigned(SelData)<gNoOfHeadMani else '0';
    --is counting, when the buffer isn't read at the moment

    SelCntr:Basic_Cnter
        generic map(gCntWidth=>cCntWidth)
        port map(clk=>clk,reset=>reset,
                iClear  => TaskManiEn_posEdge,
                iEn=>CntEn,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
                oQ=>SelData,oOv=>open);


    --DeMultiplexer to select the Data-------------------------------------------------------------
    OffsetMux:Mux2D
        generic map(gWordsWidth => cParam.SizeManiHeaderOffset,
                    gWordsNo=>gNoOfHeadMani,
                    gWidthSel=>cCntWidth)
        port map(
                iData   => reg.ManiOffset,
                iSel=>std_logic_vector(SelData),oWord=>SelManiOffset);

    WordMux:Mux2D
        generic map(gWordsWidth => cParam.SizeManiHeaderData,
                    gWordsNo=>gNoOfHeadMani,
                    gWidthSel=>cCntWidth)
        port map(
                iData   => reg.ManiWords,
                iSel=>std_logic_vector(SelData),oWord=>SelManiWords);


    --Usage of Port B------------------------------------------------------------------------------
    WrEnB<='1' when CntEn='1' and SelManiOffset/=(SelManiOffset'range =>'0') else '0';
        --Write Enabled when Manipulation is active(CntEn) and a Manipulation exists(Offset not 00..0)

    AddressB    <= std_logic_vector(unsigned(reg.DataStartAddr)+unsigned(SelManiOffset)) when WrEnB='1' else iRdAddress;
        --selection between write-manipulation- and read-address


    --Error flag is set, when an overflow occurs
    oError_Frame_Buff_OV<='1' when unsigned(iRdAddress)=unsigned(iWrAddress)+1 else '0';

end two_seg_arch;
