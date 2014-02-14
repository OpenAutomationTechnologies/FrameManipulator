# -----------------------------------------------------------------------------
# FrameManipulator_hw.tcl
# -----------------------------------------------------------------------------
#
#    (c) B&R, 2014
#
#    Redistribution and use in source and binary forms, with or without
#    modification, are permitted provided that the following conditions
#    are met:
#
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#    3. Neither the name of B&R nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without prior written permission. For written
#       permission, please contact office@br-automation.com
#
#    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
#    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#    COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
#    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#    POSSIBILITY OF SUCH DAMAGE.
#
# -----------------------------------------------------------------------------


# +-----------------------------------
# | request TCL package from ACDS 11.0
# |
package require -exact sopc 11.0
# |
# +-----------------------------------

# +-----------------------------------
# | module FrameManipulator
# |
set_module_property NAME FrameManipulator
set_module_property VERSION 0.2.0
set_module_property INTERNAL false
set_module_property AUTHOR "B&R"
set_module_property DISPLAY_NAME FrameManipulator
set_module_property TOP_LEVEL_HDL_FILE "../fm/src/FrameManipulator.vhd"
set_module_property TOP_LEVEL_HDL_MODULE FrameManipulator
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property ANALYZE_HDL false
set_module_property ICON_PATH "img/br.png"
# |
# +-----------------------------------

# +-----------------------------------
# | files
# |
add_file "../fm/src/framemanipulatorPkg.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/FrameManipulator.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/adder_2121.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/Basic_Cnter.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/Basic_DownCnter.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/From_To_Cnt_Filter.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/Mux1D.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/Mux2D.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Basics/shift_right_register.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/CRC_calculator.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/end_of_frame_detection.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/Preamble_check.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/Preamble_Generator.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/sync_newData.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Ethernet/sync_RxFrame.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/DpramAdjustable.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/DpramFix.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/FiFo_File.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/FiFo_Sync_Ctrl.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/FiFo_top.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/read_logic.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/lib_Memory/write_logic.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Address_Manager.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Byte_to_TXData.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Control_Register.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Delay_FSM.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Delay_Handler.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Frame_collector.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Frame_Create_FSM.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Manipulation_Manager.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Packet_MemCnter.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Packet_Memory.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Packet_StartAddrMem.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/PacketControl_FSM.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/ReadAddress_FSM.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/RXData_to_Byte.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/SafetyTaskSelection.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/SoC_Cnter.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/StoreAddress_FSM.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Task_Mem_Reset.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_components/Task_Memory.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Data_Buffer.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Packet_Buffer.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Frame_Creator.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Frame_Receiver.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Memory_Interface.vhd" {SYNTHESIS SIMULATION}
add_file "../fm/src/src_Manipulator_top_level/Process_Unit.vhd" {SYNTHESIS SIMULATION}
# |
# +-----------------------------------

