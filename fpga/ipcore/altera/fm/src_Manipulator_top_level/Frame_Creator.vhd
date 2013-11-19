
-- ******************************************************************************************
-- *                                Frame_Creator                                           *
-- ******************************************************************************************
-- *                                                                                        *
-- * Creates a new frame, when iStartNewFrame is set. It generates a new Preamble and a     *
-- * valid or manipulated CRC. The frame-data are collected from iDataStartAddr to          *
-- * iDataEndAddr.                                                                          *
-- *                                                                                        *
-- * Once a frame was sent out, it activates oNextFrame to receive the next one. Thereby,   *
-- * the IPG (Inter Packet Gap) is considered by a small delay.                             *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Frame_Creator                           by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Frame_Creator is
    generic(gDataBuffAddrWidth: natural:=11);
    port(
        clk, reset:     in std_logic;

        iStartNewFrame: in std_logic;   --data for a new frame is available
        oNextFrame:     out std_logic;  --frame-creator is ready for new data
        iDistCrcEn:     in std_logic;   --task: distortion of frame-CRC

        --Read data buffer
        iDataStartAddr: in std_logic_vector(gDataBuffAddrWidth-1 downto 0); --Position of the first frame-byte
        iDataEndAddr:   in std_logic_vector(gDataBuffAddrWidth-1 downto 0); --Position of the last
        iData:          in std_logic_vector(7 downto 0);                    --frame-data
        oRdBuffAddr:    out std_logic_vector(gDataBuffAddrWidth-1 downto 0);--read address of data-memory
        oRdBuffEn:      out std_logic;                                      --read-enable

        oTXData :       out std_logic_vector(1 downto 0);   --frame-output-data
        oTXDV:          out std_logic                       --frame-output-data-valid
    );
end Frame_Creator;

architecture two_seg_arch of Frame_Creator is

    --create new frame FSM -------------------------------------------------------------------
    --FSM to select between Preamble, frame-data and CRC
    component Frame_Create_FSM
        port(
            clk, reset:         in std_logic;

            iFrameStart:        in std_logic;   --start of a new frame
            iReadBuffDone:      in std_logic;   --buffer reading has reched the last position

            oPreamble_Active:   out std_logic;  --activate preamble_generator
            oPreReadBuff:       out std_logic;  --activate pre-reading
            oReadBuff_Active:   out std_logic;  --activate reading from data-buffer
            oCRC_Active:        out std_logic;  --activate CRC calculation

            oSelectTX:          out std_logic_vector(1 downto 0);   --selection beween the preamble, payload and crc
            oNextFrame:         out std_logic;                      --FSM is ready for new data
            oTXDV:              out std_logic                       --TX Data Valid
        );
    end component;


    --preamble generator ---------------------------------------------------------------------
    component Preamble_Generator
        port(
            clk, reset:         in std_logic;
            iPreamble_Active:   in std_logic;
            oTXD:               out  std_logic_vector(1 downto 0)
        );
    end component;


    --read frame-data logic ------------------------------------------------------------------
    component read_logic
        generic(
        gPrescaler:natural:=4;
        gAddrWidth: natural:=11);
    port(
        clk, reset: in std_logic;
        iEn:        in std_logic;
        iSync:      in std_logic;
        iStartAddr: in std_logic_vector(gAddrWidth-1 downto 0);
        oRdEn:      out std_logic;
        oAddr:      out  std_logic_vector(gAddrWidth-1 downto 0)
        );
    end component;


    --byte to 2bit converter -----------------------------------------------------------------
    --converts the frame-data in byte to the width of two bits
    component Byte_to_TXData
        port(
            clk, reset: in std_logic;
            iData: in std_logic_vector(7 downto 0);
            oTXD:  out std_logic_vector(1 downto 0)
        );
    end component;


    --CRC_calculator -------------------------------------------------------------------------
    --generates a valid (or manipulated) CRC
    component CRC_calculator
        port(
            clk, reset:         in std_logic;
            iReadBuff_Active:   in std_logic;
            iCRC_Active:        in std_logic;
            iCRCMani:           in std_logic;
            iTXD:               in std_logic_vector(1 downto 0);
            oTXD:               out std_logic_vector(1 downto 0)
        );
    end component;


    --Stream selector ------------------------------------------------------------------------
    --multiplexer to select the active TX-stream
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



    signal Preamble_Active: std_logic;
    signal ReadBuff_Active: std_logic;
    signal PreReadBuff:     std_logic;
    signal CRC_Active:      std_logic;

    signal readaddr:        std_logic_vector(gDataBuffAddrWidth-1 downto 0);
    signal nStartReader:    std_logic;
    signal readdone:        std_logic;

    signal TXD_Selection:   std_logic_vector(1 downto 0);

    signal TXDPre:          std_logic_vector(1 downto 0);
    signal TXDBuff:         std_logic_vector(1 downto 0);
    signal TXDCRC:          std_logic_vector(1 downto 0);

    signal temp_TXD_Mux:    std_logic_vector(7 downto 0);



