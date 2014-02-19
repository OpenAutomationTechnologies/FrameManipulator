Framemanipulator IP-Core {#mainpage}
==============================

[TOC]


# Introduction {#fm-intro}


The FPGA design of the Framemanipulator is a POWERLINK Slave with an additional IP-Core. The POWERLINK Slave serves as Hub for configuring the PHYs and transferring the frames. It also receives the operations and configurations for the Framemanipulator from the POWERLINK Master and transfers it to the IP-Core via Avalon interface.

The Framemanipulator IP-Core is provided with two data interfaces suitable for RMII PHYs. The IP-Core is inserted between the outgoing data stream to the DUT. Therefore, all manipulations are only perceived by the DUT.

![](Structure.png "Internal structure of the Framemanipulator device")









# External signals {#fm_ext_signals}

## RMII interface to FM: ## {#fm_ext_rmii_rx}

Input data stream to Frame_Receiver

Conduit | Clock domain  | Description
------- | ------------- | ---------
FrameManipulator.iRXD       | FrameManipulator.iClk50 | Receiving RMII data stream
FrameManipulator.iRXDV      | FrameManipulator.iClk50 | Receiving RMII data valid

## RMII interface from FM: ## {#fm_ext_rmii_tx}

Output data stream from module Frame_Creator

Conduit | Clock domain  | Description
------- | ------------- | ---------
FrameManipulator.oTXData    | FrameManipulator.iClk50 | Outgoing RMII data stream
FrameManipulator.oTXDV      | FrameManipulator.iClk50 | Outgoing RMII data valid

## Status/Error LED: ## {#fm_ext_led}

LED signal provided by Process_Unit

Conduit | Clock domain  | Description
------- | ------------- | ---------
FrameManipulator.oLED      | FrameManipulator.iClk50 | Status and error LED

## Avalon slave to operate the FM: ## {#fm_ext_operate}

Interface of module Memory_Interface with data for operation (0x3000/1) and status (0x3000/2) register

Conduit | Clock domain  | Description
------- | ------------- | ---------
FrameManipulator.iSc_read        | FrameManipulator.iS_clk | Avalon slave for FM control read enable
FrameManipulator.iSc_write       | FrameManipulator.iS_clk | Avalon slave for FM control write enable
FrameManipulator.iSc_byteenable  | FrameManipulator.iS_clk | Avalon slave for FM control byte enable
FrameManipulator.iSc_address     | FrameManipulator.iS_clk | Avalon slave for FM control address
FrameManipulator.iSc_writedata   | FrameManipulator.iS_clk | Avalon slave for FM control write data
FrameManipulator.oSc_readdata    | FrameManipulator.iS_clk | Avalon slave for FM control read data

## Avalon slave to transfer the configuration to the FM: ## {#fm_ext_configurate}

Interface of module Memory_Interface with data for configuration (Objects 0x3001-0x3004)

Conduit | Clock domain  | Description
------- | ------------- | ---------
FrameManipulator.iSt_read        | FrameManipulator.iS_clk | Avalon slave for FM task configuration read enable
FrameManipulator.iSt_write       | FrameManipulator.iS_clk | Avalon slave for FM task configuration write enable
FrameManipulator.iSt_byteenable  | FrameManipulator.iS_clk | Avalon slave for FM task configuration byte enable
FrameManipulator.iSt_address     | FrameManipulator.iS_clk | Avalon slave for FM task configuration address
FrameManipulator.iSt_writedata   | FrameManipulator.iS_clk | Avalon slave for FM task configuration write data
FrameManipulator.oSt_readdata    | FrameManipulator.iS_clk | Avalon slave for FM task configuration read data






# The IP-Core Toplevel {#fm_toplevel}


The toplevel of the IP-Core is shown below. The function of each module is described in the following chapters.

![](toplevel.png "Framemanipulator IP-Core toplevel")


An Ethernet frame from the openHUB of the PL-Slave arrives at module Frame_Receiver ([More details](doc_frame_receiver.html)). The module synchronizes the other modules, checks the ingoing stream ([Signal](#fm_ext_rmii_rx)), converts the word with to the size of 1 Byte and stores the data to the memory Data_Buffer. POWERLINK, IP and ARP frames with a correct preamble get listed with their start- and end-address within the Process_Unit. The manipulation task Cut is also processed in module Frame_Receiver by sending a distorted end-address.

The Process_Unit ([More details](doc_process_unit.html)) handles the start- and end-address of the Data_Buffer. New frames are stored one after another, wrong or dropped frames will be overwritten with new data. The Process_Unit also handles the execution of the manipulation tasks and compares the configured frame pattern with the current frame. The manipulations Drop-Frame and Delay are processed within the module.

The module Data_Buffer ([More details](doc_data_buffer.html)) is the memory for the frame data. It also manipulates the frame header data.

The new frame is put out ([Signal](#fm_ext_rmii_tx)) by the module Frame_Creator ([More details](doc_frame_creator.html)), once it receives the start signal of the Process_Unit. It creates a frame with new Preamble and CRC and keeps the IPG of 960 ns. The task CRC-Distortion is executed here.

Manipulation of safety packets are processed in the module Packet_Buffer ([More details](doc_packet_buffer.html)). It stores, exchanges, deletes and distorts the safety packets by manipulating the data stream of the outgoing frame of module Frame_Creator.

The Interface between the Framemanipulator and the PL-Slave is the module Memory_Interface ([More details](doc_memory_interface.html)). The configured manipulations are stored in this module, as well as the control registers with the FM operation and status. The two memories are provided with one Avalon slave each ([Configuration](#fm_ext_configurate), [Operation](#fm_ext_operate)) with an alternative clock domain FrameManipulator.iS_clk.

The data between the MN and the IP-Core is transferred via two callback functions of the PL-Slave [More details](doc_software.html). One for the control via synchronous PDO and one for the configuration in the asynchronous SDO.






