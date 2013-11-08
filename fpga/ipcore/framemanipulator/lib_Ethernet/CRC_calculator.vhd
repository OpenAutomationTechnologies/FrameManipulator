-- **********************************************************************
-- *                           CRC_calculator                           *
-- **********************************************************************
-- *                                                                    *
-- * CRC Calculator for Ethernet frames                                 *
-- *                                                                    *
-- *  important States of the FSM:                                      *
-- *   gFrBuffer: State of the new TX Data                              *
-- *   gCRC:      State for the CRC output                              *
-- *                                                                    *
-- * in:  iState    States from the FSM                                 *
-- *      iTXD      Data input for calculation                          *
-- * out: oTXD      CRC output                                          *
-- *      oCRCdone  Finish signal for the FSM                           *
-- *                                                                    *
-- *--------------------------------------------------------------------*
-- *                                                                    *
-- * 08.05.12 V1.0 created CRC_calculator  by Sebastian Muelhausen      *
-- *                                                                    *
-- **********************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CRC_calculator is
    port(
        clk, reset:         in std_logic;
        iReadBuff_Active:   in std_logic;
        iCRC_Active:        in std_logic;
        iCRCMani:           in std_logic;
        iTXD:               in std_logic_vector(1 downto 0);
        oTXD:               out std_logic_vector(1 downto 0)
    );
end CRC_calculator;

architecture Behave of CRC_calculator is

    --Cnter for reset after the 4 Bytes
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
            clk, reset:   in std_logic;
            iClear:       in std_logic;
            iEn   :       in std_logic;
            iStartValue:  in std_logic_vector(gCntWidth-1 downto 0);
            iEndValue:    in std_logic_vector(gCntWidth-1 downto 0);
            oQ:           out std_logic_vector(gCntWidth-1 downto 0);
            oOv:          out std_logic
        );
    end component;

    SIGNAL  Crc :   std_logic_vector(31 DOWNTO 0);
    SIGNAL  CrcDin: std_logic_vector( 1 DOWNTO 0);
    signal cnt_res: std_logic;
    signal CRCcnt:  std_logic_vector(3 downto 0);
begin


CrcDin <= iTXD(1 DOWNTO 0) when iCRCMani='0' else not iTXD(1 DOWNTO 0);


Calc: PROCESS ( clk, Crc, CrcDin )   IS
    VARIABLE    H : std_logic_vector(1 DOWNTO 0);
    BEGIN

    H(0) := Crc(31) XOR CrcDin(0);
    H(1) := Crc(30) XOR CrcDin(1);


    IF rising_edge( Clk )  THEN

        IF iCRC_Active = '1'    THEN   --output
            Crc <= Crc(29 DOWNTO 0) & "00";
            cnt_res<='0';

        elsif       iReadBuff_Active = '1' THEN  --calculation

            Crc( 0) <=                      H(1);
            Crc( 1) <=             H(0) XOR H(1);
            Crc( 2) <= Crc( 0) XOR H(0) XOR H(1);
            Crc( 3) <= Crc( 1) XOR H(0)         ;
            Crc( 4) <= Crc( 2)          XOR H(1);
            Crc( 5) <= Crc( 3) XOR H(0) XOR H(1);
            Crc( 6) <= Crc( 4) XOR H(0)         ;
            Crc( 7) <= Crc( 5)          XOR H(1);
            Crc( 8) <= Crc( 6) XOR H(0) XOR H(1);
            Crc( 9) <= Crc( 7) XOR H(0)         ;
            Crc(10) <= Crc( 8)          XOR H(1);
            Crc(11) <= Crc( 9) XOR H(0) XOR H(1);
            Crc(12) <= Crc(10) XOR H(0) XOR H(1);
            Crc(13) <= Crc(11) XOR H(0)         ;
            Crc(14) <= Crc(12)                  ;
            Crc(15) <= Crc(13)                  ;
            Crc(16) <= Crc(14)          XOR H(1);
            Crc(17) <= Crc(15) XOR H(0)         ;
            Crc(18) <= Crc(16)                  ;
            Crc(19) <= Crc(17)                  ;
            Crc(20) <= Crc(18)                  ;
            Crc(21) <= Crc(19)                  ;
            Crc(22) <= Crc(20)          XOR H(1);
            Crc(23) <= Crc(21) XOR H(0) XOR H(1);
            Crc(24) <= Crc(22) XOR H(0)         ;
            Crc(25) <= Crc(23)                  ;
            Crc(26) <= Crc(24)          XOR H(1);
            Crc(27) <= Crc(25) XOR H(0)         ;
            Crc(28) <= Crc(26)                  ;
            Crc(29) <= Crc(27)                  ;
            Crc(30) <= Crc(28)                  ;
            Crc(31) <= Crc(29)                  ;
            cnt_res<='1';

        ELSE                       --else FF
            Crc <= x"FFFFFFFF";

            cnt_res<='1';
        END IF;
    END IF;
END PROCESS Calc;

    cnt_end:Basic_Cnter
    generic map(gCntWidth=>4)
    port map(
        clk=>clk, reset=>reset,
        iClear=>cnt_res,iEn=>   '1',iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
        oQ=>CRCcnt,oOv=>open);


    oTXD <= NOT Crc(30) & NOT Crc(31);

end Behave;