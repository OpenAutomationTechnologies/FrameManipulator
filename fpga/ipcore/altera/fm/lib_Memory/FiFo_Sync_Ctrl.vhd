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

    --add component for LFSR

    --constant LFSR_CTR: natural:=0;

    signal w_ptr_reg:   std_logic_vector(N-1 downto 0);
    signal w_ptr_next:  std_logic_vector(N-1 downto 0);
    signal w_ptr_succ:  std_logic_vector(N-1 downto 0);

    signal r_ptr_reg:   std_logic_vector(N-1 downto 0);
    signal r_ptr_next:  std_logic_vector(N-1 downto 0);
    signal r_ptr_succ:  std_logic_vector(N-1 downto 0);

    signal full_reg:    std_logic;
    signal empty_reg:   std_logic;
    signal full_next:   std_logic;
    signal empty_next:  std_logic;

    signal wr_op:   std_logic_vector(1 downto 0);

begin

    --register for read and write pointers
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                w_ptr_reg<=(others=>'0');
                r_ptr_reg<=(others=>'0');
            else
                w_ptr_reg<=w_ptr_next;
                r_ptr_reg<=r_ptr_next;
            end if;
        end if;
    end process;

    --statue FF
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                full_reg<='0';
                empty_reg<='1';
            else
                full_reg<=full_next;
                empty_reg<=empty_next;
            end if;
        end if;
    end process;

    --successive value for LFSR counter

    --insert component here

    --successive value for binary counter
    --g_bin
    --if (CNT_MODE/=LFSR_CTR) generate
        w_ptr_succ<=std_logic_vector(unsigned(w_ptr_reg)+1);
        r_ptr_succ<=std_logic_vector(unsigned(r_ptr_reg)+1);
    --end generate

    --next-state logic for read and write pointers

    wr_op<=iWr & iRd;

    process(w_ptr_reg,w_ptr_succ,r_ptr_reg,r_ptr_succ,wr_op,empty_reg,full_reg)
    begin
        w_ptr_next<=w_ptr_reg;
        r_ptr_next<=r_ptr_reg;

        full_next<=full_reg;
        empty_next<=empty_reg;

        case wr_op is
            when "00" =>    --no operation

            when "01" =>    --read
                if (empty_reg /= '1') then  --not empty
                    r_ptr_next<=r_ptr_succ;
                    full_next<='0';
                    if (r_ptr_succ=w_ptr_reg) then
                        empty_next<='1';
                    end if;
                end if;

            when "10" =>    --write
                if (full_reg /= '1') then   --not full
                    w_ptr_next<=w_ptr_succ;
                    empty_next<='0';
                    if (w_ptr_succ=r_ptr_reg) then
                        full_next<='1';
                    end if;
                end if;

            when others=>   --write/read
                w_ptr_next<=w_ptr_succ;
                r_ptr_next<=r_ptr_succ;
        end case;
    end process;

    --output

    oWrAddr <=w_ptr_reg;
    oRdAddr <=r_ptr_reg;

    oFull   <=full_reg;
    oEmpty  <=empty_reg;

end arch;