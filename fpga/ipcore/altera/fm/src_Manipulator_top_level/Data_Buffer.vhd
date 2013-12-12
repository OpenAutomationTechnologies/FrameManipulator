
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

entity Data_Buffer is
    generic(gDataWidth:         natural:=8;
            gDataAddrWidth:     natural:=11;
            gNoOfHeadMani:      natural:=8;
            gTaskWordWidth:     natural:=64;
            gManiSettingWidth:  natural:=112
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

    --function of the logarithm to the base of 2
    function log2c(n:natural) return natural is
        variable m, p: natural;
    begin
        m:=0;
        p:=1;
        while p<n loop
            m:=m+1;
            p:=p*2;
        end loop;
        return m;
    end log2c;


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
    constant cCntWidth:natural:=log2c(gNoOfHeadMani+1);

    constant cSizeManiHeaderData:   natural:=8;
    constant cSizeManiHeaderOffset: natural:=6;


    --Mani Enable Edge Detection--------
    signal ManiEdge:    std_logic;
    signal ManiNext:    std_logic:='0';

    --Register of Manipulation Data-----
    signal DataStartAddr:   std_logic_vector(gDataAddrWidth-1 downto 0)                     :=(others=>'0');
    signal ManiOffset:      std_logic_vector(gManiSettingWidth-gTaskWordWidth-1 downto 0)   :=(others=>'0');
    signal ManiWords:       std_logic_vector(gTaskWordWidth-1 downto 0)                     :=(others=>'0');

    --Selected Data of the Register-----
    signal SelManiOffset:   std_logic_vector(cSizeManiHeaderOffset-1 downto 0);
    signal SelManiWords:    std_logic_vector(cSizeManiHeaderData-1 downto 0);

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
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset='1' then
                ManiNext<='0';
            else
                ManiNext<=iTaskManiEn;

                if ManiEdge='1' then --stores the task setting at the receiving edge
                    DataStartAddr   <=iDataStartAddr;
                    ManiOffset      <=iManiSetting(gManiSettingWidth-1 downto gTaskWordWidth);
                    ManiWords       <=iManiSetting(gTaskWordWidth-1 downto 0);

                end if;

            end if;
        end if;
    end process;

    ManiEdge<='1' when ManiNext='0' and iTaskManiEn='1' else '0';



    --Counter for Data Selection-------------------------------------------------------------------
    CntEn<= '1' when iRdEn='0' and unsigned(SelData)<gNoOfHeadMani else '0';
    --is counting, when the buffer isn't read at the moment

    SelCntr:Basic_Cnter
        generic map(gCntWidth=>cCntWidth)
        port map(clk=>clk,reset=>reset,
                iClear=>ManiEdge,iEn=>CntEn,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
                oQ=>SelData,oOv=>open);


    --DeMultiplexer to select the Data-------------------------------------------------------------
    OffsetMux:Mux2D
        generic map(gWordsWidth=>cSizeManiHeaderOffset,
                    gWordsNo=>gNoOfHeadMani,
                    gWidthSel=>cCntWidth)
        port map (iData=>ManiOffset,iSel=>std_logic_vector(SelData),oWord=>SelManiOffset);

    WordMux:Mux2D
        generic map(gWordsWidth=>cSizeManiHeaderData,
                    gWordsNo=>gNoOfHeadMani,
                    gWidthSel=>cCntWidth)
        port map (iData=>ManiWords,iSel=>std_logic_vector(SelData),oWord=>SelManiWords);


    --Usage of Port B------------------------------------------------------------------------------
    WrEnB<='1' when CntEn='1' and SelManiOffset/=(SelManiOffset'range =>'0') else '0';
        --Write Enabled when Manipulation is active(CntEn) and a Manipulation exists(Offset not 00..0)

    AddressB<=std_logic_vector(unsigned(DataStartAddr)+unsigned(SelManiOffset)) when WrEnB='1' else iRdAddress;
        --selection between write-manipulation- and read-address


    --Error flag is set, when an overflow occurs
    oError_Frame_Buff_OV<='1' when unsigned(iRdAddress)=unsigned(iWrAddress)+1 else '0';

end two_seg_arch;