begin




    --frame-data is read, when the last data byte has been reached
    readdone<='1' when readaddr=std_logic_vector(unsigned(iDataEndAddr)-3) else '0';
        --minus 4 Bytes to cut the old CRC plus 1 for readaddr>EndAddr


    --create new frame FSM -------------------------------------------------------------------
    --starts with the iFrameStart signal
    --selection of the different signals with oSelectTX
    --PreReadBuff to eliminate problems with delays of the DPRam and read logic
    ------------------------------------------------------------------------------------------
    FSM: Frame_Create_FSM
    port map(
        clk=>clk, reset=>reset,
        iFrameStart=>iStartNewFrame,        iReadBuffDone=>readdone,
        oPreamble_Active=>Preamble_Active,  oPreReadBuff=>PreReadBuff,
        oReadBuff_Active=>ReadBuff_Active,  oCRC_Active=>CRC_Active,
        oSelectTX=>TXD_Selection,           oNextFrame=>oNextFrame,     oTXDV=>oTXDV);


    --preamble generator ---------------------------------------------------------------------
    ------------------------------------------------------------------------------------------
    Preamble : Preamble_Generator
    port map (
            clk=>clk, reset=>reset,
            iPreamble_Active => Preamble_Active,
            oTXD => TXDPre);


    --enables the read-logic via negative logic
    nStartReader<= not (ReadBuff_Active or PreReadBuff);


    --read frame-data logic ------------------------------------------------------------------
    --starts reading from the address of the first byte of the memory   => iDataStartAddr
    ------------------------------------------------------------------------------------------
    RL:read_logic
    generic map(gPrescaler=>4,gAddrWidth=>gDataBuffAddrWidth)
    port map (
            clk=>clk, reset=>reset,
            iEn=>'1',iSync=>nStartReader,iStartAddr=>iDataStartAddr,
            oRdEn=>oRdBuffEn,oAddr=> readaddr);


    --byte to 2bit converter -----------------------------------------------------------------
    --converts the frame data to a width of two bits
    ------------------------------------------------------------------------------------------
    Byte_to_Tx:Byte_to_TXData
    port map (
            clk=>clk, reset=>reset,
            iData=> iData,
            oTXD=> TXDBuff);


    --CRC_calculator -------------------------------------------------------------------------
    --iReadBuff_Active  => CRC is calculated
    --iCRC_Active       => CRC is shifted out
    --iCRCMani          => CRC is distorted
    ------------------------------------------------------------------------------------------
    CRC_calc : CRC_calculator
        port map (
            clk=>clk, reset=>reset,
            iReadBuff_Active=>ReadBuff_Active, iCRC_Active=>CRC_Active , iTXD=> TXDBuff,
            iCRCMani=>iDistCrcEn,
            oTXD=> TXDCRC);


    --collection of the different streams for the multiplexer
    temp_TXD_Mux<=TXDBuff&TXDCRC&TXDPre&"00";


    --Stream selector ------------------------------------------------------------------------
    --selects the active stream by TXD_Selection of the FSM
    ------------------------------------------------------------------------------------------
    TXDMux:Mux2D
    generic map(gWordsWidth=>2,gWordsNo=>4,gWidthSel=>2)
    port map(
            iData=>temp_TXD_Mux,iSel=>TXD_Selection,
            oWord=>oTXData);




    oRdBuffAddr<=readaddr;


end two_seg_arch;