Manipulation of safety Packets - Module Packet_Buffer {#doc_packet_buffer}
==============================

[TOC]


# Introduction {#pb-intro}

The safety manipulations are processed with the Packet_Buffer. It stores the packets, distorts them and sends the manipulated data to the Frame_Creator. The setting of the next safety manipulation Packet_Buffer.iManiSetting from the Process_Unit is stored at every incoming SoC Packet_Buffer.iFrameIsSoc. This data is processed in the [FSM of the module](#pb-fsm), which controls the [buffer with the safety packets](#pb-mem).

A ingoing safety frame is marked by the input Packet_Buffer.iSafetyFrame. The number of manipulated packets is stored within a counter.


# FSM PacketControl_FSM {#pb-fsm}


The FSM starts with the selection of the state for the manipulation by comparing the current safety task PacketControl_FSM.iSafetyTask with its predefined values of framemanipulatorPkg.cTask. The FSM returns to the state __sIdle__ once the another safety task is active (PacketControl_FSM.iNewTask) or the test is aborted (PacketControl_FSM.iStopTest).



![](PacketControlMain.png "Idle state of the PacketControl_FSM")


The FSM is processing ingoing safety frames while the _active_ signal is active. It is set once the first frame is found (Packet_Buffer.iTaskSafetyEn) by the filter of the Process_Unit. The _active_ signal is deactivated when all frames were manipulated (Packet_Buffer.iCntEnd) or an error occurred (PacketControl_FSM.iStopTest).


## sRepetition {#pb-fsm-rep}


![](PacketControlRep.png "Repetition branch of the PacketControl_FSM")


The branch for the Packet-Repetition manipulation consists of the four different states. It starts with __sRepetition__ and switches at the arriving of a safety frame (positive edge of Packet_Buffer.iSafetyFrame) to __sRepetitionExchange__. The output Packet_Buffer.oPacketExchangeEn is set to indicate the frame for the Frame_Creator, which responds with the signal Packet_Buffer.iExchangeData during the safety packet and sets the signal PacketControl_FSM.oStore and PacketControl_FSM.oRead. The current frame will be stored within the memory and put out to the Frame_Creator without manipulation. The state returns to __sRepetition__ at the end of the packet manipulation (negative edge of Packet_Buffer.iExchangeData).

Once the first manipulated frame arrives, the active signal is set and the state switches to __sRepetitionCloneOutput__ and to __sRepetitionCloneExchange__ at positive edge of the safety frame Packet_Buffer.iSafetyFrame. The output PacketControl_FSM.oClonePacketEx is set with the active signal. Incoming packets will now be stored to the internal memory, while the outgoing packet to the Frame_Creator stays the same. After the exchange, the FSM returns to state __sRepetitionCloneOutput__, while counting up the packet counter with PacketControl_FSM.oCntEn.

After manipulating the last packet, the active signal is set back to zero and the FSM enters the state __sRepetition__. When switching to the state __sRepetitionExchange__ again, the current packet will be stored while sending the proper packet from the buffer to the Frame_Creator.



## sPaLoss     {#pb-fsm-loss}

![](PacketControlLoss.png "Packet-Loss branch of the PacketControl_FSM")

The branch for the Packet-Loss manipulation starts with __sPaLoss__ state. When the manipulation started and a safety frame is detected, the FSM enters the __sPaLossMani__ state. The packet will be exchanged while the buffer Packet_Memory is unused. No data will be stored or loaded. A zero patting is put out. After the exchange the FSM returns to state __sPaLoss__ and activates the packet counter.


## sInsertion  {#pb-fsm-insert}

![](PacketControlInsert.png "Packet-Insertion branch of the PacketControl_FSM")

The Packet-Insertion task starts at state __sInsertion__. Before the manipulation starts, the state __sStoreSN2__ is entered, when a safety frame arrives. The offset Packet_Buffer.oPacketStart is set to the position of the packet from the second SN. The packet is stored into the Packet_Memory and can be used for exchange, when the test is starts in the following cycle. At the end of the packet, the FSM returns to state __sInsertion__.


When the manipulation is active and the packet of the second safety node is sent first, the signal PacketControl_FSM.iSn2Pre is set and the state __sStoreSN2__ will be entered at an incoming safety frame. The offset Packet_Buffer.oPacketStart will be set to the packet of the second SN which will be stored into the Packet_Memory. When the packet ended, the FSM enters the state __sInsertionMani__, sets the offset Packet_Buffer.oPacketStart to the position of the manipulated packet and overwrites it with the packet of the other SN. When the packet of the DUT is right behind the packet of the other SN without any data in between, the signal PacketControl_FSM.iDutNoPaGap is set and starts directly with the packet exchange. After the end of the manipulated packet, the manipulation counter is activated and the state __sInsertion__ is entered again.

When the manipulation is active and the packet of the DUT is sent first, the signal PacketControl_FSM.iSn2Pre is deactivated and the state __sInsertionMani__ will be entered at an incoming safety frame. The offset Packet_Buffer.oPacketStart is set to the start address of the manipulated packet, which will be exchanged with the data of the last packet of the second SN. Once the packet ends, the state __sStoreSN2__ is entered, the offset Packet_Buffer.oPacketStart set to the position of the other safety packet which will be stored into the Packet_Memory. When the packet of the other SN is right behind the packet of the DUT without any data in between, the signal PacketControl_FSM.iSnNoPaGap is set and starts directly with the storage of the other safety packet. After the end of the manipulated packet, the manipulation counter is activated and the state __sInsertion__ is entered again.




## sIncSeq     {#pb-fsm-seq}

![](PacketControlSeq.png "Incorrect-Sequence branch of the PacketControl_FSM")

This branch is similar to the [Packet-Repetition task](#pb-fsm-rep).

Once the configuration is sent to the IP-Core, the FSM is going to start the delay of the safety packets. It switches from state __sIncSeq__ to __sIncSeqDelay__ when a safety frame arrives. These frames will be stored in the buffer while a zero pattern is sent to the Frame_Creator and the FSM returns to state __sIncSeq__. Ingoing safety packets will be delayed like this ([similar to the Packet-Delay task](#pb-fsm-delay)) until the needed amount of packets is stored into the Packet_Memory.

With signal PacketControl_FSM.iLagReached, enough packets are stored within the buffer to process the Incorrect-Sequence manipulation. From now on the FSM switches from __sIncSeq__ to __sIncSeqEx__ and back to keep the order of the outgoing packets by exchanging the current one with the proper packet from the buffer.

Once the manipulation is activated, the FSM enters the __sIncSeqAct__ state. Here the FSM switches to the state __sIncTwistPack__ and back to sent the safety packet in their reverse order by activating PacketControl_FSM.oTwistPacketEx. When the manipulation ended, the states __sIncSeq__ and __sIncSeqEx__ are processed again.



## sIncData    {#pb-fsm-data}

![](PacketControlData.png "Incorrect-Data branch of the PacketControl_FSM")

The Incorrect-Data task starts at the state __sIncData__. The signal PacketControl_FSM.oPacketStartPayload is set during the task. The position of the packet Packet_Buffer.oPacketStart is set to its payload with a size Packet_Buffer.oPacketSize of the manipulation of one Byte. All data, which is sent to the Frame_Creator is the inverted version of the original stream.

When the manipulation starts and safety frame enters the IP-Core, the FSM enters the state __sIncDataMani__ and distorts the one Byte of the payload. The FSM switches back to __sIncData__ afterwards.


## sPaDelay    {#pb-fsm-delay}

![](PacketControlDelay.png "Packet-Delay branch of the PacketControl_FSM")

The Packet-Delay task is handled similar to the [Packet-Repetition task](#pb-fsm-rep). The states __sPaDelay__ and __sPaDelayMani__ put the safety packet out in the correct order, while __sPaDelayKill__ and __sPaDelayKillMani__ exchange the packet with a zero-patting via PacketControl_FSM.oZeroPacketEx.




## sMasquerade {#pb-fsm-masqu}

![](PacketControlMasqu.png "Masquerade branch of the PacketControl_FSM")

The Masquerade manipulation starts at state __sMasquerade__. Once a SoC enters the FM, the state __sStoreSoC__ is entered by the FSM. The packet offset Packet_Buffer.oPacketStart is set to the Timestamp of the SoC, which will be stored into the Packet_Memory. The FSM returns to __sMasquerade__ once the storage ends. The safety packet is exchanged with the stored data, once the FSM enters the state __sMasqueradeMani__ during the manipulation.


# Packet Buffer Packet_Memory {#pb-mem}

Its like a memory with additional functions. When Packet_Memory.iStore is set, the incoming data are stored with receiving a start-address, stored in Packet_StartAddrMem. When Packet_Memory.iRead is set, the data is put out, starting from the receiving start-address of Packet_StartAddrMem. When both Packet_Memory.iStore and Packet_Memory.iRead are set the current packet is stored, while exchanging it with the data from the receiving start-address of Packet_StartAddrMem. When Packet_Memory.iZeroPacketEx is set, a zero pattern is put out.

The start-addresses of Packet_StartAddrMem is normally put out one after another like a FiFo. When Packet_Memory.iClonePacketEx is set, the start-address of the exchanged packet stays the same. Multiple packets are stored into the memory, while sending the identical packet. When Packet_Memory.iTwistPacketEx is set, the start-addresses are put out in the reverse order like a LiFo.




TODO: more details
