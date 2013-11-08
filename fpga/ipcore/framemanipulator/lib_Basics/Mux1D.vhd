--Parameterized tree-shaped multiplexer
--Source: RTL Hardware Design Using VHDL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Mux1D is
    generic(gWidthData: natural:=8;
            gWidthSel:  natural:=3);
    port(
        iData:  in std_logic_vector(gWidthData-1 downto 0);
        iSel:   in std_logic_vector(gWidthSel-1 downto 0);
        oBit:   out std_logic
        );
end Mux1D;

architecture loop_tree_arch of Mux1D is
    constant cStage: natural:=gWidthSel;

    type std_logic_2d is
        array (natural range <>, natural range <>) of std_logic;

    signal p: std_logic_2d(cStage downto 0, 2**cStage-1 downto 0);

begin

    process(iData,iSel,p)
    begin
        for i in 0 to (2**cStage-1) loop
            if i<gWidthData then
                p(cStage,i) <= iData(i);    --rename input signal
            else
                p(cStage,i) <= '0';     --padding 0's
            end if;
        end loop;

        --replace structure

        for s in (cStage-1) downto 0 loop
            for r in 0 to (2**s-1) loop
                if iSel((cStage-1)-s)='0' then
                    p(s,r) <= p(s+1,2*r);
                else
                    p(s,r) <= p(s+1,2*r+1);
                end if;
            end loop;
        end loop;
    end process;

    --rename output signal
    oBit<= p(0,0);

end loop_tree_arch;