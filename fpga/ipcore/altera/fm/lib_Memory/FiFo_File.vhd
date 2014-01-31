--fifo memory
--Source: RTL Hardware Design Using VHDL

--updated data-register with the Altera Coding Styles by Sebastian Mülhausen
--for usage of M9Ks of Altera FPGAs instead of LCs

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FiFo_File is
    generic(
        B:natural:=8;       --number of Bits
        W:natural:=8        --number of address bits
    );
    port(
        clk:        in std_logic;
        iWrEn:      in std_logic;
        iWrAddr:    in std_logic_vector(W-1 downto 0);
        iRdAddr:    in std_logic_vector(W-1 downto 0);
        iWrData:    in std_logic_vector(B-1 downto 0);
        oRdData:    out std_logic_vector(B-1 downto 0)
    );
end FiFo_File;




architecture arch_Altera of FiFo_File is

    type reg_file_type is array (2**W-1 downto 0) of
        std_logic_vector(B-1 downto 0);

    signal array_reg:   reg_file_type:=(others=>(others=>'0'));
    signal RdAddr_reg:  std_logic_vector(W-1 downto 0);


begin

    --! @brief Registers
    --! - Register array without reset
    process(clk)
    begin
        if (clk'event and clk='1') then
            if iWrEn='1' then
                array_reg(to_integer(unsigned(iWrAddr)))<=iWrData;
            end if;
            RdAddr_reg<=iRdAddr;
        end if;
    end process;

    oRdData<= array_reg(to_integer(unsigned(RdAddr_reg)));

end arch_Altera;