The Frame Buffer - Module Data_Buffer {#doc_data_buffer}
==============================

[TOC]


# Introduction {#db-intro}


The main task of the module Data_Buffer is to provide the memory for the frame data and the detection of an occurred overflow Data_Buffer.oError_frameBuffOv. Its size is defined by the generic FrameManipulator.gBytesOfTheFrameBuffer. It contains a DPRAM DpramFix, which data is stored by module Frame_Receiver and loaded by Frame_Creator.

The second task is to manipulate the frame header. The setting of this task consists of eight 1-Byte-data for the exchange with the corresponding eight 6-Bit-offsets.


![](taskMani.png "Setting of a Manipulation task")


Once the manipulation is started by Data_Buffer.iTaskManiEn, the Data_Buffer is checking all eight entries. The offsets are added to the start address of the frame Data_Buffer.iDataStartAddr and the data stored into the DPRAM. The offset describes the Byte number starting with the MAC-address of the frame, offsets with the value of 0 are ignored. The data is stored when the outgoing port of the DPRAM isn't used by the Frame_Creator module.




