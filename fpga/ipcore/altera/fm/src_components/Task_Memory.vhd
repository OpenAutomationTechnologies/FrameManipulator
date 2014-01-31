
-- ******************************************************************************************
-- *                                    Task_Memory                                         *
-- ******************************************************************************************
-- *                                                                                        *
-- * Shared memory interface between the Framemanipulator and its POWERLINK Slave for the   *
-- * configuration of the tasks.                                                            *
-- *                                                                                        *
-- * It consists of 4 DPRams, which act like one big memory for the avalon slave. The four  *
-- * DPRams are selected by the first two bits of the avalon slave address with a data size *
-- * of 32 bit.                                                                             *
-- * The Framemanipulator receives the data of all 4 DPRams at once with a word size of 64  *
-- * bit.                                                                                   *
-- *                                                                                        *
-- * s_clk: clock domain of the avalon slaves                                               *
-- * s_...  avalon slave for the task-memory                                                *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Task_Memory                             by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Use work library
library work;
--! use global library
use work.global.all;

entity Task_Memory is
    generic(gSlaveWordWidth:    natural :=4*cByteLength;
            gWordWidth:         natural :=8*cByteLength;
            gSlaveAddrWidth:    natural :=11;
            gAddresswidth:      natural :=8);
    port(
        clk:            in std_logic;
        --avalon bus (s_clk domain)
        s_clk:          in std_logic;   --Clock of the slave
        s_iAddr:        in std_logic_vector(gSlaveAddrWidth-1 downto 0);
        s_iWrEn:        in std_logic;
        s_iRdEn:        in std_logic;
        s_iByteEn:      in std_logic_vector((gSlaveWordWidth/cByteLength)-1 downto 0);
        s_iWriteData:   in std_logic_vector(gSlaveWordWidth-1 downto 0);
        s_oReadData:    out std_logic_vector(gSlaveWordWidth-1 downto 0);
        --memory signals
        iTaskAddr:      in std_logic_vector(gAddresswidth-1 downto 0);  --Address of the current task
        iClTaskMem:     in std_logic;                                   --Delete task
        oSettingData:   out std_logic_vector(2*gWordWidth-1 downto 0);  --output task setting
        oCompFrame:     out std_logic_vector(gWordWidth-1 downto 0);    --output task frame
        oCompMask:      out std_logic_vector(gWordWidth-1 downto 0)     --output task mask
     );
end Task_Memory;

architecture two_seg_arch of Task_Memory is

    --DPRam Port A= Softcore, B=Hardware Manipulator
    component DPRAM_Plus
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

    signal s_WriteEn:       std_logic_vector(3 downto 0);               --write enable
    signal s_SelEn:         std_logic_vector(2 downto 0);               --DPRam Selection
    signal s_WrTaskAddr:    std_logic_vector(gAddresswidth downto 0);   --write address
    signal rd_TaskMem:      std_logic;                                  --read task

    --data output for PL-Slave
    signal s_ReadData0:     std_logic_vector(gWordWidth/2-1 downto 0);  --data of PDRam 0
    signal s_ReadData1:     std_logic_vector(gWordWidth/2-1 downto 0);  --data of PDRam 1
    signal s_ReadData2:     std_logic_vector(gWordWidth/2-1 downto 0);  --data of PDRam 2
    signal s_ReadData3:     std_logic_vector(gWordWidth/2-1 downto 0);  --data of PDRam 3

