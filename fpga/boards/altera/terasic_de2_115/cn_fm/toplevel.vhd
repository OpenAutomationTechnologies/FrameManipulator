-------------------------------------------------------------------------------
--! @file toplevel.vhd
--
--! @brief Toplevel of the INK DE2-115 design with Framemanipulator IP-core
--
--! @details This is the toplevel of the Framemanipulator design for the
--! INK DE2-115 Evaluation Board.
--
-------------------------------------------------------------------------------
--
--    (c) B&R, 2013
--
--    Redistribution and use in source and binary forms, with or without
--    modification, are permitted provided that the following conditions
--    are met:
--
--    1. Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--
--    2. Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
--    3. Neither the name of B&R nor the names of its
--       contributors may be used to endorse or promote products derived
--       from this software without prior written permission. For written
--       permission, please contact office@br-automation.com
--
--    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--    COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
--    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
--    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
--    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--    POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
--! use global library
use work.global.all;
--! use openmac package
use work.openmacPkg.all;

entity toplevel is
    port (
        -- 50 MHZ CLK IN
        EXT_CLK             : in    std_logic;
        -- PHY Interfaces
        PHY_GXCLK           : out   std_logic_vector(1 downto 0);
        PHY_RXCLK           : in    std_logic_vector(1 downto 0);
        PHY_RXER            : in    std_logic_vector(1 downto 0);
        PHY_RXDV            : in    std_logic_vector(1 downto 0);
        PHY_RXD             : in    std_logic_vector(7 downto 0);
        PHY_TXCLK           : in    std_logic_vector(1 downto 0);
        PHY_TXER            : out   std_logic_vector(1 downto 0);
        PHY_TXEN            : out   std_logic_vector(1 downto 0);
        PHY_TXD             : out   std_logic_vector(7 downto 0);
        PHY_MDIO            : inout std_logic_vector(1 downto 0);
        PHY_MDC             : out   std_logic_vector(1 downto 0);
        PHY_RESET_n         : out   std_logic_vector(1 downto 0);
        -- EPCS
        EPCS_DCLK           : out   std_logic;
        EPCS_SCE            : out   std_logic;
        EPCS_SDO            : out   std_logic;
        EPCS_DATA0          : in    std_logic;
        -- 2 MB SRAM
        SRAM_CE_n           : out   std_logic;
        SRAM_OE_n           : out   std_logic;
        SRAM_WE_n           : out   std_logic;
        SRAM_ADDR           : out   std_logic_vector(20 downto 1);
        SRAM_BE_n           : out   std_logic_vector(1 downto 0);
        SRAM_DQ             : inout std_logic_vector(15 downto 0);
        -- NODE_SWITCH
        NODE_SWITCH         : in    std_logic_vector(7 downto 0);
        -- KEY
        KEY                 : in    std_logic_vector(3 downto 0);
        -- LED
        LEDG                : out   std_logic_vector(7 downto 0);
        LEDR                : out   std_logic_vector(15 downto 0);
        -- BENCHMARK_OUT
        BENCHMARK           : out   std_logic_vector(7 downto 0);
        -- LCD
        LCD_ON              : out   std_logic;
        LCD_BLON            : out   std_logic;
        LCD_DQ              : inout std_logic_vector(7 downto 0);
        LCD_E               : out   std_logic;
        LCD_RS              : out   std_logic;
        LCD_RW              : out   std_logic
    );
end toplevel;