# +-----------------------------------
# | parameters
# |
add_parameter gBytesOfTheFrameBuffer NATURAL 1600
set_parameter_property gBytesOfTheFrameBuffer DEFAULT_VALUE 1600
set_parameter_property gBytesOfTheFrameBuffer DISPLAY_NAME "Frame buffer size"
set_parameter_property gBytesOfTheFrameBuffer DESCRIPTION  "=> Memory is used to store frames, when using the Delay task"
set_parameter_property gBytesOfTheFrameBuffer TYPE NATURAL
set_parameter_property gBytesOfTheFrameBuffer UNITS Bytes
set_parameter_property gBytesOfTheFrameBuffer ALLOWED_RANGES 0:2147483647
set_parameter_property gBytesOfTheFrameBuffer AFFECTS_GENERATION false
set_parameter_property gBytesOfTheFrameBuffer HDL_PARAMETER true
add_parameter gTaskBytesPerWord NATURAL 4
set_parameter_property gTaskBytesPerWord DEFAULT_VALUE 4
set_parameter_property gTaskBytesPerWord DISPLAY_NAME "Word width of Avalon slave for transfer of tasks"
set_parameter_property gTaskBytesPerWord TYPE NATURAL
set_parameter_property gTaskBytesPerWord ENABLED false
set_parameter_property gTaskBytesPerWord UNITS Bytes
set_parameter_property gTaskBytesPerWord ALLOWED_RANGES 0:2147483647
set_parameter_property gTaskBytesPerWord AFFECTS_GENERATION false
set_parameter_property gTaskBytesPerWord HDL_PARAMETER true
add_parameter gTaskAddr NATURAL 8
set_parameter_property gTaskAddr DEFAULT_VALUE 8
set_parameter_property gTaskAddr DISPLAY_NAME "Address width of Avalon slave for transfer of tasks"
set_parameter_property gTaskAddr TYPE NATURAL
set_parameter_property gTaskAddr ENABLED false
set_parameter_property gTaskAddr UNITS None
set_parameter_property gTaskAddr ALLOWED_RANGES 0:2147483647
set_parameter_property gTaskAddr AFFECTS_GENERATION false
set_parameter_property gTaskAddr HDL_PARAMETER true
add_parameter gTaskCount NATURAL 30
set_parameter_property gTaskCount DEFAULT_VALUE 30
set_parameter_property gTaskCount DISPLAY_NAME "Number of configurable tasks"
set_parameter_property gTaskCount DESCRIPTION  "=> Number of subindices of object 0x3001-0x3004"
set_parameter_property gTaskCount TYPE NATURAL
set_parameter_property gTaskCount UNITS None
set_parameter_property gTaskCount ALLOWED_RANGES 0:2147483647
set_parameter_property gTaskCount AFFECTS_GENERATION false
set_parameter_property gTaskCount HDL_PARAMETER true
add_parameter gControlBytesPerWord NATURAL 1
set_parameter_property gControlBytesPerWord DEFAULT_VALUE 1
set_parameter_property gControlBytesPerWord DISPLAY_NAME "Word width of Avalon slave for transfer of operations"
set_parameter_property gControlBytesPerWord TYPE NATURAL
set_parameter_property gControlBytesPerWord ENABLED false
set_parameter_property gControlBytesPerWord UNITS Bytes
set_parameter_property gControlBytesPerWord ALLOWED_RANGES 0:2147483647
set_parameter_property gControlBytesPerWord AFFECTS_GENERATION false
set_parameter_property gControlBytesPerWord HDL_PARAMETER true
add_parameter gControlAddr NATURAL 1
set_parameter_property gControlAddr DEFAULT_VALUE 1
set_parameter_property gControlAddr DISPLAY_NAME "Address width of Avalon slave for transfer of operations"
set_parameter_property gControlAddr TYPE NATURAL
set_parameter_property gControlAddr ENABLED false
set_parameter_property gControlAddr UNITS Bytes
set_parameter_property gControlAddr ALLOWED_RANGES 0:2147483647
set_parameter_property gControlAddr AFFECTS_GENERATION false
set_parameter_property gControlAddr HDL_PARAMETER true
add_parameter gBytesOfThePackBuffer NATURAL 16000
set_parameter_property gBytesOfThePackBuffer DEFAULT_VALUE 16000
set_parameter_property gBytesOfThePackBuffer DISPLAY_NAME "Packet buffer size"
set_parameter_property gBytesOfThePackBuffer DESCRIPTION  "=> Memory is used to store safety packets, when using the safety tasks"
set_parameter_property gBytesOfThePackBuffer TYPE NATURAL
set_parameter_property gBytesOfThePackBuffer UNITS Bytes
set_parameter_property gBytesOfThePackBuffer ALLOWED_RANGES 0:2147483647
set_parameter_property gBytesOfThePackBuffer AFFECTS_GENERATION false
set_parameter_property gBytesOfThePackBuffer HDL_PARAMETER true
add_parameter gNumberOfPackets NATURAL 1000
set_parameter_property gNumberOfPackets DEFAULT_VALUE 1000
set_parameter_property gNumberOfPackets DISPLAY_NAME "Maximal number of safety packets"
set_parameter_property gNumberOfPackets DESCRIPTION  "=> Value needed to calculate the size of the address-memory of the packet buffer"
set_parameter_property gNumberOfPackets TYPE NATURAL
set_parameter_property gNumberOfPackets UNITS None
set_parameter_property gNumberOfPackets ALLOWED_RANGES 0:2147483647
set_parameter_property gNumberOfPackets AFFECTS_GENERATION false
set_parameter_property gNumberOfPackets HDL_PARAMETER true
# |
# +-----------------------------------

# +-----------------------------------
# | display items
# |
# |
# +-----------------------------------

# +-----------------------------------
# | connection point reset
# |
add_interface reset reset end
set_interface_property reset associatedClock clock_50
set_interface_property reset synchronousEdges DEASSERT

set_interface_property reset ENABLED true

