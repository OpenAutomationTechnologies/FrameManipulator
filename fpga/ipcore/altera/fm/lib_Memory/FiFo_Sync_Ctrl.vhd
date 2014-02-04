-------------------------------------------------------------------------------
--! @file FiFo_Sync_Ctrl.vhd
--! @brief Control module of FiFo
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

--! This is the entity of the FiFo control module
entity FiFo_Sync_Ctrl is
    generic(
            gAddrWidth  : natural:=8;   --! Address width
            gCnt_Mode   : natural:=0    --! binary or LFSR(not included yet)
            );
    port(
        iClk        : in std_logic;                                 --! clk
        iReset      : in std_logic;                                 --! reset
        iRd         : in std_logic;                                 --! Read FiFo
        iWr         : in std_logic;                                 --! Write FiFo
        oWrAddr     : out std_logic_vector(gAddrWidth-1 downto 0);  --! Write address
        oRdAddr     : out std_logic_vector(gAddrWidth-1 downto 0);  --! Read address
        oFull       : out std_logic;                                --! FiFo is full
        oEmpty      : out std_logic                                 --! FiFo is empty
    );
end FiFo_Sync_Ctrl;


--! @brief FiFo_Sync_Ctrl architecture
--! @details Control modul of FiFo
--! - Source: RTL Hardware Design Using VHDL
architecture arch of FiFo_Sync_Ctrl is

    --! Typedef for registers
    type tReg is record
        w_ptr   : std_logic_vector(gAddrWidth-1 downto 0);  --! write pointer
        r_ptr   : std_logic_vector(gAddrWidth-1 downto 0);  --! read pointer
        full    : std_logic;                                --! FiFo is full
        empty   : std_logic;                                --! FiFo is empty
    end record;

    --! Init for registers
    constant cRegInit   : tReg :=(
                                w_ptr   => (others=>'0'),
                                r_ptr   => (others=>'0'),
                                full    => '0',
                                empty   => '1'              --is empty at begin
                                );

    signal reg          : tReg; --! Registers
    signal reg_next     : tReg; --! Next value of registers

    signal w_ptr_succ   : std_logic_vector(gAddrWidth-1 downto 0);  --! successive write value for binary counter
    signal r_ptr_succ   : std_logic_vector(gAddrWidth-1 downto 0);  --! successive read value for binary counter

    signal wr_op        : std_logic_vector(1 downto 0);     --! Read/Write operation

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - For read and write pointers and states
    registers :
    process(iClk, iReset)
    begin
        if iReset='1' then
            reg <= cRegInit;

        elsif rising_edge(iClk) then
            reg <= reg_next;

        end if;
    end process;


    w_ptr_succ  <= std_logic_vector(unsigned(reg.w_ptr)+1);
    r_ptr_succ  <= std_logic_vector(unsigned(reg.r_ptr)+1);

    wr_op<=iWr & iRd;


    --! @brief next-state logic for read and write pointers
    process(reg,w_ptr_succ,r_ptr_succ,wr_op)
    begin
        reg_next.w_ptr  <= reg.w_ptr;
        reg_next.r_ptr  <= reg.r_ptr;

        reg_next.full   <= reg.full;
        reg_next.empty  <= reg.empty;

        case wr_op is
            when "00" =>    --no operation

            when "01" =>    --read
                if (reg.empty /= '1') then  --not empty
                    reg_next.r_ptr  <= r_ptr_succ;
                    reg_next.full   <= '0';
                    if (r_ptr_succ = reg.w_ptr) then
                        reg_next.empty  <= '1';
                    end if;
                end if;

            when "10" =>    --write
                if (reg.full /= '1') then   --not full
                    reg_next.w_ptr  <= w_ptr_succ;
                    reg_next.empty  <= '0';
                    if (w_ptr_succ = reg.r_ptr) then
                        reg_next.full   <= '1';
                    end if;
                end if;

            when others=>   --write/read
                reg_next.w_ptr  <= w_ptr_succ;
                reg_next.r_ptr  <= r_ptr_succ;
        end case;
    end process;

    --output

    oWrAddr <= reg.w_ptr;
    oRdAddr <= reg.r_ptr;

    oFull   <= reg.full;
    oEmpty  <= reg.empty;

end arch;