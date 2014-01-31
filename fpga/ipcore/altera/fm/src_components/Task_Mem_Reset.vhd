
-- ******************************************************************************************
-- *                                    Task_Mem_Reset                                      *
-- ******************************************************************************************
-- *                                                                                        *
-- * component to clear up all tasks of the Task_Memory                                     *
-- *                                                                                        *
-- * it is connected between the reading process_unit and the task_memory                   *
-- *                                                                                        *
-- * when iClearMem = 1 => the tasks are cleared on the positive edge one after another     *
-- *                                                                                        *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      Task_Mem_Reset                          by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Task_Mem_Reset is
    generic(gAddrWidth:natural:=6);
    port(
        clk, reset:     in std_logic;

        iRdAddress:     in std_logic_vector(gAddrWidth-1 downto 0); --reading task address
        iClearMem:      in std_logic;                               --Operation: Clear all tasks
        oTaskMemAddr:   out std_logic_vector(gAddrWidth-1 downto 0);--reading/clearing task address
        oEnClear:       out std_logic                               --clear enable
    );
end  Task_Mem_Reset;


architecture two_seg_arch of Task_Mem_Reset is

    --counter for the addresses to clear
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
            clk, reset:   in std_logic;
            iClear:       in std_logic;
            iEn:          in std_logic;
            iStartValue:  in std_logic_vector(gCntWidth-1 downto 0);
            iEndValue:    in std_logic_vector(gCntWidth-1 downto 0);
            oQ:           out std_logic_vector(gCntWidth-1 downto 0);
            oOv:          out std_logic
        );
    end component;

    --Counter variables
    signal addrCnt:     std_logic_vector(iRdAddress'range);
    signal ClearEn:     std_logic;
    signal addrOv:      std_logic;

    signal ClearMem_Reg:std_logic;  --Register for edge-detection

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - RS-FF for cnter-enable
    process(clk, reset)
    begin
        if reset='1' then
            ClearEn         <= '0';
            ClearMem_Reg    <= '0';

        elsif rising_edge(clk) then

            if iClearMem='1' and ClearMem_Reg='0' then  --enable cnter on edge
                ClearEn <= '1';

            elsif addrOv='1' then                       --disable cnter at overflow
                ClearEn <= '0';

            end if;

            ClearMem_Reg    <= iClearMem;

        end if;
    end process;

    --cnter
    Cnter:Basic_Cnter
    generic map(gCntWidth=>gAddrWidth)
    port map(
            clk=>clk,reset=>reset,
            iClear=>'0',iEn=>ClearEn,iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ=>addrCnt,oOv=>addrOv);


    --selection between clear- and read-address
    oTaskMemAddr<=addrCnt when ClearEn='1' else iRdAddress;

    oEnClear<=ClearEn;

end two_seg_arch;