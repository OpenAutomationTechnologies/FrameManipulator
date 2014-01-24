/**
********************************************************************************
\file   frameman.c

\brief  Main file of the Framemanipulator

This file contains the SDO- and PDO-transfer of the Framemanipulator for
configuration and operation

\ingroup module_FM
*******************************************************************************/

/*------------------------------------------------------------------------------
Copyright (c) 2013, Bernecker+Rainer Industrie-Elektronik Ges.m.b.H. (B&R)
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the copyright holders nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDERS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------------*/

//------------------------------------------------------------------------------
// includes
//------------------------------------------------------------------------------

#include "frameman.h"
#include <system.h>
#include <user/pdou.h>

//============================================================================//
//            G L O B A L   D E F I N I T I O N S                             //
//============================================================================//

//------------------------------------------------------------------------------
// const defines
//------------------------------------------------------------------------------

#define IORD32(base, offset)        IORD_32DIRECT(base+offset, 0)
#define IORD16(base, offset)        IORD_16DIRECT(base+offset, 0)
#define IORD8(base, offset)         IORD_8DIRECT(base+offset, 0)
#define IOWR32(base, offset, data)  IOWR_32DIRECT(base+offset, 0, data)
#define IOWR16(base, offset, data)  IOWR_16DIRECT(base+offset, 0, data)
#define IOWR8(base, offset, data)   IOWR_8DIRECT(base+offset, 0, data)

#define FRAMEMAN_CONTROL_REG_OPERATION 0
#define FRAMEMAN_CONTROL_REG_STATUS    1

#define FRAMEMAN_TASK_BASE            FRAMEMANIPULATOR_0_ST_SLAVE_TASKS_BASE
#define FRAMEMAN_CONTROL_BASE         FRAMEMANIPULATOR_0_SC_SLAVE_CONTROL_BASE
#define FRAMEMAN_NO_OF_TASKS          FRAMEMANIPULATOR_0_ST_SLAVE_TASKS_SPAN/(8*4)    //Whole Span in Bytes
                                        // 8Byte for a Word in 4 Memory-Blocks

//------------------------------------------------------------------------------
// module global vars
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// global function prototypes
//------------------------------------------------------------------------------


//============================================================================//
//            P R I V A T E   D E F I N I T I O N S                           //
//============================================================================//

//------------------------------------------------------------------------------
// const defines
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// local types
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// local vars
//------------------------------------------------------------------------------

static BYTE    aControlReg_l[2];

//------------------------------------------------------------------------------
// local function prototypes
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
/**
\brief  Framemanipulator Initialisation

Linking of Object 0x3000 for PDO-transfer

\return The function returns a tEplKernel error code.

\ingroup module_FM
*/
//------------------------------------------------------------------------------
tEplKernel frameman_init(void)
{
    tObdSize        obdSize;
    UINT            varEntries;

    aControlReg_l[0]=0;
    aControlReg_l[1]=0;

    obdSize = sizeof(aControlReg_l[0]);
    varEntries = 2;

    return oplk_linkObject(0x3000, aControlReg_l, &varEntries, &obdSize, 0x01);

}


//------------------------------------------------------------------------------
/**
\brief  PDO-Callback of the Framemanipulator

Linking of Object 0x3000 for PDO-transfer via callback

\return The function returns a tEplKernel error code.

\ingroup module_FM
*/
//------------------------------------------------------------------------------
tEplKernel frameman_syncCb(void)
{
   BYTE operationByte       = aControlReg_l[FRAMEMAN_CONTROL_REG_OPERATION];
   BYTE *pErrorByte_p       = &aControlReg_l[FRAMEMAN_CONTROL_REG_STATUS];

   tEplKernel ret           = kEplSuccessful;

   //memory pointer
   volatile BYTE  *c_base   = (BYTE *)FRAMEMAN_CONTROL_BASE;

   //positive edge signal
   BYTE operation_pos_edge;

   //storage of the operation of the last cycle for edge-detection
   static BYTE old_operationByte_p;

   //Load Registers
   ret = pdou_copyRxPdoToPi();
   if(ret != kEplSuccessful)
        goto Exit;

   //positive edge detection:   new_value XOR old_value => edge
   //                           edge AND new_value => positive edge
   operation_pos_edge=(operationByte^old_operationByte_p)&operationByte;

   //reading word 1 = status register for PRes
   *pErrorByte_p=operation_pos_edge|IORD8(c_base,FRAMEMAN_CONTROL_REG_STATUS);

   //writing word 0 = operation register of PReq
   IOWR8(c_base,FRAMEMAN_CONTROL_REG_OPERATION,operation_pos_edge);

   //storing of old data
   old_operationByte_p=operationByte;

   //Store Registers
   ret = pdou_copyTxPdoFromPi();

   Exit:

   return ret;
}



