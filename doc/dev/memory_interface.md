The Interface between PL-Slave and FM - Module Memory_Interface {#doc_memory_interface}
==============================

[TOC]


# Introduction {#mi-intro}


The module Memory_Interface is the connection between FM IP-Core and PL-Slave. The two Avalon interfaces are implemented to transfer the SDO and PDO data from and to the MN. The interface clock Memory_Interface.iS_clk can alter to the 50 MHz clock of the IP-Core. The module consists of three submodules:

* [Store FM operation](#mi-control)
* [Store task configuration](#mi-task)
* [Clear task memory](#mi-reset)


![](MemoryInterfaceInter.png "Internal structure of the Memory_Interface module")



## Store FM operation - Control_Register {#mi-control}


The data for the PDO transfer is stored in the DPRAM memory of the Control_Register. The size of the memory is two Bytes. The first one is the data of the operation register 0x3000/1 with its different enable-flags. Flags _Start_, _Stop_ and _Reset-Packet-Delay_ are passed on to the other modules, while _Clear-Errors_ is used to reset the error flags of the status register 0x3000/2 and _Delete-Tasks_ to [start the reset of the task memory](#mi-reset).


![](OperationReg.png "Operation register to control the FM")



The second Byte of the memory is the status register 0x3000/2 with the feedback from the FM. The _Test-is-active_ flag is activated during the series of test by the input signal Memory_Interface.iTestActive. The feedback of the flags _Stopping-Test_, _Deleting-Tasks_ and _Clearing-Errors_ are sent by the [callback within the PL-Slave](doc_software.html).

The upper nibble of the register is reserved for the error flags. Once an error occurred, it will be stored in here until the reset-flag is sent by the MN. An error also activates the output Memory_Interface.oStopTest and aborts the current series of test.


![](StatusReg.png "Status register with the feedback from the FM")


## Clear task memory - Task_Mem_Reset {#mi-reset}

The module Task_Mem_Reset is used to remove the configured tasks. During the series of test it transfers the input Memory_Interface.iRdTaskAddr to the memory Task_Memory, but will delete the stored entries once the rising edge of the input Task_Mem_Reset.iClearMem occurs by setting the output Task_Mem_Reset.oEnClear while generating the addresses.



## Store task configuration - Task_Memory {#mi-task}

The different task configurations are stored into the module Task_Memory. Its DPRAMs have a word width of 32 bit at the port of the Avalon interface, while having a word with of 64 bit for transferring the setting to the Process_Unit.

Four of these DPRAMs are implemented within the Task_Memory to put out the whole task configuration simultaneously. For the Avalon interface, they act like one big memory, parted by the data of the objects 0x3001 to 0x3004.

![](DPRAM4.png "Structure of the internal task memory")

