
-- ******************************************************************************************
-- *                                Frame-Receiver                                          *
-- ******************************************************************************************
-- *                                                                                        *
-- * Receives the incoming frame and stores it on the data-buffer.                          *
-- *                                                                                        *
-- * Only frames with a valid preamble and an Ethertype of "gEtherTypeFilter_1" or          *
-- * "gEtherTypeFilter_2" activates the start signal "oStartFrame" for the next process     *
-- * unit.                                                                                  *
-- *                                                                                        *
-- * It starts to write the data to the memory, starting with the address iDataStartAddr.   *
-- * This position is sent by the process unit and overwrites invalid or dropped frames to  *
-- * save some memory.                                                                      *
-- *                                                                                        *
-- * It also processes the truncate task for the selected frames and changes the address    *
-- * of the last byte of the data-buffer.                                                   *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Frame-Receiver                          by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--! use global library
use work.global.all;


entity Frame_Receiver is
    generic(
            gBuffAddrWidth      : natural :=11;
            gEtherTypeFilter    : std_logic_vector :=X"88AB_0800_0806"  --filter
            );
    port(
        clk, reset:         in std_logic;
        iRXDV:              in std_logic;                                   --frame data valid
        iRXD:               in std_logic_vector(1 downto 0);                --frame data (2bit)
        --write data
        oData:              out std_logic_vector(cByteLength-1 downto 0);   --frame data (1byte)
        oWrBuffAddr:        out std_logic_vector(gBuffAddrWidth-1 downto 0);--write address
        oWrBuffEn :         out std_logic;                                  --write data-memory enable
        iDataStartAddr:     in std_logic_vector(gBuffAddrWidth-1 downto 0); --first byte of frame data
        oDataEndAddr:       out std_logic_vector(gBuffAddrWidth-1 downto 0);--last byte of frame data
        --truncate frame
        iTaskCutEn:         in std_logic;                                   --cut task enabled
        iTaskCutData:       in std_logic_vector(gBuffAddrWidth-1 downto 0); --cut task setting
        --start process-unit
        oStartFrameProcess: out std_logic;                                  --valid frame received
        oFrameEnded:        out std_logic;                                  --frame ended
        oFrameSync:         out std_logic                                   --synchronization signal
    );
end Frame_Receiver;