begin

    --Isolate the selection of the Buffers from the address line----------------------------------------
    s_SelEn<=s_iAddr(s_iAddr'left downto s_iAddr'left-1)&s_iWrEn;   --first two address-bits => DPRam selection + WriteEnable
    s_WrTaskAddr<=s_iAddr(gAddresswidth downto 0);                  --remaining address-bits => real address



    --Aktivate the different Buffer for Port A ---------------------------------------------------------
    with s_SelEn select --last bit=1 => write
        s_WriteEn<= "0001" when "001",  --write 00 => PDRam 0
                    "0010" when "011",  --write 01 => PDRam 1
                    "0100" when "101",  --write 10 => PDRam 2
                    "1000" when "111",  --write 11 => PDRam 3
                    "0000" when others;


    rd_TaskMem <= not iClTaskMem;


    --Mapping of the four Buffers ---------------------------------------------------------------------
    ManiDataBuffer1:DPRAM_Plus
    generic map(gAddresswidthA=>gAddresswidth+1,gAddresswidthB=>gAddresswidth,gWordWidthA=>gWordWidth/2,
                gWordWidthB=>gWordWidth)
    port map(
            clock_a=>s_clk,clock_b=>clk,
            --port A PL-Slave
            address_a=>s_WrTaskAddr,    byteena_a=>s_iByteEn,       data_a=>s_iWriteData,
            wren_a=>s_WriteEn(0),       rden_a=>s_iRdEn,
            --port B FM
            address_b=>iTaskAddr,       byteena_b=>(others=>'1'),   data_b=>(others=>'0'),
            wren_b=>iClTaskMem,         rden_b=>rd_TaskMem,
            --output
            q_a=>s_ReadData0,           q_b=>oSettingData(2*gWordWidth-1 downto gWordWidth));--first 8Byte


    ManiDataBuffer2:DPRAM_Plus
    generic map(gAddresswidthA=>gAddresswidth+1,gAddresswidthB=>gAddresswidth,gWordWidthA=>gWordWidth/2,
                gWordWidthB=>gWordWidth)
    port map(
            clock_a=>s_clk,clock_b=>clk,
            --port A PL-Slave
            address_a=>s_WrTaskAddr,    byteena_a=>s_iByteEn,       data_a=>s_iWriteData,
            wren_a=>s_WriteEn(1),       rden_a=>s_iRdEn,
            --port B FM
            address_b=>iTaskAddr,       byteena_b=>(others=>'1'),   data_b=>(others=>'0'),
            wren_b=>iClTaskMem,         rden_b=>rd_TaskMem,
            --output
            q_a=>s_ReadData1,           q_b=>oSettingData(gWordWidth-1 downto 0));--second 8Byte


    CompFrameBuffer:DPRAM_Plus
    generic map(gAddresswidthA=>gAddresswidth+1,gAddresswidthB=>gAddresswidth,gWordWidthA=>gWordWidth/2,
                gWordWidthB=>gWordWidth)
    port map(
            clock_a=>s_clk,clock_b=>clk,
            --port A PL-Slave
            address_a=>s_WrTaskAddr,    byteena_a=>s_iByteEn,       data_a=>s_iWriteData,
            wren_a=>s_WriteEn(2),       rden_a=>s_iRdEn,
            --port B FM
            address_b=>iTaskAddr,       byteena_b=>(others=>'1'),   data_b=>(others=>'0'),
            wren_b=>iClTaskMem,         rden_b=>rd_TaskMem,
            --output
            q_a=>s_ReadData2,q_b=>oCompFrame);


    CompMaskBuffer:DPRAM_Plus
    generic map(gAddresswidthA=>gAddresswidth+1,gAddresswidthB=>gAddresswidth,gWordWidthA=>gWordWidth/2,
                gWordWidthB=>gWordWidth)
    port map(
            clock_a=>s_clk,clock_b=>clk,
            --port A PL-Slave
            address_a=>s_WrTaskAddr,    byteena_a=>s_iByteEn,       data_a=>s_iWriteData,
            wren_a=>s_WriteEn(3),       rden_a=>s_iRdEn,
            --port B FM
            address_b=>iTaskAddr,       byteena_b=>(others=>'1'),   data_b=>(others=>'0'),
            wren_b=>iClTaskMem,         rden_b=>rd_TaskMem,
            --output
            q_a=>s_ReadData3,           q_b=>oCompMask);



    --Select the Output data for Port A ----------------------------------------------------------------
    with s_SelEn select --last bit=0 => read
        s_oReadData<=   s_ReadData0 when "000", --read 00 => DPRam 0
                        s_ReadData1 when "010", --read 01 => DPRam 1
                        s_ReadData2 when "100", --read 10 => DPRam 2
                        s_ReadData3 when "110", --read 11 => DPRam 3
                        (others=>'0') when others;



end two_seg_arch;
