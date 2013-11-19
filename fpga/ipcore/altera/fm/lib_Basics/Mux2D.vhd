--Two-dimensional Multiplexer using an one-dimensional parameterized tree-shaped multiplexer
--Source: RTL Hardware Design Using VHDL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Mux2D is
    generic(gWordsWidth: natural:=8;
            gWordsNo:   natural:=8;
            gWidthSel:  natural:=3);
    port(
        iData:  in std_logic_vector(gWordsWidth*gWordsNo-1 downto 0);
        iSel:   in std_logic_vector(gWidthSel-1 downto 0);
        oWord:  out std_logic_vector(gWordsWidth-1 downto 0)
        );
end Mux2D;

architecture loop_tree_arch of Mux2D is

    constant cRoW:natural:=gWordsWidth;

    function ix(c,r:natural) return natural is
    begin
        return (c*cRoW+r);      --!!!!!!!!
    end ix;

    component Mux1D
        generic(gWidthData: natural:=8;
                gWidthSel:  natural:=3);
        port(
            iData:  in std_logic_vector(gWidthData-1 downto 0);
            iSel:   in std_logic_vector(gWidthSel-1 downto 0);
            oBit:   out std_logic
            );
    end component;

    type array_transpose_type is
        array(gWordsWidth-1 downto 0) of std_logic_vector(gWordsNo-1 downto 0);

    signal ArrayConnect:    array_transpose_type;

begin

    --convert to array-of-array data type
    process(iData)
    begin
        for i in 0 to (gWordsWidth-1) loop
            for j in 0 to (gWordsNo-1) loop
                ArrayConnect(i)(j)<=iData(ix(j,i));
            end loop;
        end loop;
    end process;

    --replicate 1-Bit multiplexer gWordsWidth times
    gen_nbit: for i in 0 to (gWordsWidth-1) generate
        mux:Mux1D
            generic map(gWidthData=>gWordsNo,gWidthSel=>gWidthSel)
            port map(iData=>ArrayConnect(i),iSel=>iSel,
                oBit=>oWord(i));
    end generate;

end loop_tree_arch;