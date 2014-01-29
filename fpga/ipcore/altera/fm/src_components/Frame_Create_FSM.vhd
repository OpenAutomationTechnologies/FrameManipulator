-- ******************************************************************************************
-- *                                   Frame_Create_FSM V2.0                                *
-- ******************************************************************************************
-- *                                                                                        *
-- * The FSM for creating Ethernet frames and the TXDV signal                               *
-- *                                                                                        *
-- * States:                                                                                *
-- *  sIdle:        ready for the next frame-data                                           *
-- *  sPreamble:    starts the Preamble_Generator                                           *
-- *  sPre_read:    pre-start of Read Logic to compensate delay                             *
-- *  sRead:        loads and converts frame payload                                        *
-- *  sCrc:         starts CRC_calculator                                                   *
-- *  sWait_IPG:    waits a few cycles to keep the Inter Packet Gap of 960ns                *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 08.05.12 V1.0      created Frame_starter                   by Sebastian Muelhausen     *
-- * 12.06.12 V1.1      updated FSM for Frames with Size=0      by Sebastian Muelhausen     *
-- * 09.08.12 V2.0      redesign with sWait_IPG                 by Sebastian Muelhausen     *
-- * 25.11.13 V2.1      Updated for safety manipulations        by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.global.all;

entity Frame_Create_FSM is
    generic(gSafetyPackSelCntWidth  : natural :=8);
    port(
        clk, reset:         in std_logic;

        iFrameStart:        in std_logic;                       --start of a new frame
        iReadBuffDone:      in std_logic;                       --buffer reading has reched the last position

        iPacketExchangeEn   : in std_logic;                                     --Start of the exchange of the safety packet
        iPacketStart        : in std_logic_vector(cByteLength-1 downto 0);      --Start of safety packet
        iPacketSize         : in std_logic_vector(cByteLength-1 downto 0);      --Size of safety packet
        oExchangeData       : out std_logic;                                    --Exchanging safety data

        oPreamble_Active:   out std_logic;                      --activate preamble_generator
        oPreReadBuff:       out std_logic;                      --activate pre-reading
        oReadBuff_Active:   out std_logic;                      --activate reading from data-buffer
        oCRC_Active:        out std_logic;                      --activate CRC calculation

        oSelectTX:          out std_logic_vector(1 downto 0);   --selection beween the preamble, payload and crc
        oNextFrame:         out std_logic;                      --FSM is ready for new data
        oTXDV:              out std_logic                       --TX Data Valid
     );
end Frame_Create_FSM;

architecture Behave of Frame_Create_FSM is

    --counter for the timing
    component Basic_Cnter
        generic(gCntWidth: natural := 2);
        port(
            clk, reset:   in std_logic;
            iClear:       in std_logic;
            iEn:          in std_logic;
            iStartValue:  in std_logic_vector(gCntWidth-1 downto 0);
            iEndValue:    in std_logic_vector(gCntWidth-1 downto 0);
            oQ:           out std_logic_vector(gCntWidth-1 downto 0);
            oOv:          out std_logic
        );
    end component;

    constant cCntWidth:natural:=6;

    --timings:
    constant cPramble_Time:     natural:=31;    --8Byte => 8Byte*8Bit/2Width => 32
    constant cPre_Read_Time:    natural:=5;     --Forerun of the reading logic of 5 cycles
    constant cCRC_Time:         natural:=15;    --4Byte => 4Byte*8Bit/2Width => 16
    constant cIPG_Time:         natural:=43;    --Whole delay of 960ns => here 880ns + process time



    --States
    type mc_state_type is
        (sIdle,sPreamble,sPre_read,sRead,sSafetyRead,sCrc,sWait_IPG);

    signal state_reg:   mc_state_type;
    signal state_next:  mc_state_type;

    --counter variables
    signal ClearCnt:    std_logic;                                              --Clear of timing counter
    signal ClearPCnt:   std_logic;                                              --Clear of packet counter
    signal Cnt:         std_logic_vector(cCntWidth-1 downto 0);                 --Counter for timings
    signal PCnt:        std_logic_vector(gSafetyPackSelCntWidth-1 downto 0);    --Byte counter for packet exchange
    signal PCntPre:     std_logic;                                              --Prescaler for packet counter

