#include "global.h"
#include "Benchmark.h"
#include "kernel/EplObdk.h"
#include "Framemanipulator.h"




//---------------------------------------------------------------------------
//
// Function:    FM_PDO_Transfer
//
// Description: PDO accesses for FM for configuration
//
// Parameters:  operation_byte_p                = opertaions/PDO Data (PReq)
//              p_status_byte_p                 = error-messages+status/PDO Data (PRes)
//
// Location:    Has to be called in the function AppCbSync()
//
//---------------------------------------------------------------------------


    void FM_PDO_Transfer(char operation_byte_p,char* p_status_byte_p)
   {
       //memory pointer
       volatile unsigned char  *c_base = (unsigned char *)FM_Control_Base;

       //positive edge signal
       unsigned char operation_pos_edge;

       //storage of the operation of the last cycle for edge-detection
       static unsigned char old_operation_byte_p;


       //positive edge detection:   new_value XOR old_value => edge
       //                           edge AND new_value => positive edge
       operation_pos_edge=(operation_byte_p^old_operation_byte_p)&operation_byte_p;

       //reading word 1 = status register for PRes
       *p_status_byte_p=operation_pos_edge|IORD8(c_base,FM_ContrErrorAddr);

       //writing word 0 = operation register of PReq
       IOWR8(c_base,FM_ContrOpeAddr,operation_pos_edge);


       //storing of old data
       old_operation_byte_p=operation_byte_p;

   }





//---------------------------------------------------------------------------
//
// Function:    FMConfigObdAccess
//
// Description: callback function for FM accesses for writing tasks
//
// Parameters:  pParam_p                = OBD parameter
//
// Returns:     tEplKernel              = error code
//
//
// Interface to the Framemanipulator
//
//---------------------------------------------------------------------------

tEplKernel PUBLIC FMConfigObdAccess(tEplObdCbParam MEM* pParam_p)
{

    //object variables
    tEplKernel          Ret = kEplSuccessful;
    unsigned int        uiIndexType;
    unsigned int        uiSubIndType;

    //temporary data signals
    DWORD               *pTmp = (DWORD*)(pParam_p->m_pData);
    unsigned char       temp_char;
    DWORD               temp_ar[2];

    //memory pointer
    volatile unsigned long  *t_base = (unsigned long *)FM_Task_Base;
    volatile unsigned char  *c_base = (unsigned char *)FM_Control_Base;


    pParam_p->m_dwAbortCode = 0;
    uiIndexType = pParam_p->m_uiIndex;
    uiSubIndType = pParam_p->m_uiSubIndex;




    if ((pParam_p->m_ObdEvent != kEplObdEvPreWrite)&&(pParam_p->m_ObdEvent !=kEplObdEvPreRead))
    {   // read accesses, post write events etc. are OK
        goto Exit;
    }


    //SDO-WRITE------------------------------------------------------------------
    //Write => SDO => Object and FM
    if (pParam_p->m_ObdEvent==kEplObdEvPreWrite)
    {
        if (uiSubIndType<=FM_NoOFTasks)//Number of the mapped Object fits in the Memory
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
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks)*2+1,pTmp[1]);
                        break;
                    }
                case 0x3003:
                    {
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks*2)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks*2)*2+1,pTmp[1]);
                        break;
                    }
                case 0x3004:
                    {
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks*3)*2,pTmp[0]);
                        IOWR32(t_base,(uiSubIndType-1+FM_NoOFTasks*3)*2+1,pTmp[1]);
                        break;
                    }
                default:
                    {

                    }
            }
        }
        else
        {
            //Error detection: subindex>available tasks
            //temp_char=0x04;//IORD8(c_base,FM_ContrErrorAddr);//|0x04;
            //IOWR8(c_base,FM_ContrErrorAddr,temp_char);
        }
    }

    //SDO READ-------------------------------------------------------------------
    //Read => FM => Object => SDO
    if (pParam_p->m_ObdEvent==kEplObdEvPreRead)
    {
        if (uiSubIndType<=FM_NoOFTasks)
        {
            if (uiSubIndType==0)
            {
                //subindex 0 = number of available tasks
                char temp_char=FM_NoOFTasks;
                //update subnindex 0
                EplObdWriteEntry(uiIndexType, 0,&temp_char,1);
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
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks)*2+1);
                            break;
                        }
                    case 0x3003:
                        {
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks*2)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks*2)*2+1);
                            break;
                        }
                    case 0x3004:
                        {
                            temp_ar[0]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks*3)*2);
                            temp_ar[1]=IORD32(t_base,(uiSubIndType-1+FM_NoOFTasks*3)*2+1);
                            break;
                        }
                    default:
                        {

                        }
                }
                //updates objects with the true value
                EplObdWriteEntry(uiIndexType, uiSubIndType,&temp_ar,8);
            }
        }
        else
        {
            //subindex>available tasks => task is not readable => zeroes
            temp_ar[0]=0;
            temp_ar[1]=0;
            EplObdWriteEntry(uiIndexType, uiSubIndType,&temp_ar,8);     //Write 0 to unused Subindexes
        }
  }


Exit:

    return Ret;
}

