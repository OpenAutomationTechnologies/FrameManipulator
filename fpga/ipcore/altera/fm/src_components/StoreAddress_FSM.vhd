
-- ******************************************************************************************
-- *                                StoreAddress_FSM                                        *
-- ******************************************************************************************
-- *                                                                                        *
-- * FSM for storing the start- and end-position of the frame-data into the fifo. The delay *
-- * timestamp is connected to the start-address and the CRC-distortion flag to the end-    *
-- * address.                                                                               *
-- * The Frame-Receiver receives also a new start address for the next frame.               *
-- *                                                                                        *
-- * States:                                                                                *
-- *    sIdle:      Wait for new incoming frame                                             *
-- *    sWrStart:   Write start address + delay-timestamp to the fifo                       *
-- *    sWait_end:  Wait for the valid end address/end of the frame                         *
-- *    sWrEnd:     Write end position + CRC-distortion flag                                *
-- *    sWait_stop: Wait until the start signal is zero                                     *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      StoreAddress_FSM                        by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity StoreAddress_FSM is
        generic(
                gAddrDataWidth: natural:=11;
                gSize_Time:     natural:=40;
                gFiFoBitWidth:  natural:=52
        );
        port(
            clk, reset:         in std_logic;
            --control signals
            iStartStorage:      in std_logic;                                   --start storing positions
            iFrameEnd:          in std_logic;                                   --end position is valid
            iDataInEndAddr:     in std_logic_vector(gAddrDataWidth-1 downto 0); --end position of the current frame
            oDataInStartAddr:   out std_logic_vector(gAddrDataWidth-1 downto 0);--new start position of the next frame
            --tasks
            iCRCManEn:          in std_logic;                                   --task: crc distortion
            iDelayTime:         in std_logic_vector(gSize_Time-1 downto 0);     --delay timestamp
            --storing data
            oWr:                out std_logic;                                  --write Fifo
            oFiFoData :         out std_logic_vector(gFiFoBitWidth-1 downto 0)  --Fifo data
        );
end StoreAddress_FSM;



architecture two_seg_arch of StoreAddress_FSM is

    --states
    type mc_state_type is
        (sIdle,sWrStart,sWait_end,sWrEnd,sWait_stop);

    signal state_reg:   mc_state_type;
    signal state_next:  mc_state_type;

    --start position register
    signal Next_DataInStartAddr:    std_logic_vector(gAddrDataWidth-1 downto 0);
    signal Reg_DataInStartAddr:     std_logic_vector(gAddrDataWidth-1 downto 0);

begin


    --register
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                Reg_DataInStartAddr<=(others=>'0');
                state_reg<=sIdle;

            else
                Reg_DataInStartAddr<=Next_DataInStartAddr;
                state_reg<=state_next;

            end if;
        end if;
    end process;

    --next state logic
    process(state_reg,iStartStorage,iFrameEnd)
    begin
       case state_reg is

            when sIdle=>
                if iStartStorage='1' then
                    state_next<=sWrStart;       --when start, then write start position

                else
                    state_next<=sIdle;

                end if;

            when sWrStart=>
                state_next<=sWait_end;      --goto wait

            when sWait_end=>
                if iFrameEnd='1' then
                    state_next<=sWrEnd;         --when end-address is valid, then write end position

                else
                    state_next<=sWait_end;

                end if;

            when sWrEnd=>
                state_next<=sWait_stop;         --goto end

            when sWait_stop=>
                if iStartStorage='0' then
                    state_next<=sIdle;         --goto idle, when start signal is 0

                else
                    state_next<=sWait_stop;

                end if;

            when others=>
                state_next<= sIdle;

        end case;
    end process;



    --Moore output
    process(state_reg,Reg_DataInStartAddr,iDelayTime,iCRCManEn)
    begin
        --store and output of new start position
        Next_DataInStartAddr    <=Reg_DataInStartAddr;
        oDataInStartAddr        <=Reg_DataInStartAddr;

        oWr<='0';
        oFiFoData<=(others=>'0');

        case state_reg is
            when sIdle=>

            when sWrStart=>     --writeEnable and fifo-data=delay-timestamp+start position
                oWr<='1';
                oFiFoData<= iDelayTime & Reg_DataInStartAddr;

            when sWait_end=>

            when sWrEnd=>       --writeEnable and fifo-data= CRC Task Flag + end position
                oWr<='1';
                oFiFoData<=(gFiFoBitWidth-1 downto gAddrDataWidth+1 =>'0')& iCRCManEn & iDataInEndAddr;  --end Address
                Next_DataInStartAddr    <=iDataInEndAddr;
                                --start position of the next frame is current end position

            when sWait_stop=>

            when others =>

        end case;

    end process;



end two_seg_arch;