architecture two_seg_arch of Frame_Receiver is

    --data width converter ------------------------------------------------------------------
    --converts the data from a width of two to one byte
    component RXData_to_Byte
        port(
            clk, reset: in std_logic;
            iRXDV: in std_logic;
            iRXD:  in std_logic_vector(1 downto 0);
            oData: out std_logic_vector(cByteLength-1 downto 0);
            oEn:   out std_logic;
            oSync: out std_logic
        );
    end component;


    --preamble checker ----------------------------------------------------------------------
    component Preamble_check
        port(
            clk, reset: in std_logic;
            iRXD:  in std_logic_vector(1 downto 0);
            iRXDV:  in std_logic;
            iSync:  in std_logic;
            oPreOk: out std_logic
        );
    end component;


    --Ethertype collector -------------------------------------------------------------------
    --collects data from byte number gFrom to gTo
    component Frame_collector
        generic(
            gFrom:natural:=13;
            gTo : natural:=22
        );
        port(
            clk, reset:         in std_logic;
            iData:              in std_logic_vector(cByteLength-1 downto 0);
            iSync:              in std_logic;
            oFrameData :        out std_logic_vector((gTo-gFrom+1)*cByteLength-1 downto 0);
            oCollectorFinished: out std_logic
        );
    end component;


    --Memory write logic --------------------------------------------------------------------
    --stores the frame-data to the buffer
    component write_logic
        generic(
            gPrescaler:natural:=4;
            gAddrWidth: natural:=11);
        port(
            clk, reset: in std_logic;
            iSync:      in std_logic;
            iEn:        in std_logic;
            iStartAddr: in std_logic_vector(gAddrWidth-1 downto 0);
            oAddr:      out std_logic_vector(gAddrWidth-1 downto 0);
            oWrEn:      out std_logic
        );
    end component;


    --frame end detection -------------------------------------------------------------------
    --detects the end of the frame and process the cut-frame-task
    component end_of_frame_detection
        generic(gBuffAddrWidth:natural:=11);
        port(
            clk, reset: in std_logic;
            iRXDV:      in std_logic;
            iAddr:      in std_logic_vector(gBuffAddrWidth-1 downto 0);
            iStartAddr: in std_logic_vector(gBuffAddrWidth-1 downto 0);
            iCutEn:     in std_logic;
            iCutData:   in std_logic_vector(gBuffAddrWidth-1 downto 0);
            oEndAddr:   out std_logic_vector(gBuffAddrWidth-1 downto 0);
            oFrameEnd:  out std_logic
         );
    end component;

    --! Ethertype filter as downto-std_logic_vector
    constant cEtherTypeFilter   : std_logic_vector(gEtherTypeFilter'length-1 downto 0) := gEtherTypeFilter;
    constant cEtherTypeSize     : natural := 2*cByteLength; --! Size of EtherType = 2 Bytes

    --! Number of Ethertype filter
    constant cNumbFilter        : natural := gEtherTypeFilter'length/cEtherTypeSize;

    signal data:                std_logic_vector(cByteLength-1 downto 0);
    signal sync:                std_logic;

    signal EnWL:                std_logic;
    signal wraddr:              std_logic_vector(gBuffAddrWidth-1 downto 0);

    signal EtherType:           std_logic_vector(cEtherTypeSize-1 downto 0);
    signal preambleOk:          std_logic:='0';
    signal CollectorFinished:   std_logic;

    signal FrameEnd:            std_logic;

    signal MatchFilter  : std_logic_vector(cNumbFilter-1 downto 0); --! Filter(x) does match

    signal StartFrameProcess_reg    : std_logic;    --! Register of oStartFrameProcess to reduce path delay
    signal StartFrameProcess_next   : std_logic;    --! Next value of register


begin

    --data width converter ------------------------------------------------------------------
    --converted data output             => oData
    --generates synchronization signal  => oSync
    -----------------------------------------------------------------------------------------
    Rx : RXData_to_Byte
    port map (
            clk=>clk, reset=>reset,
            iRXDV => iRXDV, iRXD => iRXD,
            oData => data, oEn => open, oSync => sync);


    --preamble checker ----------------------------------------------------------------------
    -- valid preamble detected  =>  oPreOk
    -----------------------------------------------------------------------------------------
    PreCheck:Preamble_check
    port map(
            clk=>clk, reset=>reset,
            iRXD=>iRXD, iRXDV=>iRXDV,iSync=>sync,
            oPreOk=>preambleOk);


    --Ethertype collector -------------------------------------------------------------------
    --collected data            =>  oFrameData
    --collector has finisched   =>  oCollectorFinished
    -----------------------------------------------------------------------------------------
    EtherType_Collector : Frame_collector
    generic map(gFrom=>13,gTo=>14)     --Ethertype=Byte 13 and 14
    port map(
            clk=>clk,reset=>reset,
            iData=>data,iSync=>sync,
            oFrameData=>EtherType,oCollectorFinished=>CollectorFinished);


    --! Check of the Ethertype with the predefined values
    EthertypeMatch :
    for i in MatchFilter'range generate

        MatchFilter(i)  <=  '1' when EtherType = cEtherTypeFilter(15+cEtherTypeSize*i downto 0+cEtherTypeSize*i) else '0';

    end generate EthertypeMatch;



    --write logic is enabled and stores data utill the frame has ended
    EnWL<= not FrameEnd;

    --Memory write logic --------------------------------------------------------------------
    -----------------------------------------------------------------------------------------
    WL : write_logic
    generic map(gPrescaler=>4,  --writes data every fourth tick
                gAddrWidth=>gBuffAddrWidth)
    port map (
            clk=>clk, reset=>reset,
            iSync => sync,iEn=>EnWL,iStartAddr=>iDataStartAddr,
            oAddr => wraddr, oWrEn => oWrBuffEn);


    --frame end detection -------------------------------------------------------------------
    --detects the end of the frame                      =>  oFrameEnd
    --as well as the memory-address of the last byte    =>  oEndAddr
    --also truncates the frame in the cut-frame-task    =>  iCutEn, iCutData
    -----------------------------------------------------------------------------------------
    end_of_frame : end_of_frame_detection
    generic map(gBuffAddrWidth=>gBuffAddrWidth)
    port map (
            clk=>clk, reset=>reset,
            iRXDV => iRXDV, iAddr => wraddr,iStartAddr=>iDataStartAddr,iCutEn=>iTaskCutEn,
            iCutData=>iTaskCutData,
            oEndAddr=> oDataEndAddr,oFrameEnd=>FrameEnd);


    --  frame process can start, when the collection has finished with Preamble and one of the valid Ethertypes
    StartFrameProcess_next  <= '1' when CollectorFinished='1' and preambleOk='1' and reduceOr(MatchFilter)='1' else '0';


    --! @brief Registers
    --! - Storing with asynchronous reset
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            StartFrameProcess_reg   <= '0';

        elsif rising_edge(clk) then
            StartFrameProcess_reg   <= StartFrameProcess_next;

        end if;
    end process;

    oStartFrameProcess  <= StartFrameProcess_reg;


    --signal output
    oFrameEnded<=FrameEnd;
    oData <= data;
    oWrBuffAddr<=wraddr;
    oFrameSync<=sync;

end two_seg_arch;


