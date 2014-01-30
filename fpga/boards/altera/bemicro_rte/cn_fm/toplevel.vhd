-------------------------------------------------------------------------------
--! @file toplevel.vhd
--
--! @brief Toplevel of the BeMicro RTE Design with Framemanipulator IP-core
--
--! @details This is the toplevel of the Framemanipulator design for the
--! BeMicro RTE.
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

entity toplevel is
    port (
        -- 50 MHZ CLK IN
        EXT_CLK             : in   std_logic;
        -- PHY Interface
        PHY_RXER            : in       std_logic_vector(1 downto 0);
        PHY_RXDV            : in       std_logic_vector(1 downto 0);
        PHY_RXD             : in       std_logic_vector(3 downto 0);
        PHY_TXEN            : out      std_logic_vector(1 downto 0);
        PHY_TXD             : out      std_logic_vector(3 downto 0);
        PHY_MDIO            : inout    std_logic_vector(1 downto 0);
        PHY_MDC             : out      std_logic_vector(1 downto 0);
        PHY_RESET_n         : out      std_logic_vector(1 downto 0);
        -- EPCS
        EPCS_DCLK           : out  std_logic;
        EPCS_SCE            : out  std_logic;
        EPCS_SDO            : out  std_logic;
        EPCS_DATA0          : in   std_logic;
        -- 512 kB SRAM
        SRAM_CE_n           : out      std_logic;
        SRAM_OE_n           : out      std_logic;
        SRAM_WE_n           : out      std_logic;
        SRAM_ADDR           : out      std_logic_vector(18 downto 1);
        SRAM_BE_n           : out      std_logic_vector(1 downto 0);
        SRAM_DQ             : inout    std_logic_vector(15 downto 0);
        -- NODE_SWITCH
        NODE_SWITCH         : in    std_logic_vector(7 downto 0);   --low active
        -- LED
        LED                 : out   std_logic_vector(7 downto 0)    --low active
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
            tri_state_0_out_tcm_address_out                 : out   std_logic_vector(18 downto 0);
            tri_state_0_out_tcm_byteenable_n_out            : out   std_logic_vector(1 downto 0);
            tri_state_0_out_tcm_read_n_out                  : out   std_logic;
            tri_state_0_out_tcm_write_n_out                 : out   std_logic;
            tri_state_0_out_tcm_data_out                    : inout std_logic_vector(15 downto 0) := (others => 'X');
            tri_state_0_out_tcm_chipselect_n_out            : out   std_logic;
            -- PHY0
            openmac_0_smi_clk                               : out   std_logic_vector(1 downto 0);                     -- SMIClk
            openmac_0_smi_dio                               : inout std_logic_vector(1 downto 0)  := (others => 'X'); -- SMIDat
            openmac_0_smi_nPhyRst                           : out   std_logic_vector(1 downto 0);                     -- Rst_n
            openmac_0_rmii_rxData                           : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- RxDat
            openmac_0_rmii_rxDataValid                      : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- RxDv
            openmac_0_rmii_txData                           : out   std_logic_vector(3 downto 0);                     -- TxDat
            openmac_0_rmii_txEnable                         : out   std_logic_vector(1 downto 0);                     -- TxEn
            openmac_0_rmii_rxError                          : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- RxErr
            -- BENCHMARK
            pcp_0_benchmark_pio_export                      : out   std_logic_vector(7 downto 0);
            -- EPCS
            epcs_flash_dclk                                 : out   std_logic;
            epcs_flash_sce                                  : out   std_logic;
            epcs_flash_sdo                                  : out   std_logic;
            epcs_flash_data0                                : in    std_logic                     := 'X';
            -- NODE SWITCH
            node_switch_pio_export                          : in    std_logic_vector(7 downto 0)  := (others => 'X');
            -- STATUS ERROR LED
            status_led_pio_export                           : out   std_logic_vector(1 downto 0);
            -- LEDG
            ledg_pio_export                                 : out   std_logic_vector(7 downto 0);
            -- FRAMEMANIPULATOR
            framemanipulator_0_stream_to_dut_iRXDV          : in    std_logic                     := 'X';             -- iRXDV
            framemanipulator_0_stream_to_dut_iRXD           : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- iRXD
            framemanipulator_0_stream_to_dut_oTXData        : out   std_logic_vector(1 downto 0);                     -- oTXData
            framemanipulator_0_stream_to_dut_oTXDV          : out   std_logic;                                        -- oTXDV
            framemanipulator_0_led_export                   : out   std_logic_vector(1 downto 0)                      -- export
          );
    end component;



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

    type tFm is record
        txEn    : std_logic;
        txD     : std_logic_vector(1 downto 0);
        rxEn    : std_logic;
        rxD     : std_logic_vector(1 downto 0);
        led     : std_logic_vector(1 downto 0);
    end record;

    --pll
    signal clk25            : std_logic;
    signal clk50            : std_logic;
    signal clk100           : std_logic;
    signal pllLocked        : std_logic;

    signal sramAddr         : std_logic_vector(SRAM_ADDR'high downto 0);
    signal plk_status_error : std_logic_vector(1 downto 0);
    signal LEDG             : std_logic_vector(7 downto 0);                 --high active
    signal nodeSwitch       : std_logic_vector(NODE_SWITCH'high downto 0);  --high active

    -- connection Framemanipulator
    signal openMac_txEnable : std_logic_vector(1 downto 0);
    signal openMac_txData   : std_logic_vector(3 downto 0);
    signal fm               : tFm;
    signal Phy1_txEnable    : std_logic;
    signal Phy1_txData      : std_logic_vector(1 downto 0);

begin
    SRAM_ADDR       <= sramAddr(SRAM_ADDR'range);

    LED         <=  not (fm.led & "0000" & plk_status_error);       --LED output is low acitve

    nodeSwitch  <=  not NODE_SWITCH;    --NODE_SWITCH is low acitve, nodeSwitch high

    inst : component cn_fm
        port map (
            clk25_clk                                       => clk25,
            clk50_clk                                       => clk50,
            clk100_clk                                      => clk100,
            reset_reset_n                                   => pllLocked,

            openmac_0_rmii_txEnable                         => openMac_txEnable,
            openmac_0_rmii_txData                           => openMac_txData,
            openmac_0_rmii_rxDataValid                      => PHY_RXDV,
            openmac_0_rmii_rxError                          => PHY_RXER,
            openmac_0_rmii_rxData                           => PHY_RXD,
            openmac_0_smi_clk                               => PHY_MDC,
            openmac_0_smi_dio                               => PHY_MDIO,
            openmac_0_smi_nPhyRst                           => PHY_RESET_n,

            tri_state_0_out_tcm_address_out                 => sramAddr,
            tri_state_0_out_tcm_read_n_out                  => SRAM_OE_n,
            tri_state_0_out_tcm_byteenable_n_out            => SRAM_BE_n,
            tri_state_0_out_tcm_write_n_out                 => SRAM_WE_n,
            tri_state_0_out_tcm_data_out                    => SRAM_DQ,
            tri_state_0_out_tcm_chipselect_n_out            => SRAM_CE_n,

            pcp_0_benchmark_pio_export                      => open,

            epcs_flash_dclk                                 => EPCS_DCLK,
            epcs_flash_sce                                  => EPCS_SCE,
            epcs_flash_sdo                                  => EPCS_SDO,
            epcs_flash_data0                                => EPCS_DATA0,

            node_switch_pio_export                          => nodeSwitch,
            status_led_pio_export                           => plk_status_error,
            ledg_pio_export                                 => LEDG,

            framemanipulator_0_stream_to_dut_iRXDV          => fm.rxEn,
            framemanipulator_0_stream_to_dut_iRXD           => fm.rxD,
            framemanipulator_0_stream_to_dut_oTXData        => fm.txD,
            framemanipulator_0_stream_to_dut_oTXDV          => fm.txEn,
            framemanipulator_0_led_export                   => fm.led
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

    -- Connect Phy1 to Framemanipulator
    fm.rxD      <=  openMac_txData(3 downto 2);
    fm.rxEn     <=  openMac_txEnable(1);

    -- Output-Framemanipulator to FF with negative edge
    process(clk100)
    begin
        if falling_edge(clk100) then
            if pllLocked='0' then
                Phy1_txData     <=  "00";
                Phy1_txEnable   <=  '0';
            else
                Phy1_txData     <=  fm.txD;
                Phy1_txEnable   <=  fm.txEn;
            end if;
        end if;
    end process;

    -- Connect Tx-Phy output
    PHY_TXD     <=  Phy1_txData     &   openMac_txData(1 downto 0);
    PHY_TXEN    <=  Phy1_txEnable   &   openMac_txEnable(0);

end rtl;
