-- **************************************************************************
-- *                       end_of_frame_detection                           *
-- **************************************************************************
-- *                                                                        *
-- * It listens to the RX Data Valid signal and saves the address of the    *
-- * last Byte                                                              *
-- *                                                                        *
-- * in:  iRXDV     input to recognize the end of the stream of data        *
-- *      iAddr     current address of the Byte                             *
-- * out: oEndAddr  Data                                                    *
-- *      oFrameEnd Data changed                                            *
-- *                                                                        *
-- *------------------------------------------------------------------------*
-- *                                                                        *
-- * 08.05.12 V1.0 created end_of_frame_detection  by Sebastian Muelhausen  *
-- * 01.06.12 V1.1 added oFrameEnd                 by Sebastian Muelhausen  *
-- *                                                                        *
-- **************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity end_of_frame_detection is
    generic(gBuffAddrWidth:natural:=11);
    port(
        clk, reset: in std_logic;
        iRXDV:      in std_logic;
        iAddr:      in std_logic_vector(gBuffAddrWidth-1 downto 0);
        iStartAddr: in std_logic_vector(gBuffAddrWidth-1 downto 0);
        iCutEn:     in std_logic;
        iCutData:   in std_logic_vector(gBuffAddrWidth-1 downto 0);
        oEndAddr:   out std_logic_vector(gBuffAddrWidth-1 downto 0);
        oFrameEnd:  out std_logic
    );
end end_of_frame_detection;

architecture Behave of end_of_frame_detection is

    --shift register to realize the last edge of RXDV
    --edge detection isn't enough. Signal could toggle before it ends
    component shift_right_register
        generic(
            gWidth: natural:=8
            );
        port(
            clk, reset: in std_logic;
            iD: in std_logic;
            oQ: out std_logic_vector(gWidth-1 downto 0)
        );
    end component;

    --register for the last Edge detection
    signal Addr_reg:    std_logic_vector(gBuffAddrWidth-1 downto 0);
    signal Addr_next:   std_logic_vector(gBuffAddrWidth-1 downto 0);
    signal RXD_reg:     std_logic_vector(2 downto 0);

    signal CutAddr: std_logic_vector(gBuffAddrWidth-1 downto 0);
    signal NewAddr: std_logic_vector(gBuffAddrWidth-1 downto 0);

    --register for end of frame
    signal end_reg: std_logic;
    signal end_next:std_logic;

begin

    process(clk, reset)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                Addr_reg <= (others => '0');
                end_reg<='0';
            else
                Addr_reg <= Addr_next;
                end_reg <= end_next;
            end if;
        end if;
    end process;

    --shift register to save the last values of RXDV
    RX_shift:shift_right_register
    generic map(gWidth=>3)
    port map(
            clk=>clk, reset=>reset,
            iD=>iRXDV,
            oQ=>RXD_reg);


    CutAddr<=std_logic_vector(unsigned(iStartAddr)+unsigned(iCutData)+5);   -- +4 cause of CRC   +1 for end

    end_next<= '1' when (RXD_reg="000")or(iCutEn='1' and (iAddr=CutAddr or (unsigned(iCutData)+5<(unsigned(iAddr)-unsigned(iStartAddr))))) else end_reg and iCutEn;
    NewAddr<=iAddr when (RXD_reg="000")or iCutEn='0' else CutAddr;
    Addr_next<= NewAddr when end_next='1' and end_reg='0' else Addr_reg;

    oEndAddr<=Addr_reg;
    oFrameEnd<= '1' when end_reg='1' else '0';

end Behave;