architecture rtl of toplevel is

    component cn_fm is
        port (
            clk25_clk                                       : in    std_logic                     := 'X';
            clk50_clk                                       : in    std_logic                     := 'X';
            reset_reset_n                                   : in    std_logic                     := 'X';
            clk100_clk                                      : in    std_logic                     := 'X';
            -- SRAM
            tri_state_0_tcm_address_out                     : out   std_logic_vector(20 downto 0);
            tri_state_0_tcm_byteenable_n_out                : out   std_logic_vector(1 downto 0);
            tri_state_0_tcm_read_n_out                      : out   std_logic;
            tri_state_0_tcm_write_n_out                     : out   std_logic;
            tri_state_0_tcm_data_out                        : inout std_logic_vector(15 downto 0) := (others => 'X');
            tri_state_0_tcm_chipselect_n_out                : out   std_logic;
            -- OPENMAC
            openmac_0_mii_txEnable                          : out   std_logic_vector(1 downto 0);
            openmac_0_mii_txData                            : out   std_logic_vector(7 downto 0);
            openmac_0_mii_txClk                             : in    std_logic_vector(1 downto 0)  := (others => 'X');
            openmac_0_mii_rxError                           : in    std_logic_vector(1 downto 0)  := (others => 'X');
            openmac_0_mii_rxDataValid                       : in    std_logic_vector(1 downto 0)  := (others => 'X');
            openmac_0_mii_rxData                            : in    std_logic_vector(7 downto 0)  := (others => 'X');
            openmac_0_mii_rxClk                             : in    std_logic_vector(1 downto 0)  := (others => 'X');
            openmac_0_smi_nPhyRst                           : out   std_logic_vector(1 downto 0);
            openmac_0_smi_clk                               : out   std_logic_vector(1 downto 0);
            openmac_0_smi_dio                               : inout std_logic_vector(1 downto 0)  := (others => 'X');
            -- BENCHMARK
            pcp_0_benchmark_pio_export                      : out   std_logic_vector(7 downto 0);
            -- EPCS
            epcs_flash_dclk                                 : out   std_logic;
            epcs_flash_sce                                  : out   std_logic;
            epcs_flash_sdo                                  : out   std_logic;
            epcs_flash_data0                                : in    std_logic                     := 'X';
                -- LCD
            lcd_data                                        : inout std_logic_vector(7 downto 0)  := (others => 'X');
            lcd_E                                           : out   std_logic;
            lcd_RS                                          : out   std_logic;
            lcd_RW                                          : out   std_logic;
            -- NODE SWITCH
            node_switch_pio_export                          : in    std_logic_vector(7 downto 0)  := (others => 'X');
            -- STATUS ERROR LED
            status_led_pio_export                           : out   std_logic_vector(1 downto 0);
            -- HEX
            hex_pio_export                                  : out   std_logic_vector(31 downto 0);
            -- LEDR
            ledr_pio_export                                 : out   std_logic_vector(15 downto 0);
            -- KEY
            key_pio_export                                  : in    std_logic_vector(3 downto 0)  := (others => 'X');
            -- FRAMEMANIPULATOR
            framemanipulator_0_stream_to_dut_iRXDV          : in    std_logic                     := 'X';             -- iRXDV
            framemanipulator_0_stream_to_dut_iRXD           : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- iRXD
            framemanipulator_0_stream_to_dut_oTXData        : out   std_logic_vector(1 downto 0);                     -- oTXData
            framemanipulator_0_stream_to_dut_oTXDV          : out   std_logic;                                        -- oTXDV
            framemanipulator_0_led_export                   : out   std_logic_vector(1 downto 0)                      -- export
          );
    end component cn_fm;

    -- PLL component
    component pll
        port (
            inclk0  : in std_logic;
            c0      : out std_logic;
            c1      : out std_logic;
            c2      : out std_logic;
            c3      : out std_logic;
            locked  : out std_logic
        );
    end component;

    component convRmiiToMii
        port (
            --! Reset
            iRst        : in    std_logic;
            --! RMII Clock
            iClk        : in    std_logic;
            --! RMII transmit path
            iRmiiTx     : in    tRmiiPath;
            --! RMII receive path
            oRmiiRx     : out   tRmiiPath;
            --! MII receive clock
            iMiiRxClk   : in    std_logic;
            --! MII receive path
            iMiiRx      : in    tMiiPath;
            --! MII receive error
            iMiiRxError : in    std_logic;
            --! MII transmit clock
            iMiiTxClk   : in    std_logic;
            --! MII transmit path
            oMiiTx      : out   tMiiPath
        );
    end component;


    --pll
    signal clk25            : std_logic;
    signal clk50            : std_logic;
    signal clk100           : std_logic;
    signal pllLocked        : std_logic;
    signal sramAddr         : std_logic_vector(SRAM_ADDR'high downto 0);
    signal plk_status_error : std_logic_vector(1 downto 0);

    signal reset            : std_logic;


    -- connection Framemanipulator
    signal openMac_tx       : tMiiPathArray(1 downto 0);    --data from PL-Slave MII
    signal fmRx             : tRmiiPath;                    --data from PL-Slave RMII
    signal fmTx             : tRmiiPath;                    --data from FM RMII
    signal mani_tx          : tMiiPath;                     --data from FM MII
    signal fmLed            : std_logic_vector(1 downto 0); --FM status leds


    -- temporary signals
    signal openMac_txEnable     : std_logic_vector(1 downto 0);
    signal openMac_txData       : std_logic_vector(2*cMiiDataWidth-1 downto 0);

begin

    reset       <= not pllLocked;

    SRAM_ADDR   <= sramAddr(SRAM_ADDR'range);

    PHY_GXCLK   <= (others => '0');
    PHY_TXER    <= (others => '0');

    LCD_ON      <= '1';
    LCD_BLON    <= '1';

    LEDG        <= fmLed & "0000" & plk_status_error;



    openMac_tx(0).enable    <= openMac_txEnable(0);
    openMac_tx(1).enable    <= openMac_txEnable(1);

    openMac_tx(0).data      <= openMac_txData(cMiiDataWidth-1 downto 0);
    openMac_tx(1).data      <= openMac_txData(2*cMiiDataWidth-1 downto cMiiDataWidth);


    -- Connect Tx-Phy output
    PHY_TXD     <=  mani_tx.data    &   openMac_tx(0).data;
    PHY_TXEN    <=  mani_tx.enable  &   openMac_tx(0).enable;


    inst : component cn_fm
        port map (
            clk25_clk                                       => clk25,
            clk50_clk                                       => clk50,
            clk100_clk                                      => clk100,
            reset_reset_n                                   => pllLocked,

            openmac_0_mii_txEnable                          => openMac_txEnable,
            openmac_0_mii_txData                            => openMac_txData,
            openmac_0_mii_txClk                             => PHY_TXCLK,
            openmac_0_mii_rxError                           => PHY_RXER,
            openmac_0_mii_rxDataValid                       => PHY_RXDV,
            openmac_0_mii_rxData                            => PHY_RXD,
            openmac_0_mii_rxClk                             => PHY_RXCLK,
            openmac_0_smi_nPhyRst                           => PHY_RESET_n,
            openmac_0_smi_clk                               => PHY_MDC,
            openmac_0_smi_dio                               => PHY_MDIO,

            tri_state_0_tcm_address_out                     => sramAddr,
            tri_state_0_tcm_read_n_out                      => SRAM_OE_n,
            tri_state_0_tcm_byteenable_n_out                => SRAM_BE_n,
            tri_state_0_tcm_write_n_out                     => SRAM_WE_n,
            tri_state_0_tcm_data_out                        => SRAM_DQ,
            tri_state_0_tcm_chipselect_n_out                => SRAM_CE_n,

            pcp_0_benchmark_pio_export                      => BENCHMARK,

            epcs_flash_dclk                                 => EPCS_DCLK,
            epcs_flash_sce                                  => EPCS_SCE,
            epcs_flash_sdo                                  => EPCS_SDO,
            epcs_flash_data0                                => EPCS_DATA0,

            node_switch_pio_export                          => NODE_SWITCH,
            status_led_pio_export                           => plk_status_error,

            lcd_data                                        => LCD_DQ,
            lcd_E                                           => LCD_E,
            lcd_RS                                          => LCD_RS,
            lcd_RW                                          => LCD_RW,

            hex_pio_export                                  => open,
            ledr_pio_export                                 => LEDR,
            key_pio_export                                  => KEY,

            framemanipulator_0_stream_to_dut_iRXDV          => fmRx.enable,
            framemanipulator_0_stream_to_dut_iRXD           => fmRx.data,
            framemanipulator_0_stream_to_dut_oTXData        => fmTx.data,
            framemanipulator_0_stream_to_dut_oTXDV          => fmTx.enable,
            framemanipulator_0_led_export                   => fmLed
        );

    -- Pll Instance
    pllInst : pll
        port map (
            inclk0  => EXT_CLK,
            c0      => clk50,
            c1      => clk100,
            c2      => clk25,
            c3      => open,
            locked  => pllLocked
        );


    -- Rmii/Mii converting
    convert : convRmiiToMii
        port map (
            iRst        => reset,
            iClk        => clk50,
            iRmiiTx     => fmTx,            --Data from FM RMII
            oRmiiRx     => fmRx,            --Data from PL-Slave RMII
            iMiiRxClk   => PHY_TXCLK(1),    --converting with the tx clock of phy 1
            iMiiRx      => openMac_tx(1),   --Data from PL-Slave MII
            iMiiRxError => '0',
            iMiiTxClk   => PHY_TXCLK(1),
            oMiiTx      => mani_tx          --Data from FM MII
        );



end rtl;