begin

    --counter for timings
    FSM_Cnter:Basic_Cnter
    generic map(gCntWidth=>cCntWidth)
    port map(
            clk=>clk,reset=>reset,
            iClear=>ClearCnt,iEn=>'1',iStartValue=>(others=>'0'),iEndValue=>(others=>'1'),
            oQ=>Cnt,oOv=>open);


    --prescaler for safety counter
    Packet_Prescaler:Basic_Cnter
    generic map(gCntWidth=>2)
    port map(
            clk=>clk,reset=>reset,
            iClear=>ClearPCnt,iEn=>'1',iStartValue=>"11",iEndValue=>(others=>'1'),
            oQ=>open,oOv=>PCntPre);                 --starts with Ov to eliminate register delay

    --safety counter for packet exchange
    Packet_Cnter:Basic_Cnter
    generic map(gCntWidth   => gSafetyPackSelCntWidth)
    port map(
            clk=>clk,reset=>reset,
            iClear=>ClearPCnt,iEn=>PCntPre,iStartValue=>(0=>'1',others=>'0'),iEndValue=>(others=>'1'),
            oQ=>PCnt,oOv=>open);                    --starts at 1


    --state register
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                state_reg <= sIdle;
            else
                state_reg <= state_next;
            end if;
        end if;
    end process;

    --next-state logic
    process(state_reg, iFrameStart, iReadBuffDone,Cnt,PCnt,iPacketExchangeEn,iPacketStart,iPacketSize)
    begin
        case state_reg is

            when sIdle =>
                if iFrameStart='1' then
                    state_next<=sPreamble;  --start of preamble after start

                else
                    state_next<=sIdle;

                end if;

            when sPreamble =>
                if Cnt=std_logic_vector(to_unsigned(cPramble_Time-cPre_Read_Time,Cnt'length)) then
                    state_next<=sPre_read;  --pre-read after constant timing

                else
                    state_next<=sPreamble;

                end if;

            when sPre_read =>
                if iReadBuffDone='1' then
                    state_next<=sCrc;   --goto CRC, when there's no payload (e.g. frame cut to size of 0)

                elsif Cnt=std_logic_vector(to_unsigned(cPramble_Time,Cnt'length)) then
                    state_next<=sRead;  --read after timing

                else
                    state_next<=sPre_read;

                end if;

            when sRead =>
                if iReadBuffDone='1' then
                    state_next<=sCrc;   --start CRC after reaching the end

                elsif (iPacketExchangeEn='1' and unsigned(PCnt)=unsigned(iPacketStart)) then
                    state_next<=sSafetyRead;

                else
                    state_next<=sRead;

                end if;

            when sSafetyRead =>
                if unsigned(PCnt)=unsigned(iPacketStart)+unsigned(iPacketSize) then
                    state_next<=sRead;

                else
                    state_next<=sSafetyRead;

                end if;

            when sCrc =>
                if Cnt=std_logic_vector(to_unsigned(cCRC_Time,Cnt'length)) then
                    state_next<=sWait_IPG;  --goto waiting after CRC has finished

                else
                    state_next<=sCrc;

                end if;

            when sWait_IPG =>
                if Cnt>std_logic_vector(to_unsigned(cCRC_Time+cIPG_Time,Cnt'length)) and iFrameStart='0' then
                    state_next<=sIdle;  --goto idle after waiting for the IPG

                else
                    state_next<=sWait_IPG;

                end if;

        end case;
    end process;


    --Moore output
    process(state_reg)
    begin

        oPreamble_Active<='0';
        oReadBuff_Active<='0';
        oPreReadBuff<='0';

        oNextFrame<='0';

        ClearCnt    <='0';
        ClearPCnt   <='1';              --always inactive

        case state_reg is
            when sIdle=>                --IDLE:
                ClearCnt        <= '1'; --deaktivates Cnter
                oNextFrame      <= '1'; --FSM is ready for new data

            when sPreamble=>            --PREAMBLE
                oPreamble_Active<= '1'; --preamble is active

            when sPre_read=>            --PRE-READ
                oPreamble_Active<= '1'; --preamble is active
                oPreReadBuff    <= '1'; --Read-Logic is active, too

            when sRead=>                --READ
                ClearCnt        <= '1'; --Cnter is inactive
                ClearPCnt       <= '0'; --Packet Cnter is active
                oReadBuff_Active<= '1'; --Read-Logic is active

            when sSafetyRead=>          --READ
                ClearCnt        <= '1'; --Cnter is inactive
                ClearPCnt       <= '0'; --Packet Cnter is active
                oReadBuff_Active<= '1'; --Read-Logic is active

            when sCrc=>                 --CRC (is Meely to compensate one cycle of delay)
                null;

            when sWait_IPG=>            --WAIT_IPG (doesn't need output)
                null;

        end case;

    end process;


    --Meely Output
    oCRC_Active<='1' when state_next=sCrc  else '0';    --CRC start


    --Select TX and TXDV
    process(state_reg,state_next)
    begin
        oSelectTX       <="00";
        oTXDV           <='0';
        oExchangeData   <='0';

        case state_reg is
            when sIdle=>

            when sPreamble=>
                oSelectTX   <= "01";
                oTXDV       <= '1';

            when sPre_read=>
                oSelectTX   <= "01";
                oTXDV       <= '1';

            when sRead=>
                oSelectTX   <= "11";
                oTXDV       <= '1';

            when sSafetyRead=>
                oSelectTX       <= "11";
                oTXDV           <= '1';
                oExchangeData   <= '1';

            when sCrc=>
                --below the case with state_next to save one cycle
                null;

            when sWait_IPG=>
                null;

        end case;

        if state_next=sCrc then
            oSelectTX<="10";
            oTXDV<='1';
        end if;

    end process;

end Behave;