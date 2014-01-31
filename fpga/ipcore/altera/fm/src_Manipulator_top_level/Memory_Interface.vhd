
-- ******************************************************************************************
-- *                                Memory_Interface                                        *
-- ******************************************************************************************
-- *                                                                                        *
-- * Shared memory interface between the Framemanipulator and its POWERLINK Slave           *
-- *                                                                                        *
-- * s_clk: clock domain of the avalon slaves                                               *
-- * st_... avalon slave for the task-memory                                                *
-- * sc_... avalon slave for the control registers (operations and error)                   *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Memory_Interface                        by Sebastian Muelhausen     *
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

entity Memory_Interface is
    generic(gSlaveTaskWordWidth:    natural:=4*cByteLength;
            gSlaveTaskAddrWidth:    natural:=8;
            gTaskWordWidth:         natural:=8*cByteLength;
            gTaskAddrWidth:         natural:=5;
            gSlaveControlWordWidth: natural:=cByteLength;
            gSlaveControlAddrWidth: natural:=1
        );
    port(
        clk, reset:             in std_logic;
        s_clk:                  in std_logic;   --avalon bus clock domain
        --Avalon Slave Task Memory
        st_address:             in std_logic_vector(gSlaveTaskAddrWidth-1 downto 0);
        st_writedata:           in std_logic_vector(gSlaveTaskWordWidth-1 downto 0);
        st_write:               in std_logic;
        st_read:                in std_logic;
        st_readdata:            out std_logic_vector(gSlaveTaskWordWidth-1 downto 0);
        st_byteenable:          in std_logic_vector((gSlaveTaskWordWidth/cByteLength)-1 downto 0);
        --Avalon Slave Contol Memory
        sc_address:             in std_logic_vector(gSlaveControlAddrWidth-1 downto 0);
        sc_writedata:           in std_logic_vector(gSlaveControlWordWidth-1 downto 0);
        sc_write:               in std_logic;
        sc_read:                in std_logic;
        sc_readdata:            out std_logic_vector(gSlaveControlWordWidth-1 downto 0);
        sc_byteenable:          in std_logic_vector(gSlaveControlWordWidth/cByteLength-1 downto 0);
        --status signals
        iError_Addr_Buff_OV:    in std_logic;   --Error: Overflow address-buffer
        iError_Frame_Buff_OV:   in std_logic;   --Error: Overflow data-buffer
        iError_Packet_Buff_OV:  in std_logic;   --Error: Overflow packet-buffer
        iError_Task_Conf:       in std_logic;   --Error: Wrong task configuration
        oStartTest:             out std_logic;  --start a new series of test
        oStopTest:              out std_logic;  --aborts the current test
        oClearMem               : out std_logic;  --clear all tasks
        oResetPaketBuff:        out std_logic;  --Resets the packet FIFO and removes the packet lag
        iTestActive:            in std_logic;   --Series of test is active
        --task signals
        iRdTaskAddr:            in std_logic_vector(gTaskAddrWidth-1 downto 0);     --task selection
        oTaskSettingData:       out std_logic_vector(2*gTaskWordWidth-1 downto 0);  --settings of the task
        oTaskCompFrame:         out std_logic_vector(gTaskWordWidth-1 downto 0);    --header-data of the manipulated frame
        oTaskCompMask:          out std_logic_vector(gTaskWordWidth-1 downto 0)     --mask-data of the manipulated frame
    );
end Memory_Interface;

