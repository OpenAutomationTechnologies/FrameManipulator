--fifo control
--Source: RTL Hardware Design Using VHDL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FiFo_top is
    generic(
        B:natural:=8;       --number of Bits
        W:natural:=8;       --number of address bits
        Cnt_Mode:natural:=0 --binary or LFSR(not included)
    );
    port(
        clk, reset: in std_logic;
        iRd:        in std_logic;
        iWr:        in std_logic;
        iWrData:    in std_logic_vector(B-1 downto 0);
        oFull:      out std_logic;
        oEmpty:     out std_logic;
        oRdData:    out std_logic_vector(B-1 downto 0)
     );
end FiFo_top;

architecture arch of FiFo_top is

    component fifo_sync_ctrl
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
    end component;

    component fifo_file
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
    end component;

    signal rd_addr: std_logic_vector(W-1 downto 0);
    signal wr_addr: std_logic_vector(W-1 downto 0);
    signal f_status:std_logic;
    signal wr_fifo: std_logic;

begin

    cntr:fifo_sync_ctrl
    generic map(N=>W,Cnt_Mode=>Cnt_Mode)
    port map(
            clk=>clk,reset=>reset,
            iRd=>iRd,iWr=>iWr,
            oWrAddr=>wr_addr,oRdAddr=>rd_addr,oFull=>f_status,oEmpty=>oEmpty);

    wr_fifo<= iWr and (not f_status);
    oFull<=f_status;

    reg:fifo_file
    generic map(B=>B,W=>W)
    port map(
            clk=>clk,
            iWrEn=>wr_fifo,iWrAddr=>wr_addr,iRdAddr=>rd_addr,iWrData=>iWrData,
            oRdData=>oRdData);

end arch;