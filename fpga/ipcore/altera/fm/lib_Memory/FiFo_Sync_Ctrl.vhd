--fifo address counter
--Source: RTL Hardware Design Using VHDL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FiFo_Sync_Ctrl is
    generic(
        N:natural:=8;
        Cnt_Mode:natural:=0--binary or LFSR(not included)
    );
    port(
        clk, reset: in std_logic;
        iRd:        in std_logic;
        iWr:        in std_logic;
        oWrAddr:    out std_logic_vector(N-1 downto 0);
        oRdAddr:    out std_logic_vector(N-1 downto 0);
        oFull:      out std_logic;
        oEmpty:     out std_logic
    );
end FiFo_Sync_Ctrl;

architecture arch of FiFo_Sync_Ctrl is

    --! Typedef for registers
    type tReg is record
        w_ptr   : std_logic_vector(N-1 downto 0);   --! write pointer
        r_ptr   : std_logic_vector(N-1 downto 0);   --! read pointer
        full    : std_logic;                        --! FiFo is full
        empty   : std_logic;                        --! FiFo is empty
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

    signal w_ptr_succ:  std_logic_vector(N-1 downto 0);
    signal r_ptr_succ:  std_logic_vector(N-1 downto 0);

    signal wr_op:   std_logic_vector(1 downto 0);

begin


    --! @brief Registers
    --! - Storing with asynchronous reset
    --! - For read and write pointers and states
    registers :
    process(clk, reset)
    begin
        if reset='1' then
            reg <= cRegInit;

        elsif rising_edge(clk) then
            reg <= reg_next;

        end if;
    end process;


    --successive value for LFSR counter

    --insert component here

    --successive value for binary counter
    --g_bin
    --if (CNT_MODE/=LFSR_CTR) generate
        w_ptr_succ  <= std_logic_vector(unsigned(reg.w_ptr)+1);
        r_ptr_succ  <= std_logic_vector(unsigned(reg.r_ptr)+1);
    --end generate

    --next-state logic for read and write pointers

    wr_op<=iWr & iRd;

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

    oWrAddr <=reg.w_ptr;
    oRdAddr <=reg.r_ptr;

    oFull   <=reg.full;
    oEmpty  <=reg.empty;

end arch;