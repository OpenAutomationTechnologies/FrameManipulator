
-- ******************************************************************************************
-- *                                Control_Register                                        *
-- ******************************************************************************************
-- *                                                                                        *
-- * Shared interface between the Framemanipulator and its POWERLINK Slave                  *
-- *                                                                                        *
-- * Address 0: operations from the MN for the FM                                           *
-- *            starts a new test, stops the current one, clear task memory and clear erros *
-- *                                                                                        *
-- * Address 1: collected status informaions and error messages for the MN                  *
-- *                                                                                        *
-- * s_clk: clock domain of the avalon slaves                                               *
-- * s_...  avalon slave for the control registers (operations and error)                   *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Control_Register                        by Sebastian Muelhausen     *
-- * 20.11.13 V1.1      Added Safety Registers                  by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Use work library
library work;
--! use global library
use work.global.all;

entity Control_Register is
    generic(gWordWidth:         natural :=cByteLength;
            gAddresswidth:      natural :=1);
    port(
        clk, reset:             in std_logic;
        s_clk:                  in std_logic;   --Clock of the slave
        --Controls
        oStartTest:             out std_logic;  --Opertaion: Start new series of test
        oStopTest:              out std_logic;  --Opertaion: Stop current sereis of test
        oClearMem:              out std_logic;  --Opertaion: clear all tasks
        oResetPaketBuff:        out std_logic;  --Opertaion:aborts the current test
        iTestActive:            in std_logic;   --Status: Test is active
        --Error messages
        iError_Addr_Buff_OV:    in std_logic;   --Error: Address-buffer overflow
        iError_Frame_Buff_OV:   in std_logic;   --Error: Data-buffer overflow
        iError_Packet_Buff_OV:  in std_logic;   --Error: Overflow packet-buffer
        iError_Task_Conf:       in std_logic;   --Error: Wrong task configuration
        --avalon bus (s_clk-domain)
        s_iAddr:                in std_logic_vector(gAddresswidth-1 downto 0);
        s_iWrEn:                in std_logic;
        s_iRdEn:                in std_logic;
        s_iByteEn:              in std_logic_vector((gWordWidth/cByteLength)-1 DOWNTO 0);
        s_iWriteData:           in std_logic_vector(gWordWidth-1 downto 0);
        s_oReadData:            out std_logic_vector(gWordWidth-1 downto 0)
     );
end Control_Register;

architecture two_seg_arch of Control_Register is

    --DPRam Port A= PL-Slave, B=Hardware Manipulator
    component DPRAM_Plus IS
        generic(gAddresswidthA:     natural :=7;
            gAddresswidthB:     natural :=6;
            gWordWidthA:        natural :=32;
            gWordWidthB:        natural :=64);
        port
        (
            address_a   : IN STD_LOGIC_VECTOR (gAddresswidthA-1 DOWNTO 0);
            address_b   : IN STD_LOGIC_VECTOR (gAddresswidthB-1 DOWNTO 0);
            byteena_a   : IN STD_LOGIC_VECTOR ((gWordWidthA/cByteLength)-1 DOWNTO 0) :=  (OTHERS => '1');
            byteena_b   : IN STD_LOGIC_VECTOR ((gWordWidthB/cByteLength)-1 DOWNTO 0) :=  (OTHERS => '1');
            clock_a     : IN STD_LOGIC  := '1';
            clock_b     : IN STD_LOGIC ;
            data_a      : IN STD_LOGIC_VECTOR (gWordWidthA-1 DOWNTO 0);
            data_b      : IN STD_LOGIC_VECTOR (gWordWidthB-1 DOWNTO 0);
            rden_a      : IN STD_LOGIC  := '1';
            rden_b      : IN STD_LOGIC  := '1';
            wren_a      : IN STD_LOGIC  := '0';
            wren_b      : IN STD_LOGIC  := '0';
            q_a         : OUT STD_LOGIC_VECTOR (gWordWidthA-1 DOWNTO 0);
            q_b         : OUT STD_LOGIC_VECTOR (gWordWidthB-1 DOWNTO 0)
        );
    end component;

    --positions of operation and status bits
    constant cOpStart:       natural:= 0;
    constant cOpStop:        natural:= 1;
    constant cOpClearMem:    natural:= 2;
    constant cOpClearErrors: natural:= 3;
    constant cOpClearPaket:  natural:= 4;

    constant cStActive:      natural:= 0;

    constant cErDataOv:      natural:= 4;
    constant cErFrameOv:     natural:= 5;
    constant cErPacketOv:    natural:= 6;
    constant cErTaskConf:    natural:= 7;


    --data variables
    signal DataB_out:   std_logic_vector(gWordWidth-1 downto 0);
    signal byteena_b:   std_logic_vector(gWordWidth/cByteLength-1 downto 0);
    signal wren_b:      std_logic;
    signal rden_b:      std_logic;
    signal Addr_B:      std_logic_vector(gAddresswidth-1 downto 0);

    --operation register
    signal OperationByte_reg:   std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');
    signal OperationByte_next:  std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');

    --status and error register
    signal StatusByte_reg:  std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');
    signal StatusByte_next: std_logic_vector(gWordWidth-1 downto 0):=(others=>'0');


    signal Write_Status:    std_logic;  --writes status, when changes occurres
    signal ClearErrors:     std_logic;  --Opertaion: Clear all errors