add_interface_port reset iReset reset Input 1
# |
# +-----------------------------------

# +-----------------------------------
# | connection point stream_to_dut
# |
add_interface stream_to_dut conduit end

set_interface_property stream_to_dut ENABLED true

add_interface_port stream_to_dut iRXDV export Input 1
add_interface_port stream_to_dut iRXD export Input 2
add_interface_port stream_to_dut oTXData export Output 2
add_interface_port stream_to_dut oTXDV export Output 1
# |
# +-----------------------------------

# +-----------------------------------
# | connection point led
# |
add_interface led conduit end

set_interface_property led ENABLED true
add_interface_port led oLED export Output 2
# |
# +-----------------------------------

# +-----------------------------------
# | connection point clock_mem_slave
# |
add_interface clock_mem_slave clock end
set_interface_property clock_mem_slave clockRate 0

set_interface_property clock_mem_slave ENABLED true

add_interface_port clock_mem_slave iS_Clk clk Input 1
# |
# +-----------------------------------

# +-----------------------------------
# | connection point clock_50
# |
add_interface clock_50 clock end
set_interface_property clock_50 clockRate 50000000

set_interface_property clock_50 ENABLED true

add_interface_port clock_50 iClk50 clk Input 1
# |
# +-----------------------------------

# +-----------------------------------
# | connection point st_slave_tasks
# |
add_interface st_slave_tasks avalon end
set_interface_property st_slave_tasks addressUnits WORDS
set_interface_property st_slave_tasks associatedClock clock_mem_slave
set_interface_property st_slave_tasks associatedReset reset
set_interface_property st_slave_tasks bitsPerSymbol 8
set_interface_property st_slave_tasks burstOnBurstBoundariesOnly false
set_interface_property st_slave_tasks burstcountUnits WORDS
set_interface_property st_slave_tasks explicitAddressSpan 0
set_interface_property st_slave_tasks holdTime 0
set_interface_property st_slave_tasks linewrapBursts false
set_interface_property st_slave_tasks maximumPendingReadTransactions 0
set_interface_property st_slave_tasks readLatency 0
set_interface_property st_slave_tasks readWaitTime 1
set_interface_property st_slave_tasks setupTime 0
set_interface_property st_slave_tasks timingUnits Cycles
set_interface_property st_slave_tasks writeWaitTime 0

set_interface_property st_slave_tasks ENABLED true

add_interface_port st_slave_tasks iSt_read read Input 1
add_interface_port st_slave_tasks oSt_readdata readdata Output gtaskbytesperword*8
add_interface_port st_slave_tasks iSt_byteenable byteenable Input gtaskbytesperword
add_interface_port st_slave_tasks iSt_address address Input gtaskaddr
add_interface_port st_slave_tasks iSt_writedata writedata Input gtaskbytesperword*8
add_interface_port st_slave_tasks iSt_write write Input 1
# |
# +-----------------------------------

# +-----------------------------------
# | connection point sc_slave_control
# |
add_interface sc_slave_control avalon end
set_interface_property sc_slave_control addressUnits WORDS
set_interface_property sc_slave_control associatedClock clock_mem_slave
set_interface_property sc_slave_control associatedReset reset
set_interface_property sc_slave_control bitsPerSymbol 8
set_interface_property sc_slave_control burstOnBurstBoundariesOnly false
set_interface_property sc_slave_control burstcountUnits WORDS
set_interface_property sc_slave_control explicitAddressSpan 0
set_interface_property sc_slave_control holdTime 0
set_interface_property sc_slave_control linewrapBursts false
set_interface_property sc_slave_control maximumPendingReadTransactions 0
set_interface_property sc_slave_control readLatency 0
set_interface_property sc_slave_control readWaitTime 1
set_interface_property sc_slave_control setupTime 0
set_interface_property sc_slave_control timingUnits Cycles
set_interface_property sc_slave_control writeWaitTime 0

set_interface_property sc_slave_control ENABLED true

add_interface_port sc_slave_control iSc_read read Input 1
add_interface_port sc_slave_control iSc_address address Input gcontroladdr
add_interface_port sc_slave_control iSc_writedata writedata Input gcontrolbytesperword*8
add_interface_port sc_slave_control oSc_readdata readdata Output gcontrolbytesperword*8
add_interface_port sc_slave_control iSc_write write Input 1
add_interface_port sc_slave_control iSc_byteenable byteenable Input gcontrolbytesperword
# |
# +-----------------------------------