architecture two_seg_arch of Memory_Interface is


    --control register -----------------------------------------------------------------------
    --interface to the PL-Slave for the different operations and error-messages
    component Control_Register is
        generic(gWordWidth:         natural :=cByteLength;
                gAddresswidth:      natural :=1);
        port(
            clk, reset:             in std_logic;
            s_clk:                  in std_logic;   --Clock of the slave
            --Controls
            oStartTest:             out std_logic;  --Start new series of test
            oStopTest:              out std_logic;  --Stop current sereis of test
            oClearMem:              out std_logic;  --clear all tasks
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
    end component;



    --component to clear up all tasks --------------------------------------------------------
    --is connected in front of the task memory
    component Task_Mem_Reset
        generic(gAddrWidth:natural:=6);
        port(
            clk, reset:     in std_logic;
            iRdAddress:     in std_logic_vector(gAddrWidth-1 downto 0); --reading task address
            iClearMem:      in std_logic;                               --Operation: Clear all tasks
            oTaskMemAddr:   out std_logic_vector(gAddrWidth-1 downto 0);--reading/clearing task address
            oEnClear:       out std_logic                               --clear enable
        );
    end  component;


    --task-memory ----------------------------------------------------------------------------
    --memory for the different manipulation tasks
    component Task_Memory
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
            s_iByteEn:      in std_logic_vector((gSlaveWordWidth/cByteLength)-1 DOWNTO 0);
            s_iWriteData:   in std_logic_vector(gSlaveWordWidth-1 downto 0);
            s_oReadData:    out std_logic_vector(gSlaveWordWidth-1 downto 0);
            --memory signals
            iTaskAddr:      in std_logic_vector(gAddresswidth-1 downto 0);  --Address of the current task
            iClTaskMem:     in std_logic;                                   --Delete task
            oSettingData:   out std_logic_vector(2*gWordWidth-1 downto 0);  --output task setting
            oCompFrame:     out std_logic_vector(gWordWidth-1 downto 0);    --output task frame
            oCompMask:      out std_logic_vector(gWordWidth-1 downto 0)     --output task
        );
    end component;


    signal ClearMem:std_logic;
    signal ClTask:  std_logic;
    signal TaskAddr:std_logic_vector(gTaskAddrWidth-1 downto 0);


begin

    --control register -----------------------------------------------------------------------
    --operations:       MN  =>  PL-Slave    =>  Framemanipultaor
    --error-messages:   Framemanipulator    =>  PL-Slave    =>  MN
    ------------------------------------------------------------------------------------------
    C_Reg:Control_Register
    generic map(gWordWidth=>gSlaveControlWordWidth,gAddresswidth=>gSlaveControlAddrWidth)
    port map(
            clk=>clk,   s_clk=>s_clk,       reset=>reset,
            --operations
            oStartTest=>oStartTest,         oStopTest=>oStopTest,
            oClearMem=>ClearMem,            oResetPaketBuff=>oResetPaketBuff,
            iTestActive=>iTestActive,
            --Error messages
            iError_Addr_Buff_OV=>iError_Addr_Buff_OV,
            iError_Frame_Buff_OV=>iError_Frame_Buff_OV,
            iError_Packet_Buff_OV=>iError_Packet_Buff_OV,
            iError_Task_Conf=>iError_Task_Conf,
            --avalon bus (s_clk-domain)
            s_iAddr=>sc_address,            s_iWriteData=>sc_writedata,     s_iWrEn=>sc_write,
            s_iRdEn=>sc_read,               s_iByteEn=>sc_byteenable,       s_oReadData=>sc_readdata
            );

    oClearMem   <= ClearMem;



    --component to clear up all tasks --------------------------------------------------------
    --deletes all tasks
    --It is conneted in series to the task-memory and selects between reading data and
    --clearing tasks
    ------------------------------------------------------------------------------------------
    T_Mem_Res:Task_Mem_Reset
    generic map(gAddrWidth=>gTaskAddrWidth)
    port map(
            clk=>clk, reset=>reset,
            iRdAddress=>iRdTaskAddr,    iClearMem=>ClearMem,
            oTaskMemAddr=>TaskAddr,     oEnClear=>ClTask);


    --task-memory ----------------------------------------------------------------------------
    --Port A: PL-Slave: one memory with 32bit word-width and the avalon bus clock domain
    --Port B: FM:   three memories with 64bit word-width and 50MHz ethernet clock domain
    --task selection with iTaskAddr
    --clear task with iClTaskMem
    --task data: oSettingData, oCompFrame and oCompMask
    ------------------------------------------------------------------------------------------
    T_Memory:Task_Memory
    generic map(gSlaveWordWidth=>gSlaveTaskWordWidth,
                gWordWidth=>gTaskWordWidth,gSlaveAddrWidth=>gSlaveTaskAddrWidth,gAddresswidth=>gTaskAddrWidth)
    port map (
            clk=>clk,s_clk=>s_clk,
            --avalon bus (s_clk domain)
            s_iAddr=>st_address,        s_iWriteData=>st_writedata, s_iWrEn=>st_write,
            s_iRdEn=>st_read,
            s_oReadData=>st_readdata,   s_iByteEn=>st_byteenable,
            --memory signals
            iClTaskMem=>ClTask,         iTaskAddr=>TaskAddr,        oSettingData=>oTaskSettingData,
            oCompFrame=>oTaskCompFrame, oCompMask=>oTaskCompMask);



end two_seg_arch;