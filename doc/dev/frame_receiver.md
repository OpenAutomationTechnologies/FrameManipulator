Collecting the POWERLINK Frame - Module Frame_Receiver {#doc_frame_receiver}
==============================

[TOC]


# Introduction {#fr-intro}


The processing of ingoing frames starts with the Frame_Receiver module. Its first task is to detect the start of frame stream and to synchronize the other modules to it (Frame_Receiver.oFrameSync). This is done with the submodule RXData_to_Byte, which also converts the incoming data to a better usable word with of 1 Byte.




![](FrameReceiverIntern.png "Internal structure of the Frame_Receiver module")

Once a frame enters the module it will be stored to the Data_Buffer by submodule write_logic. It starts with the synchronization signal of RXData_to_Byte and ends with the end of the frame. The start-address Frame_Receiver.iDataStartAddr of the frame is provided by the Process_Unit and stores the ingoing frames one after another. Incorrect or dropped frames will be overwritten with the next valid frame.

The Preamble of the ingoing frame is verified by the Preamble_check module and the Ethertype is selected by the Frame_collector. Only POWERLINK, ARP and IP frames with a valid Preamble are allowed to pass. They set the signal Frame_Receiver.oStartFrameProcess and inform the Process_Unit once the check is done.


The frame end Frame_Receiver.oFrameEnded is set by the end_of_frame_detection module as well as the end-address of the frame data Frame_Receiver.oDataEndAddr. The module checks the RMII data valid signal Frame_Receiver.iRXDV and detects the falling edge. The end_of_frame_detection also truncates frames at the Cut manipulation by setting the signal of the frame end and sending the manipulated end-address, once the configured number of frame bytes Frame_Receiver.iTaskCutData is stored.

![](taskCut.png "Setting of a Cut manipulation")