begin

    --Register Storage---------------------------------------------------
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset='1' then
                StatusByte_reg<=    (others=>'0');
                OperationByte_reg<=(others=>'0');

            else
                StatusByte_reg<=StatusByte_next;
                OperationByte_reg<=OperationByte_next;

            end if;
        end if;
    end process;

    --store test staus (first nibble) D-FF:
    StatusByte_next(cStActive)<=iTestActive;

    --store errors (second nibble) RS-FF:
        --set of bits with error-signal, reset of bits with clear-operation
    StatusByte_next(cErDataOv)   <=(StatusByte_reg(cErDataOv)     or iError_Addr_Buff_OV)
                                                                and not ClearErrors;

    StatusByte_next(cErFrameOv)  <=(StatusByte_reg(cErFrameOv)    or iError_Frame_Buff_OV)
                                                                and not ClearErrors;

    StatusByte_next(cErPacketOv)  <=(StatusByte_reg(cErPacketOv)    or iError_Packet_Buff_OV)
                                                                and not ClearErrors;

    StatusByte_next(cErTaskConf)  <=(StatusByte_reg(cErTaskConf)    or iError_Task_Conf)
                                                                and not ClearErrors;


    --writes new status, when changes occure
    Write_Status<='0' when StatusByte_next=StatusByte_reg else '1';

    wren_b<='1' when Write_Status='1' else '0'; --enable write at changes
    rden_b<='1' when Write_Status='0' else '0'; --disable read at changes

    Addr_B(0)<='1' when Write_Status='1' else '0';  --Addr 1 = Write Errors, else Read Addr 0 = Operations

    --Memory----------------------------------------------------------
    ControlMem:DPRAM_Plus
    generic map(gAddresswidthA=>gAddresswidth,gAddresswidthB=>gAddresswidth,gWordWidthA=>gWordWidth,gWordWidthB=>gWordWidth)
    port map(
    clock_a=>s_clk,clock_b=>clk,
            --Port A: PL-Slave
            address_a=>s_iAddr,     data_a=>s_iWriteData,           wren_a=>s_iWrEn,
            rden_a=>s_iRdEn,        byteena_a=>s_iByteEn,           q_a=>s_oReadData,
            --Port B: FM
            address_b=>Addr_B,      data_b=>StatusByte_next,        wren_b=>wren_b,
            rden_b=>rden_b,         byteena_b=>(others=>'1'),       q_b=>DataB_out);


    --Operation Output------------------------------------------------
    --update register, when data is read
    OperationByte_next<=DataB_out(OperationByte_next'range) when rden_b='1' else OperationByte_reg;

    oStartTest  <='1' when OperationByte_reg(cOpStart)='1'   and OperationByte_reg(cOpStop)='0'
                                                            and OperationByte_reg(cOpClearMem)='0'
                        else '0';

    oStopTest   <='1' when OperationByte_reg(cOpStop)='1'    or OperationByte_reg(cOpClearMem)='1'
                                                            or StatusByte_reg(7 downto 4)/="0000"
                        else '0';

    oClearMem   <='1' when OperationByte_reg(cOpClearMem)='1' else '0';

    ClearErrors <='1' when OperationByte_reg(cOpClearErrors)='1' else '0';

    oResetPaketBuff <='1' when OperationByte_reg(cOpClearPaket)='1' else '0';

end two_seg_arch;