//------------------------------------------------------------------------------
/**
\brief  PDO-Callback of the Framemanipulator

Callback function for FM accesses for writing tasks

\param  pParam_p            OBD parameter

\return The function returns a tEplKernel error code.

\ingroup module_FM
*/
//------------------------------------------------------------------------------
tEplKernel frameman_configObdAccessCb(tObdCbParam MEM* pParam_p)
{

    //object variables
    tEplKernel          Ret = kEplSuccessful;
    unsigned int        uiIndexType;
    unsigned int        uiSubIndType;

    //temporary data signals
    DWORD               *pTmp = (DWORD*)(pParam_p->pArg);
    DWORD               temp_ar[2];

    //memory pointer
    volatile unsigned long  *t_base = (unsigned long *)FRAMEMAN_TASK_BASE;


    pParam_p->abortCode = 0;
    uiIndexType = pParam_p->index;
    uiSubIndType = pParam_p->subIndex;




    if ((pParam_p->obdEvent != kObdEvPreWrite)&&(pParam_p->obdEvent !=kObdEvPreRead))
    {   // read accesses, post write events etc. are OK
        goto Exit;
    }


    //SDO-WRITE------------------------------------------------------------------
    //Write => SDO => Object and FM
    if (pParam_p->obdEvent==kObdEvPreWrite)
    {
        if (uiSubIndType<=FRAMEMAN_NO_OF_TASKS)//Number of the mapped Object fits in the Memory
        {
            // check index type
            switch (uiIndexType)
            {
                case 0x3001:
                    {
                        //store SDO data to Framemanipulator memory
                        IOWR32(t_base,(uiSubIndType-1)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1)*2+1,pTmp[1]);
                        break;
                    }
                case 0x3002:
                    {
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS)*2+1,pTmp[1]);
                        break;
                    }
                case 0x3003:
                    {
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*2)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*2)*2+1,pTmp[1]);
                        break;
                    }
                case 0x3004:
                    {
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*3)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*3)*2+1,pTmp[1]);
                        break;
                    }
                default:
                    {
                        break;
                    }
            }
        }
    }

    //SDO READ-------------------------------------------------------------------
    //Read => FM => Object => SDO
    if (pParam_p->obdEvent==kObdEvPreRead)
    {
        if (uiSubIndType<=FRAMEMAN_NO_OF_TASKS)
        {
            if (uiSubIndType==0)
            {
                //subindex 0 = number of available tasks
                char temp_char=FRAMEMAN_NO_OF_TASKS;
                //update subnindex 0
                obd_writeEntry(uiIndexType, 0,&temp_char,1);
            }
            else
            {

                // check index type
                switch (uiIndexType)
                {
                    //collect the true task value from the Framemanipulator
                    case 0x3001:
                        {

                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1)*2+1);
                            break;
                        }
                    case 0x3002:
                        {
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS)*2+1);
                            break;
                        }
                    case 0x3003:
                        {
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*2)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*2)*2+1);
                            break;
                        }
                    case 0x3004:
                        {
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*3)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FRAMEMAN_NO_OF_TASKS*3)*2+1);
                            break;
                        }
                    default:
                        {
                            break;
                        }
                }
                //updates objects with the true value
                obd_writeEntry(uiIndexType, uiSubIndType,&temp_ar,8);
            }
        }
        else
        {
            //subindex>available tasks => task is not readable => zeroes
            temp_ar[0]=0;
            temp_ar[1]=0;
            obd_writeEntry(uiIndexType, uiSubIndType,&temp_ar,8);     //Write 0 to unused Subindexes
        }
  }

Exit:

    return Ret;
}

