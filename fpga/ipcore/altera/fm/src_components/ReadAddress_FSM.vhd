
-- ******************************************************************************************
-- *                                ReadAddress_FSM                                         *
-- ******************************************************************************************
-- *                                                                                        *
-- * FSM for reading the Fifo and storing the addresses from the fifo. It starts a new frame*
-- * when the Frame-Creator and new frame-data addresses are ready.                         *
-- *                                                                                        *
-- * States:                                                                                *
-- *    sIdle:                  Wait for ready-signal from the Frame-Creator                *
-- *    sWait_new_frame_data:   Wait for new frame data/start address                       *
-- *    sStart_frame:           Stores start address                                        *
-- *    sWait_end_addr:         Wait for valid end position                                 *
-- *    sRd_end_addr:           Stores end address                                          *
-- *                                                                                        *
-- *----------------------------------------------------------------------------------------*
-- *                                                                                        *
-- * 09.08.12 V1.0      ReadAddress_FSM                         by Sebastian Muelhausen     *
-- *                                                                                        *
-- ******************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ReadAddress_FSM is
        generic(
                gAddrDataWidth:natural:=11;
                gBuffBitWidth:natural:=16
        );
        port(
            clk, reset:     in std_logic;
            --control signals
            iNextFrame:     in std_logic;   --frame-creator is ready for new data
            iDataReady:     in std_logic;   --address data is ready
            oStart:         out std_logic;  --start new frame
            --fifo signals
            oRd:            out std_logic;                                  --read fifo
            iFifoData:      in std_logic_vector(gBuffBitWidth-1 downto 0);  --fifo data
            --new frame positions
            oDataOutStart:  out std_logic_vector(gAddrDataWidth-1 downto 0);--start address of new frame
            oDataOutEnd:    out std_logic_vector(gAddrDataWidth-1 downto 0) --end address of new frame
        );
end ReadAddress_FSM;


architecture two_seg_arch of ReadAddress_FSM is

    --states
    type mc_state_type is
        (sIdle,sWait_new_frame_data,sStart_frame,sWait_end_addr,sRd_end_addr);

    signal state_reg:   mc_state_type;
    signal state_next:  mc_state_type;

    --register: start address of new frame
    signal Next_DataOutStart:   std_logic_vector(gAddrDataWidth-1 downto 0);
    signal Reg_DataOutStart:    std_logic_vector(gAddrDataWidth-1 downto 0);

    --register: end address of new frame
    signal Next_DataOutEnd: std_logic_vector(gAddrDataWidth-1 downto 0);
    signal Reg_DataOutEnd:  std_logic_vector(gAddrDataWidth-1 downto 0);

begin

    --register
    process(clk)
    begin
        if clk='1' and clk'event then
            if reset = '1' then
                Reg_DataOutEnd<=(others=>'0');
                Reg_DataOutStart<=(others=>'0');
                state_reg<=sIdle;

            else
                Reg_DataOutEnd<=Next_DataOutEnd;
                Reg_DataOutStart<=Next_DataOutStart;
                state_reg<=state_next;

            end if;
        end if;
    end process;

    --next state logic
    process(state_reg,iDataReady,iNextFrame)
    begin
       case state_reg is

            when sIdle=>
                if iNextFrame='1' then                  --if Frame-Creator is ready
                    state_next<=sWait_new_frame_data;   --check of new frame data

                else
                    state_next<=sIdle;

                end if;

            when sWait_new_frame_data=>
                if iDataReady='1' then          --if new data is ready
                    state_next<=sStart_frame;   --start a new frame

                else
                    state_next<=sWait_new_frame_data;

                end if;

            when sStart_frame=>
                state_next<=sWait_end_addr;     --goto: wait for end address

            when sWait_end_addr=>
                if iDataReady='1' then          --if data is ready
                    state_next<=sRd_end_addr;   --read end address

                else
                    state_next<=sWait_end_addr;

                end if;

            when sRd_end_addr=>
                state_next<=sIdle;              --goto: idle

            when others=>
                state_next<= sIdle;

        end case;
    end process;

    --Moore output
    process(state_reg,Reg_DataOutStart,Reg_DataOutEnd,iFifoData)
    begin
    --store addresses
    Next_DataOutStart   <=Reg_DataOutStart;
    Next_DataOutEnd     <=Reg_DataOutEnd;

    oDataOutStart<=Reg_DataOutStart;
    oDataOutEnd <=Reg_DataOutEnd;
    oRd         <='0';
    oStart      <='0';

        case state_reg is
            when sIdle=>

            when sWait_new_frame_data=>

            when sStart_frame=>                 --start new frame
                oRd<='1';                       --read fifo
                oStart<='1';                    --set start signal
                oDataOutStart   <=iFifoData;    --store start address
                Next_DataOutStart<=iFifoData;

            when sWait_end_addr=>

            when sRd_end_addr=>                 --read end address
                oRd<='1';                       --read fifo
                oDataOutEnd     <=iFifoData;    --store end address
                Next_DataOutEnd <=iFifoData;

            when others =>

        end case;

    end process;

end two_seg_arch;