-------------------------------------------------------------------------------
--! @file Task_Mem_Reset.vhd
--! @brief Clear up task memory
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


--! This is the entity of the module for clearing the task memory.
entity Task_Mem_Reset is
    generic(gAddrWidth  : natural := 6);    --! Address width of the tasks
    port(
        iClk            : in std_logic;                                 --! clk
        iReset          : in std_logic;                                 --! reset
        iRdAddress      : in std_logic_vector(gAddrWidth-1 downto 0);   --! reading task address
        iClearMem       : in std_logic;                                 --! Operation: Clear all tasks
        oTaskMemAddr    : out std_logic_vector(gAddrWidth-1 downto 0);  --! reading/clearing task address
        oEnClear        : out std_logic                                 --! clear enable
    );
end  Task_Mem_Reset;

--! @brief Task_Mem_Reset architecture
--! @details Deletes all tasks of the memory
architecture two_seg_arch of Task_Mem_Reset is

    --Counter variables
    signal addrCnt  : std_logic_vector(iRdAddress'range);   --! Counter for task address
    signal clearEn  : std_logic;                            --! Enable clearing memroy on positive edge
    signal addrOv   : std_logic;                            --! Overflow of address counter => stop clear

    signal clearMem_reg : std_logic;  --! Register for edge-detection

begin

    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - RS-FF for cnter-enable
    process(iClk, iReset)
    begin
        if iReset='1' then
            clearEn         <= '0';
            clearMem_reg    <= '0';

        elsif rising_edge(iClk) then

            if iClearMem='1' and clearMem_reg='0' then  --enable cnter on edge
                clearEn <= '1';

            elsif addrOv='1' then                       --disable cnter at overflow
                clearEn <= '0';

            end if;

            clearMem_reg    <= iClearMem;

        end if;
    end process;

    --! @brief Counter for the addresses to clear
    Cnter : work.Basic_Cnter
    generic map(gCntWidth=>gAddrWidth)
    port map(
            iClk        => iClk,
            iReset      => iReset,
            iClear      => '0',
            iEn         => clearEn,
            iStartValue => (others=>'0'),
            iEndValue   => (others=>'1'),
            oQ          => addrCnt,
            oOv         => addrOv
            );


    --! selection between clear- and read-address
    oTaskMemAddr    <= addrCnt when clearEn = '1' else iRdAddress;

    oEnClear    <= clearEn;

end two_seg_arch;