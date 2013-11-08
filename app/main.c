/**
********************************************************************************
\file        DigitalIoMain.c

\brief        main module of digital I/O user interface

\author        Josef Baumgartner

\date        06.04.2010

(C) BERNECKER + RAINER, AUSTRIA, A-5142 EGGELSBERG, B&R STRASSE 1

*******************************************************************************/

/******************************************************************************/
/* includes */
#include "Epl.h"

#include "fpgaCfg.h"
#include "omethlib.h"
#include "fwUpdate.h"

#include "EplSdo.h"
#include "EplAmi.h"
#include "EplObd.h"
#include "user/EplSdoAsySequ.h"

#ifdef __NIOS2__
#include <unistd.h>
#elif defined(__MICROBLAZE__)
#include "xilinx_usleep.h"
#endif

#include "systemComponents.h"

#ifdef LCD_BASE
#include "Cmp_Lcd.h"
#endif
//MANNI
#include "Framemanipulator.h"

//FM Variables
BYTE        FM_Control[2];


/******************************************************************************/
/* defines */
#define OBD_DEFAULT_SEG_WRITE_HISTORY_ACK_FINISHED_THLD 3           ///< count of history entries, where 0BD accesses will still be acknowledged
#define OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE              20          ///< maximum possible history elements
#define OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID           0xFFFFUL

#define NODEID      0x01 // should be NOT 0xF0 (=MN) in case of CN

#define CYCLE_LEN   1000 // [us]
#define MAC_ADDR    0x00, 0x12, 0x34, 0x56, 0x78, 0x9A
#define IP_ADDR     0xc0a86401  // 192.168.100.1 // don't care the last byte!
#define SUBNET_MASK 0xFFFFFF00  // 255.255.255.0

/**
 * \brief structure for object access forwarding to PDI (i.e. AP)
 */
typedef struct sApiPdiComCon {
    tEplObdParam *          apObdParam_m[0];    ///< SDO command layer connection handle number
} tApiPdiComCon;

// This function is the entry point for your object dictionary. It is defined
// in OBJDICT.C by define EPL_OBD_INIT_RAM_NAME. Use this function name to define
// this function prototype here. If you want to use more than one Epl
// instances then the function name of each object dictionary has to differ.

tEplKernel PUBLIC  EplObdInitRam (tEplObdInitParam MEM* pInitParam_p);
tEplKernel PUBLIC AppCbSync(void) INTERNAL_RAM_SIZE_MEDIUM;
tEplKernel PUBLIC AppCbEvent(
    tEplApiEventType        EventType_p,   // IN: event type (enum)
    tEplApiEventArg*        pEventArg_p,   // IN: event argument (union)
    void GENERIC*           pUserArg_p);

BYTE        portIsOutput[4];
BYTE        digitalIn[4];
BYTE        digitalOut[4];

static BOOL     fShutdown_l = FALSE;
BOOL            fIsUserImage_g;            ///< if set user image is booted
UINT32          uiFpgaConfigVersion_g = 0; ///< version of currently used FPGA configuration

static tDefObdAccHdl aObdDefAccHdl_l[OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE]; ///< segmented object access management

/* counter of currently empty OBD segmented write history elements for default OBD access */
BYTE bObdSegWriteAccHistoryEmptyCnt_g = OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE;
/* counter of subsequent accesses to an object */
WORD wObdSegWriteAccHistorySeqCnt_g = OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID;
tApiPdiComCon ApiPdiComInstance_g;


/******************************************************************************/
/* forward declarations */
int openPowerlink(BYTE bNodeId_p);
void InitPortConfiguration (BYTE *p_portIsOutput);
WORD GetNodeId (void);

static tEplKernel  EplAppCbDefaultObdAccess(tEplObdParam MEM* pObdParam_p);
static tEplKernel EplAppDefObdAccSaveHdl(tEplObdParam *  pObdParam_p,
                    tDefObdAccHdl **ppDefHdl_p);
static tEplKernel EplAppDefObdAccGetStatusObdHdl(WORD wIndex_p, WORD wSubIndex_p,
                    tEplObdDefAccStatus ReqStatus_p, BOOL fSearchOldest_p,
                    tDefObdAccHdl **ppDefObdAccHdl_p);
static tEplKernel EplAppDefObdAccGetObdHdl(tEplObdParam * pObdAccParam_p,
                    tDefObdAccHdl **ppDefObdAccHdl_p);
static tEplKernel EplAppDefObdAccWriteObdSegmented(tDefObdAccHdl *pDefObdAccHdl_p,
                    void * pfnSegmentFinishedCb_p, void * pfnSegmentAbortCb_p);
void EplAppDefObdAccCleanupAllPending(void);
void EplAppDefObdAccCleanupHistory(void);
tEplKernel EplAppDefObdAccFinished(tEplObdParam ** pObdParam_p);
int EplAppDefObdAccWriteSegmentedFinishCb(void * pHandle);
int EplAppDefObdAccWriteSegmentedAbortCb(void * pHandle);

/**
********************************************************************************
\brief  handle an user event

EplAppHandleUserEvent() handles all user events.

\param  pEventArg_p         event argument, the user argument of the event
                            contains the object handle

\return Returns kEplSucessful if user event was successfully handled. Otherwise
        an error code is returned.
*******************************************************************************/
static int EplAppHandleUserEvent(tEplApiEventArg* pEventArg_p)
{
    tEplKernel      EplRet = kEplSuccessful;
    tEplObdParam *  pObdParam;
    tDefObdAccHdl * pSegmentHdl;        ///< handle of this segment
    tDefObdAccHdl * pTempHdl;           ///< handle for temporary storage
    //        tEplTimerArg    TimerArg;                ///< timer event posting
    //        tEplTimerHdl    EplTimerHdl;             ///< timer event posting

    // assign user argument
    pObdParam = (tEplObdParam *) pEventArg_p->m_pUserArg;

    DEBUG_TRACE1(DEBUG_LVL_14,
                 "AppCbEvent(kEplApiEventUserDef): (EventArg %p)\n", pObdParam);

    // get segmented OBD access handle

    // if we don't find the segmented obd handle the segment was
    // already finished/aborted. In this case we immediately return.
    EplRet = EplAppDefObdAccGetObdHdl(pObdParam, &pSegmentHdl);
    if (EplRet != kEplSuccessful)
    {   // handle incorrectly assigned. Therefore we abort the segment!
        DEBUG_TRACE2(DEBUG_LVL_ERROR,
                     "%s() ERROR: No segmented access handle assigned for handle %p!\n",
                     __func__, pObdParam);
        return kEplSuccessful;
    }

    DEBUG_TRACE4(DEBUG_LVL_14, "(0x%04X/%u Ev=%X Size=%u\n",
         pObdParam->m_uiIndex, pObdParam->m_uiSubIndex,
         pObdParam->m_ObdEvent,
         pObdParam->m_SegmentSize);

    /*printf("(0x%04X/%u Ev=%X pData=%p Off=%u Size=%u\n"
           " ObjSize=%u TransSize=%u Acc=%X Typ=%X)\n",
        pObdParam->m_uiIndex, pObdParam->m_uiSubIndex,
        pObdParam->m_ObdEvent,
        pObdParam->m_pData,
        pObdParam->m_SegmentOffset, pObdParam->m_SegmentSize,
        pObdParam->m_ObjSize, pObdParam->m_TransferSize,
        pObdParam->m_Access, pObdParam->m_Type); */

    if(pObdParam->m_uiIndex != 0x1F50)
    {   // should not get any other indices
        DEBUG_TRACE1(DEBUG_LVL_ERROR, "%s() invalid object index!\n", __func__);
        return kEplInvalidParam;
    }

    /*------------------------------------------------------------------------*/
    // check if write operation has already started for this object
    EplRet = EplAppDefObdAccGetStatusObdHdl(pObdParam->m_uiIndex,
                                            pObdParam->m_uiSubIndex,
                                            kEplObdDefAccHdlInUse,
                                            FALSE,  // search first
                                            &pTempHdl);
    if (EplRet == kEplSuccessful)
    {   // write operation for this object is already processing
        DEBUG_TRACE3(DEBUG_LVL_14,
                     "%s() Write for object %d(%d) already in progress -> exit\n",
                     __func__, pObdParam->m_uiIndex, pObdParam->m_uiSubIndex);
        // change handle status
        pSegmentHdl->m_Status = kEplObdDefAccHdlWaitProcessingQueue;
    }
    else
    {
        switch (pSegmentHdl->m_Status)
        {
            case kEplObdDefAccHdlWaitProcessingInit:
            case kEplObdDefAccHdlWaitProcessingQueue:
                // segment has not been processed yet -> do a initialize writing

                // change handle status
                pSegmentHdl->m_Status = kEplObdDefAccHdlWaitProcessingQueue;

                /* search for oldest handle where m_pfnAccessFinished call is
                 * still due. As we know that we find at least our own handle,
                 * we don't have to take care of the return value! (Assuming
                 * there is no software error :) */
                EplAppDefObdAccGetStatusObdHdl(pObdParam->m_uiIndex,
                        pObdParam->m_uiSubIndex,
                        kEplObdDefAccHdlWaitProcessingQueue,
                        TRUE,           // find oldest
                        &pTempHdl);

                DEBUG_TRACE4(DEBUG_LVL_14, "%s() Check for oldest handle. EventHdl:%p Oldest:%p (Seq:%d)\n",
                             __func__, pObdParam, pSegmentHdl->m_pObdParam,
                             pSegmentHdl->m_wSeqCnt);

                if (pTempHdl->m_pObdParam == pObdParam)
                {   // this is the oldest handle so we do the write
                    EplRet = EplAppDefObdAccWriteObdSegmented(pSegmentHdl,
                                     EplAppDefObdAccWriteSegmentedFinishCb,
                                     EplAppDefObdAccWriteSegmentedAbortCb);
                }
                else
                {
                    // it is not the oldest handle so we do nothing
                    EplRet = kEplSuccessful;
                }
                break;

            case kEplObdDefAccHdlProcessingFinished:
                // go on with acknowledging finished segments
                DEBUG_TRACE2(DEBUG_LVL_14,
                        "%s() Handle Processing finished 0x%p\n", __func__,
                        pSegmentHdl->m_pObdParam);
                EplRet = kEplSuccessful;
                break;

            case kEplObdDefAccHdlError:
            default:
                // all other not handled cases are not allowed -> error
                DEBUG_TRACE2(DEBUG_LVL_ERROR, "%s() ERROR: Invalid handle status %d!\n",
                        __func__, pSegmentHdl->m_Status);
                // do ordinary SDO sequence processing / reset flow control manipulation
                EplSdoAsySeqAppFlowControl(0, FALSE);
                // Abort all not empty handles of segmented transfer
                EplAppDefObdAccCleanupHistory();
                EplRet = kEplSuccessful;
                break;
        } // switch (pSegmentHdl->m_Status)
    } /* else -- handle already in progress */

    return EplRet;
}

/**
 ********************************************************************************
 \brief deletes all pending default OBD accesses

 This function clears all allocated memory used for default OBD accesses and
 resets the OBD default access instance
 *******************************************************************************/
void EplAppDefObdAccCleanupAllPending(void)
{
    // clean domain OBD access history buffers
    EplAppDefObdAccCleanupHistory(); // ignore return value

    // clean forwarded OBD accesses
    if (ApiPdiComInstance_g.apObdParam_m[0] != 0)
    {
        EPL_FREE(ApiPdiComInstance_g.apObdParam_m[0]);
        ApiPdiComInstance_g.apObdParam_m[0]= NULL;
    }
}

/**
 ********************************************************************************
 \brief cleans the default OBD access history buffers

 This function clears errors from the segmented access history buffer which is
 used for default OBD accesses.
 *******************************************************************************/
void EplAppDefObdAccCleanupHistory(void)
{
    tDefObdAccHdl * pObdDefAccHdl = NULL;
    BYTE            bArrayNum;                 ///< loop counter and array element

    pObdDefAccHdl = aObdDefAccHdl_l;

    for (bArrayNum = 0; bArrayNum < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE; bArrayNum++, pObdDefAccHdl++)
    {
        if (pObdDefAccHdl->m_Status == kEplObdDefAccHdlEmpty)
        {
            continue;
        }

        DEBUG_TRACE2(DEBUG_LVL_14, "%s() Cleanup handle %p\n", __func__, pObdDefAccHdl->m_pObdParam);
        pObdDefAccHdl->m_pObdParam->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_OR_STORED;

        // Ignore return value
        EplAppDefObdAccFinished(&pObdDefAccHdl->m_pObdParam);

        // reset history status and access counter
        pObdDefAccHdl->m_Status = kEplObdDefAccHdlEmpty;
        pObdDefAccHdl->m_wSeqCnt = OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID;

        bObdSegWriteAccHistoryEmptyCnt_g++;
    }
    wObdSegWriteAccHistorySeqCnt_g = OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID;
}

/**
 ********************************************************************************
 \brief signals an OBD default access as finished

 \param pObdParam_p     pointer to OBD access struct pointer

 \return tEplKernel value
 *******************************************************************************/
tEplKernel EplAppDefObdAccFinished(tEplObdParam ** pObdParam_p)
{
tEplKernel EplRet = kEplSuccessful;
tEplObdParam * pObdParam = NULL;

    pObdParam = *pObdParam_p;

    DEBUG_TRACE2(DEBUG_LVL_14, "INFO: %s(%p) called\n", __func__, pObdParam);

    if (pObdParam_p == NULL                   ||
        pObdParam == NULL                     ||
        pObdParam->m_pfnAccessFinished == NULL  )
    {
        EplRet = kEplInvalidParam;
        goto Exit;
    }

    // check if it was a segmented write SDO transfer (domain object write access)
    if ((pObdParam->m_ObdEvent == kEplObdEvPreRead)            &&
        (//(pObdParam->m_SegmentSize != pObdParam->m_ObjSize) || //TODO: implement object size in Async message
         (pObdParam->m_SegmentOffset != 0)                    )  )
    {
        //segmented read access not allowed!
        pObdParam->m_dwAbortCode = EPL_SDOAC_UNSUPPORTED_ACCESS;
    }

    // call callback function which was assigned by caller
    EplRet = pObdParam->m_pfnAccessFinished(pObdParam);

    if ((pObdParam->m_uiIndex < 0x2000)               &&
        (pObdParam->m_Type == kEplObdTypDomain)         &&
        (pObdParam->m_ObdEvent == kEplObdEvInitWriteLe)   )
    {   // free allocated memory for segmented write transfer history

        if (pObdParam->m_pData != NULL)
        {
            EPL_FREE(pObdParam->m_pData);
            pObdParam->m_pData = NULL;
        }
        else
        {   //allocation expected, but not present!
            EplRet = kEplInvalidParam;
        }
    }

    // free handle storage
    EPL_FREE(pObdParam);
    *pObdParam_p = NULL;

Exit:
    if (EplRet != kEplSuccessful)
    {
        DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: %s failed!\n", __func__);
    }
    return EplRet;

}

/**
********************************************************************************
\brief  assign data type in a obd access handle

\param  pObdParam_p     Pointer to obd access handle
*******************************************************************************/
static void EplAppCbDefaultObdAssignDatatype(tEplObdParam *pObdParam_p)
{
    // assign data type

    // check object size and type
    switch (pObdParam_p->m_uiIndex)
    {
        case 0x1010:
        //case 0x1011:
            pObdParam_p->m_Type = kEplObdTypUInt32;
            pObdParam_p->m_ObjSize = 4;
            break;

        case 0x1F50:
            pObdParam_p->m_Type = kEplObdTypDomain;
            //TODO: check maximum segment offset
            break;

        default:
            if(pObdParam_p->m_uiIndex >= 0x2000)
            {  // all application specific objects will be verified at AP side
                break;
            }

            break;
    } /* switch (pObdParam_p->m_uiIndex) */
}

/**
********************************************************************************
\brief  writes data to an OBD entry from a source with little endian byteorder

\param  pObdParam_p     pointer to object handle

\return kEplObdAccessAdopted or error code
*******************************************************************************/
static tEplKernel EplAppCbDefaultObdInitWriteLe(tEplObdParam *pObdParam_p)
{
    tEplObdParam *   pAllocObdParam = NULL; ///< pointer to allocated memory of OBD access handle
    BYTE *           pAllocDataBuf;         ///< pointer to object data buffer
    tEplKernel       Ret = kEplSuccessful;
    tDefObdAccHdl *  pDefObdHdl;

    // do not return kEplSuccessful in this case,
    // only error or kEplObdAccessAdopted is allowed!

    // TODO: Do I really need to allocate a buffer for Default OBD (write) access ?
    // TODO: block all transfers of same index/subindex which are already processing

    // verify caller - if it is local, then write access to read only object is fine
    if (pObdParam_p->m_pRemoteAddress != NULL)
    {   // remote access via SDO
        // if it is a read only object -> refuse SDO access
        if (pObdParam_p->m_Access == kEplObdAccR)
        {
            Ret = kEplObdWriteViolation;
            pObdParam_p->m_dwAbortCode = EPL_SDOAC_WRITE_TO_READ_ONLY_OBJ;
            goto Exit;
        }
    }

    // Note SDO: Only a "history segment block" can be delayed, but not single segments!
    //           Client will send Ack Request after sending a history block, so we don't need to
    //           send an Ack immediately after first received frame.

    // verify if caller has assigned a callback function
    if (pObdParam_p->m_pfnAccessFinished == NULL)
    {
        if (pObdParam_p->m_pRemoteAddress != NULL)
        {   // remote access via SDO
            pObdParam_p->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_OR_STORED;
            Ret = kEplObdAccessViolation;
        }
        else
        {
            // ignore all other originators than SDO (for now)
            // workaround: do not return error because EplApiLinkObject() calls this function,
            // but object access is not really necessary

            /* TODO jba: if we exit here we return successfull which shouldn't be according to
               comment at beginning of function */
        }
        goto Exit;
    }

    // different pre-access verification for all write objects (previous to handle storing)
    switch (pObdParam_p->m_uiIndex)
    {
        case 0x1010:
        //case 0x1011:
            break;

//      case 0x1F50:
//          break;

        default:
            if(pObdParam_p->m_uiIndex >= 0x2000)
            {   // check if forwarding object access request to AP is possible

                // check if empty ApiPdi connection handles are available
                if (ApiPdiComInstance_g.apObdParam_m[0] != NULL)
                {
                    Ret = kEplObdOutOfMemory;
                    pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
                    goto Exit;
                }
                break;
            }
            else
            {   // all remaining local PCP objects

                // TODO: introduce counter to recognize memory leaks / to much allocated memory
                // or use static storage

                // forward "pAllocObdParam" which has to be returned in callback,
                // so callback can access the Obd-access handle and SDO communication handle
                if (pObdParam_p->m_Type == kEplObdTypDomain)
                {
                    // if it is an initial segment, check if this object is already accessed
                    if (pObdParam_p->m_SegmentOffset == 0)
                    {   // inital segment

                        // history has to be completely empty for new segmented write transfer
                        // only one segmented transfer at once is allowed!
                        if (bObdSegWriteAccHistoryEmptyCnt_g < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE)
                        {
                            Ret = kEplObdOutOfMemory;
                            pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
                            goto Exit;
                        }

                        // reset object segment access counter
                        wObdSegWriteAccHistorySeqCnt_g = OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID;
                    }
                    else
                    {
                        // Don't accept following segments if transfer is not started or aborted
                        if (wObdSegWriteAccHistorySeqCnt_g == OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID)
                        {
                            Ret = kEplObdOutOfMemory;
                            pObdParam_p->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_OR_STORED;
                            goto Exit;
                        }
                    }
                }
                else
                {   // non domain object
                    // should be handled in the switch-cases above, not in the default case
                }
            break;
        } // else -> all remaining objects
    } // end of switch (pObdParam_p->m_uiIndex)

    // allocate memory for handle
    pAllocObdParam = EPL_MALLOC(sizeof (*pAllocObdParam));
    if (pAllocObdParam == NULL)
    {
        Ret = kEplObdOutOfMemory;
        pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
        goto Exit;
    }

    EPL_MEMCPY(pAllocObdParam, pObdParam_p, sizeof (*pAllocObdParam));

    // different treatment for all write objects (after handle storing)
    switch (pObdParam_p->m_uiIndex)
    {
        case 0x1010:
        //case 0x1011:
#ifdef TEST_OBD_ADOPTABLE_FINISHED_TIMERU
            TimerArg.m_EventSink = kEplEventSinkApi;
            TimerArg.m_Arg.m_pVal = pAllocObdParam;

            if(EplTimerHdl == 0)
            {   // create new timer
                Ret = EplTimeruSetTimerMs(&EplTimerHdl, 6000, TimerArg);
            }
            else
            {   // modify exisiting timer
                Ret = EplTimeruModifyTimerMs(&EplTimerHdl, 6000, TimerArg);
            }
            if(Ret != kEplSuccessful)
            {
                pObdParam_p->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_DUE_LOCAL_CONTROL;
                EPL_FREE(pAllocObdParam);
                goto Exit;
            }
#endif // TEST_OBD_ADOPTABLE_FINISHED_TIMERU
            break;

//      case 0x1F50:
//          break;

        default:
                if (pObdParam_p->m_Type == kEplObdTypDomain)
                {
                    // save object data
                    pAllocDataBuf = EPL_MALLOC(pObdParam_p->m_SegmentSize);
                    if (pAllocDataBuf == NULL)
                    {
                        Ret = kEplObdOutOfMemory;
                        pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
                        EPL_FREE(pAllocObdParam);
                        goto Exit;
                    }

                    EPL_MEMCPY(pAllocDataBuf, pObdParam_p->m_pData, pObdParam_p->m_SegmentSize);
                    pAllocObdParam->m_pData = (void*) pAllocDataBuf;

                    // save OBD access handle for Domain objects (segmented access)
                    Ret = EplAppDefObdAccSaveHdl(pAllocObdParam, &pDefObdHdl);
                    DEBUG_TRACE1(DEBUG_LVL_14, "New SDO History Empty Cnt: %d\n", bObdSegWriteAccHistoryEmptyCnt_g);
                    if (Ret != kEplSuccessful)
                    {
                        EPL_FREE(pAllocObdParam);
                        goto Exit;
                    }
                    // trigger write operation (in AppEventCb)
                    Ret = EplApiPostUserEvent((void*) pAllocObdParam);
                    if (Ret != kEplSuccessful)
                    {
                        goto Exit;
                    }
                }
                else
                {   // non domain objects
                    // should be handled in the switch-cases above, not in the default case
                }
            break;
    } /* switch (pObdParam_p->m_uiIndex) */

    // test output //TODO: delete
    //            EplAppDumpData(pObdParam_p->m_pData, pObdParam_p->m_SegmentSize);

    // adopt write access
    Ret = kEplObdAccessAdopted;
    DEBUG_TRACE0(DEBUG_LVL_14, " Adopted\n");

Exit:
    return Ret;
}

/**
********************************************************************************
\brief  pre-read checking for default object callback function

\param      pObdParam_p     pointer to object handle

\return     kEplObdAccessAdopted or kEplObdSegmentReturned
*******************************************************************************/
static tEplKernel EplAppCbDefaultObdPreRead(tEplObdParam *pObdParam_p)
{
    tEplObdParam *   pAllocObdParam = NULL; ///< pointer to allocated memory of OBD access handle
    tEplKernel       Ret = kEplSuccessful;

    // do not return kEplSuccessful in this case,
    // only error or kEplObdAccessAdopted or kEplObdSegmentReturned is allowed!

    // Note: kEplObdAccessAdopted can only be returned for expedited (non-fragmented) reads!
    // Adopted access is not yet implemented for segmented kEplObdEvPreRead.
    // Thus, kEplObdSegmentReturned has to be returned in this case! This requires immediate access to
    // the read source data right from this function.

    //TODO: block all transfers of same index/subindex which are already processing

    // verify if caller has assigned a callback function
    if (pObdParam_p->m_pfnAccessFinished == NULL)
    {
        if (pObdParam_p->m_pRemoteAddress != NULL)
        {   // remote access via SDO
            pObdParam_p->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_OR_STORED;
            Ret = kEplObdAccessViolation;
        }
        else
        {
            // ignore all other originators than SDO (for now)
            // workaround: do not return error because EplApiLinkObject() calls this function,
            // but object access is not really necessary

            /* TODO jba: if we exit here we return successfull which shouldn't be according to
               comment at beginning of function */
        }
        goto Exit;
    }

    // different pre-access verification for all read objects (previous to handle storing)
    switch (pObdParam_p->m_uiIndex)
    {
        case 0x1010:
        //case 0x1011:
            break;

        case 0x1F50:
            break;

        default:
            if(pObdParam_p->m_uiIndex >= 0x2000)
            {   // check if forwarding object access request to AP is possible

                // check if empty ApiPdi connection handles are available
                if (ApiPdiComInstance_g.apObdParam_m[0] != NULL)
                {
                    Ret = kEplObdOutOfMemory;
                    pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
                    goto Exit;
                }
                break;
            }
            else
            {   // local objects at PCP
                // should be handled in the switch-cases above, not in the default case
            }

            break;
    }

    // allocate memory for handle
    pAllocObdParam = EPL_MALLOC(sizeof (*pAllocObdParam));
    if (pAllocObdParam == NULL)
    {
        Ret = kEplObdOutOfMemory;
        pObdParam_p->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
        goto Exit;
    }

    EPL_MEMCPY(pAllocObdParam, pObdParam_p, sizeof (*pAllocObdParam));

    // different treatment for all read objects (after handle storing)
    switch (pObdParam_p->m_uiIndex)
    {
        case 0x1010:
        //case 0x1011:
#ifdef TEST_OBD_ADOPTABLE_FINISHED_TIMERU
            TimerArg.m_EventSink = kEplEventSinkApi;
            TimerArg.m_Arg.m_pVal = pAllocObdParam;

            if(EplTimerHdl == 0)
            {   // create new timer
                Ret = EplTimeruSetTimerMs(&EplTimerHdl,
                                            6000,
                                            TimerArg);
            }
            else
            {   // modify exisiting timer
                Ret = EplTimeruModifyTimerMs(&EplTimerHdl,
                                            6000,
                                            TimerArg);

            }
            if(Ret != kEplSuccessful)
            {
                pObdParam_p->m_dwAbortCode = EPL_SDOAC_DATA_NOT_TRANSF_DUE_LOCAL_CONTROL;
                EPL_FREE(pAllocObdParam);
                goto Exit;
            }
#endif // TEST_OBD_ADOPTABLE_FINISHED_TIMERU
            break;

        case 0x1F50:
            break;

        default:
                // should be handled in the switch-cases above, not in the default case
            break;
    }

    // adopt read access
    Ret = kEplObdAccessAdopted;
    DEBUG_TRACE0(DEBUG_LVL_14, "  Adopted\n");

Exit:
    return Ret;
}

/**
********************************************************************************
\brief called if object index does not exits in OBD

This default OBD access callback function shall be invoked if an index is not
present in the local OBD. If a subindex is not present, this function shall not
be called. If the access to the desired object can not be handled immediately,
kEplObdAccessAdopted has to be returned.

\param pObdParam_p   OBD access structure

\return    tEplKernel value
*******************************************************************************/
static tEplKernel  EplAppCbDefaultObdAccess(tEplObdParam MEM* pObdParam_p)
{
    tEplKernel       Ret = kEplSuccessful;

    if (pObdParam_p == NULL)
    {
        return kEplInvalidParam;
    }

    if (pObdParam_p->m_pRemoteAddress != NULL)
    {   // remote access via SDO
        // DEBUG_TRACE1(DEBUG_LVL_14, "Remote OBD access from %d\n", pObdParam_p->m_pRemoteAddress->m_uiNodeId);
    }

    // return error for all non existing objects
    switch (pObdParam_p->m_uiIndex)
    {

//        case 0x1010:
//            switch (pObdParam_p->m_uiSubIndex)
//            {
//                case 0x01:
//                    break;
//                default:
//                    pObdParam_p->m_dwAbortCode = EPL_SDOAC_SUB_INDEX_NOT_EXIST;
//                    Ret = kEplObdSubindexNotExist;
//                    goto Exit;
//            }
//            break;

//        case 0x1011:
//            switch (pObdParam_p->m_uiSubIndex)
//            {
//                case 0x01:
//                    break;
//
//                default:
//                    pObdParam_p->m_dwAbortCode = EPL_SDOAC_SUB_INDEX_NOT_EXIST;
//                    Ret = kEplObdSubindexNotExist;
//                    goto Exit;
//            }
//            break;

        case 0x1F50:
            switch (pObdParam_p->m_uiSubIndex)
            {
                case 0x01:
                    break;
                default:
                    pObdParam_p->m_dwAbortCode = EPL_SDOAC_SUB_INDEX_NOT_EXIST;
                    Ret = kEplObdSubindexNotExist;
                    goto Exit;
            }
            break;

        default:
            // Tell calling function that all objects
            // >= 0x2000 exist per default.
            // The actual verification will take place
            // with the write or read access.

            if(pObdParam_p->m_uiIndex < 0x2000)
            {   // remaining PCP objects do not exist
                pObdParam_p->m_dwAbortCode = EPL_SDOAC_OBJECT_NOT_EXIST;
                Ret = kEplObdIndexNotExist;
                goto Exit;
            }
            break;
    } /* switch (pObdParam_p->m_uiIndex) */

    DEBUG_TRACE4(DEBUG_LVL_14, "EplAppCbDefaultObdAccess(0x%04X/%u Ev=%X Size=%u\n",
            pObdParam_p->m_uiIndex, pObdParam_p->m_uiSubIndex,
            pObdParam_p->m_ObdEvent,
            pObdParam_p->m_SegmentSize);

//    printf("EplAppCbDefaultObdAccess(0x%04X/%u Ev=%X pData=%p Off=%u Size=%u"
//           " ObjSize=%u TransSize=%u Acc=%X Typ=%X)\n",
//        pObdParam_p->m_uiIndex, pObdParam_p->m_uiSubIndex,
//        pObdParam_p->m_ObdEvent,
//        pObdParam_p->m_pData, pObdParam_p->m_SegmentOffset, pObdParam_p->m_SegmentSize,
//        pObdParam_p->m_ObjSize, pObdParam_p->m_TransferSize, pObdParam_p->m_Access, pObdParam_p->m_Type);

    switch (pObdParam_p->m_ObdEvent)
    {
        case kEplObdEvCheckExist:
            EplAppCbDefaultObdAssignDatatype(pObdParam_p);
            break;

        case kEplObdEvInitWriteLe:
            Ret = EplAppCbDefaultObdInitWriteLe(pObdParam_p);
            break;

        case kEplObdEvPreRead:
            Ret = EplAppCbDefaultObdPreRead(pObdParam_p);
            break;

        default:
            break;
    }

Exit:
    return Ret;
}

/**
********************************************************************************
\brief searches for free storage of OBD access handle and saves it

\param pObdParam_p     pointer to OBD handle
\param ppDefHdl_p      pointer to store pointer of segmented transfer handle

\retval kEplSuccessful if element was successfully assigned
\retval kEplObdOutOfMemory if no free element is left
\retval kEplApiInvalidParam if wrong parameter passed to this function
*******************************************************************************/
static tEplKernel EplAppDefObdAccSaveHdl(tEplObdParam * pObdParam_p, tDefObdAccHdl **ppDefHdl_p)
{
    tDefObdAccHdl * pObdDefAccHdl = NULL;
    BYTE bArrayNum;                 ///< loop counter and array element

    // check for wrong parameter values
    if (pObdParam_p == NULL)
    {
        return kEplApiInvalidParam;
    }

    pObdDefAccHdl = aObdDefAccHdl_l;

    for (bArrayNum = 0; bArrayNum < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE; bArrayNum++, pObdDefAccHdl++)
    {
        if (pObdDefAccHdl->m_Status == kEplObdDefAccHdlEmpty)
        {
            *ppDefHdl_p = pObdDefAccHdl;

            // free storage found -> assign OBD access handle
            pObdDefAccHdl->m_pObdParam = pObdParam_p;
            pObdDefAccHdl->m_Status = kEplObdDefAccHdlWaitProcessingInit;
            pObdDefAccHdl->m_wSeqCnt = ++wObdSegWriteAccHistorySeqCnt_g;
            bObdSegWriteAccHistoryEmptyCnt_g--;

            // check if segmented write history is full (flow control for SDO)
            if (bObdSegWriteAccHistoryEmptyCnt_g < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE - OBD_DEFAULT_SEG_WRITE_HISTORY_ACK_FINISHED_THLD)
            {
                // prevent SDO from ack the last received frame
                EplSdoAsySeqAppFlowControl(TRUE, TRUE);
            }
            return kEplSuccessful;
        }
    }

    // no free storage found if we reach here
    pObdDefAccHdl->m_pObdParam->m_dwAbortCode = EPL_SDOAC_OUT_OF_MEMORY;
    return kEplObdOutOfMemory;
}

/**
********************************************************************************
\brief searches for a segmented OBD access handle with a specific status

This function searches for a segmented OBD access handle. it searches for index,
subindex and status. If fSearchOldestEntry is TRUE the oldest entry in history
is searched.

\param wIndex_p             index of searched element
\param wSubIndex_p          subindex of searched element
\param ReqStatus_p          requested status of handle
\param fSearchOldestEntry   if TRUE, the oldest object access will be returned
\param ppObdParam_p         IN:  caller provides  target pointer address
                            OUT: address of found element or NULL

\retval kEplSuccessful             if element was found
\retval kEplObdVarEntryNotExist    if no element was found
\retval kEplApiInvalidParam        if wrong parameter passed to this function
*******************************************************************************/
static tEplKernel EplAppDefObdAccGetStatusObdHdl(WORD wIndex_p,
        WORD wSubIndex_p, tEplObdDefAccStatus ReqStatus_p, BOOL fSearchOldest_p,
        tDefObdAccHdl **ppDefObdAccHdl_p)
{
    tEplKernel      Ret;
    tDefObdAccHdl * pObdDefAccHdl = NULL;
    BYTE            bArrayNum;              ///< loop counter and array element

    // check for wrong parameter values
    if (ppDefObdAccHdl_p == NULL)
    {
        return kEplApiInvalidParam;
    }

    Ret = kEplObdVarEntryNotExist;
    *ppDefObdAccHdl_p = NULL;
    pObdDefAccHdl = aObdDefAccHdl_l;

    for (bArrayNum = 0; bArrayNum < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE;
         bArrayNum++, pObdDefAccHdl++)
    {
        /* check for a valid handle */
        if (pObdDefAccHdl->m_pObdParam == NULL)
        {
            continue;
        }

        // search for index, subindex and status
        if ((pObdDefAccHdl->m_pObdParam->m_uiIndex == wIndex_p)        &&
            (pObdDefAccHdl->m_pObdParam->m_uiSubIndex == wSubIndex_p) &&
            (pObdDefAccHdl->m_wSeqCnt != OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID) &&
            (pObdDefAccHdl->m_Status == ReqStatus_p))
        {
            /* handle found */
            /* check if we have already found another handle */
            if (*ppDefObdAccHdl_p == NULL)
            {
                /* It is the first found handle, therefore save it */
                *ppDefObdAccHdl_p = pObdDefAccHdl;
                Ret = kEplSuccessful;
                if (!fSearchOldest_p)
                {
                    break;
                }
            }
            else
            {
                /* we found a handle but it is not the first one. We compare the
                 * sequence counter and if it is older we store it. */
                if ((*ppDefObdAccHdl_p)->m_wSeqCnt > pObdDefAccHdl->m_wSeqCnt)
                {
                    *ppDefObdAccHdl_p = pObdDefAccHdl;
                }
            }
        }
    }
    return Ret;
}

/**
********************************************************************************
 \brief searches for a segmented OBD access handle

This function searches for a segmented OBD access handle. It searches the one
which contains the specified OBD handle pObdAccParam_p.

\param pObdAccParam_p   pointer of object dictionary access to be searched for;
\param ppObdParam_p     IN:  caller provides  target pointer address
                        OUT: address of found element or NULL

\retval kEplSuccessful             if element was found
\retval kEplObdVarEntryNotExist    if no element was found
\retval kEplApiInvalidParam        if wrong parameter passed to this function
*******************************************************************************/
static tEplKernel EplAppDefObdAccGetObdHdl(tEplObdParam * pObdAccParam_p,
                                            tDefObdAccHdl **ppDefObdAccHdl_p)
{
    tEplKernel      Ret;
    tDefObdAccHdl * pObdDefAccHdl = NULL;
    BYTE            bArrayNum;                 ///< loop counter and array element

    // check for wrong parameter values
    if (ppDefObdAccHdl_p == NULL)
    {
        return kEplApiInvalidParam;
    }

    Ret = kEplObdVarEntryNotExist;
    *ppDefObdAccHdl_p = NULL;
    pObdDefAccHdl = aObdDefAccHdl_l;

    for (bArrayNum = 0; bArrayNum < OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE;
         bArrayNum++, pObdDefAccHdl++)
    {
        if (pObdAccParam_p == pObdDefAccHdl->m_pObdParam)
        {
            // assigned found handle
             *ppDefObdAccHdl_p = pObdDefAccHdl;
             Ret = kEplSuccessful;
             break;
        }
    }
    return Ret;
}

/**
********************************************************************************
\brief abort callback function

EplAppDefObdAccWriteSegmentedAbortCb() will be called if a segmented write
transfer should be aborted.

\param  pHandle         pointer to default object access handle

\returns OK, or ERROR if event posting failed
*******************************************************************************/
int EplAppDefObdAccWriteSegmentedAbortCb(void * pHandle)
{
    int                 iRet = OK;
    tDefObdAccHdl *     pDefObdHdl;

    pDefObdHdl = (tDefObdAccHdl *)pHandle;

    // Disable flow control
    EplSdoAsySeqAppFlowControl(0, FALSE);

    // Abort all not empty handles of segmented transfer
    EplAppDefObdAccCleanupHistory();

    DEBUG_TRACE1 (DEBUG_LVL_15, "<--- Abort callback Handle:%p!\n\n",
            pDefObdHdl->m_pObdParam);

    return iRet;
}

/**
********************************************************************************
\brief segment finished callback function

EplAppDefObdAccWriteSegmentedFinishCb() will be called if a segmented write
transfer is finished.

\param  pHandle         pointer to OBD handle

\return OK or ERROR if something went wrong
*******************************************************************************/
int EplAppDefObdAccWriteSegmentedFinishCb(void * pHandle)
{
    int                 iRet = OK;
    tDefObdAccHdl *     pDefObdHdl = (tDefObdAccHdl *)pHandle;
    tDefObdAccHdl *     pFoundHdl;
    tEplKernel          EplRet = kEplSuccessful;
    WORD                wIndex;
    WORD                wSubIndex;

    DEBUG_TRACE3 (DEBUG_LVL_14, "%s() OBD ACC Hdl:%p cnt processed: %d\n", __func__,
                 pDefObdHdl->m_pObdParam, pDefObdHdl->m_wSeqCnt);

    pDefObdHdl->m_Status = kEplObdDefAccHdlProcessingFinished;

    wIndex = pDefObdHdl->m_pObdParam->m_uiIndex;
    wSubIndex = pDefObdHdl->m_pObdParam->m_uiSubIndex;

    // signal "OBD access finished" to originator

    // this triggers an Ack of the last received SDO sequence in case of remote access
    EplRet = EplAppDefObdAccFinished(&pDefObdHdl->m_pObdParam);

    // correct history status
    pDefObdHdl->m_Status = kEplObdDefAccHdlEmpty;
    pDefObdHdl->m_wSeqCnt = OBD_DEFAULT_SEG_WRITE_ACC_CNT_INVALID;
    bObdSegWriteAccHistoryEmptyCnt_g++;
    DEBUG_TRACE1(DEBUG_LVL_14, "New SDO History Empty Cnt: %d\n",
                 bObdSegWriteAccHistoryEmptyCnt_g);

    if (EplRet != kEplSuccessful)
    {
        DEBUG_TRACE1 (DEBUG_LVL_ERROR, "%s() EplAppDefObdAccFinished failed!\n",
                      __func__);
        goto Exit;
    }

    // check if segmented write history is empty enough to disable flow control
    if (bObdSegWriteAccHistoryEmptyCnt_g >=
        OBD_DEFAULT_SEG_WRITE_HISTORY_SIZE - OBD_DEFAULT_SEG_WRITE_HISTORY_ACK_FINISHED_THLD)
    {
        // do ordinary SDO sequence processing / reset flow control manipulation
        EplSdoAsySeqAppFlowControl(0, FALSE);
    }

    EplRet = EplAppDefObdAccGetStatusObdHdl(wIndex, wSubIndex,
            kEplObdDefAccHdlWaitProcessingQueue, TRUE, &pFoundHdl);
    if (EplRet == kEplSuccessful)
    {
        // handle found
        DEBUG_TRACE3 (DEBUG_LVL_14, "%s() RePost Event: Hdl:%p SeqNr: %d\n",
                __func__,
                pFoundHdl->m_pObdParam,
                pFoundHdl->m_wSeqCnt);
        EplRet = EplApiPostUserEvent((void*) pFoundHdl->m_pObdParam);
        if (EplRet != kEplSuccessful)
        {
            DEBUG_TRACE1 (DEBUG_LVL_ERROR, "%s() Post user event failed!\n",
                                  __func__);
            goto Exit;
        }
    }
    else
    {
        DEBUG_TRACE1(DEBUG_LVL_14, "%s() Nothing to post!\n", __func__);
        EplRet = kEplSuccessful; // nothing to post, thats fine
    }

Exit:
    DEBUG_TRACE0 (DEBUG_LVL_15, "<--- Segment finished callback!\n\n");
    if (EplRet != kEplSuccessful)
    {
        iRet = ERROR;
    }
    return iRet;
}

/**
********************************************************************************
\brief     write to domain object which is not in object dictionary

This function writes to an object which does not exist in the local object
dictionary by using segmented access (to domain object)

\param  pDefObdAccHdl_p             pointer to default OBD access for segmented
                                    access
\param  pfnSegmentFinishedCb_p      pointer to finished callback function
\param  pfnSegmentAbortCb_p         pointer to abort callback function

\retval tEplKernel value
*******************************************************************************/
static tEplKernel EplAppDefObdAccWriteObdSegmented(tDefObdAccHdl * pDefObdAccHdl_p,
        void * pfnSegmentFinishedCb_p, void * pfnSegmentAbortCb_p)
{
    tEplKernel Ret = kEplSuccessful;
    int iRet = OK;

    if (pDefObdAccHdl_p == NULL)
    {
        return kEplApiInvalidParam;
    }

    pDefObdAccHdl_p->m_Status = kEplObdDefAccHdlInUse;

    switch (pDefObdAccHdl_p->m_pObdParam->m_uiIndex)
    {
        case 0x1F50:
            switch (pDefObdAccHdl_p->m_pObdParam->m_uiSubIndex)
            {
                case 0x01:
                    iRet = updateFirmware(
                              pDefObdAccHdl_p->m_pObdParam->m_SegmentOffset,
                              pDefObdAccHdl_p->m_pObdParam->m_SegmentSize,
                              (void*) pDefObdAccHdl_p->m_pObdParam->m_pData,
                              pfnSegmentAbortCb_p, pfnSegmentFinishedCb_p,
                              (void *)pDefObdAccHdl_p);

                    if (iRet == kEplSdoComTransferRunning)
                    {
                        EplSdoAsySeqAppFlowControl(TRUE, TRUE);
                    }
                    if (iRet == ERROR)
                    {   //update operation went wrong
                        Ret = kEplObdAccessViolation;
                    }
                    break;

                default:
                    Ret = kEplObdSubindexNotExist;
                    break;
            }
            break;

        default:
            break;
    }

    return Ret;
}

/**
********************************************************************************
\brief    reboot the CN

This function reboots the CN. It checks if the FPGA configuration of the running
firmware and the user image is different. If it is the same version it only
performs a PCP software reset. If it is differnt it triggers a complete
FPGA reconfiguration.
*******************************************************************************/
void rebootCN(void)
{
    UINT32  uiFpgaConfigVersion;

    /* read FPGA configuration version of user image */
    getSwVersions(CONFIG_USER_IIB_FLASH_ADRS, &uiFpgaConfigVersion, NULL, NULL);

    /* if the FPGA configuration version changed since boot-up, we have to do
     * a complete FPGA reconfiguration. */
    if (uiFpgaConfigVersion != uiFpgaConfigVersion_g)
    {
        DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "FPGA Configuration of CN ...\n");
        //usleep(4000000);

        // trigger FPGA reconfiguration
        // remark: if we are in user image, this command will trigger a
        //         reconfiguration of the factory image regardless of its argument!
        FpgaCfg_reloadFromFlash(CONFIG_FACTORY_IMAGE_FLASH_ADRS); // restart factory image
    }
    else
    {   // only reset the PCP software

        // TODO: verify user image if only PCP SW was updated (at bootup or now?)!

        DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "PCP Software Reset of CN ...\n");
        //usleep(4000000);

        FpgaCfg_resetProcessor();
    }

}

/**
********************************************************************************
\brief     get application software date/time of current image

This function reads the application software date and time of the currently
used firmware image.

\param  pUiApplicationSwDate_p      pointer to store application software date
\param  pUiApplicationSwTime_p      pointer to store application software time

\return OK, or ERROR if data couldn't be read
*******************************************************************************/
static tFwRet getImageApplicationSwDateTime(UINT32 *pUiApplicationSwDate_p,
                                  UINT32 *pUiApplicationSwTime_p)
{
    UINT32      uiIibAdrs;

    uiIibAdrs = fIsUserImage_g ? CONFIG_USER_IIB_FLASH_ADRS
                               : CONFIG_FACTORY_IIB_FLASH_ADRS;
    return getApplicationSwDateTime(uiIibAdrs, pUiApplicationSwDate_p,
                                    pUiApplicationSwTime_p);
}

/**
********************************************************************************
\brief     get application software date/time of current image

This function read the software versions of the currently used firmware image.
The version is store at the specific pointer if it is not NULL.

\param pUiFpgaConfigVersion_p   pointer to store FPGA configuration version
\param pUiPcpSwVersion_p        pointer to store the PCP software version
\param pUiApSwVersion_p         pointer to store the AP software version

\return OK, or ERROR if data couldn't be read
*******************************************************************************/
tFwRet getImageSwVersions(UINT32 *pUiFpgaConfigVersion_p, UINT32 *pUiPcpSwVersion_p,
                       UINT32 *pUiApSwVersion_p)
{
    UINT32      uiIibAdrs;

    uiIibAdrs = fIsUserImage_g ? CONFIG_USER_IIB_FLASH_ADRS
                               : CONFIG_FACTORY_IIB_FLASH_ADRS;

    return getSwVersions(uiIibAdrs, pUiFpgaConfigVersion_p, pUiPcpSwVersion_p,
                         pUiApSwVersion_p);
}

/**
********************************************************************************
\brief    main function of digital I/O interface

*******************************************************************************/
int main (void)
{
    BYTE    bNodeId;

    tFwRet FwRetVal;

    SysComp_initPeripheral();

    switch (FpgaCfg_handleReconfig())
    {
        case kFgpaCfgFactoryImageLoadedNoUserImagePresent:
        {
            // user image reconfiguration failed
            DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "Factory image loaded.\n");
            fIsUserImage_g = FALSE;

            FwRetVal = checkFwImage(CONFIG_FACTORY_IMAGE_FLASH_ADRS,
                                    CONFIG_FACTORY_IIB_FLASH_ADRS,
                                    CONFIG_USER_IIB_VERSION);
            if(FwRetVal != kFwRetSuccessful)
            {
                // factory image was loaded, but has invalid IIB
                // checkFwImage() prints error, don't do anything
                // else here for now
                DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: checkFwImage() of factory image failed with 0x%x\n", FwRetVal);
            }
            break;
        }

        case kFpgaCfgUserImageLoadedWatchdogDisabled:
        {
            DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "User image loaded.\n");

#ifdef CONFIG_IIB_IS_PRESENT
            FwRetVal = checkFwImage(CONFIG_USER_IMAGE_FLASH_ADRS,
                                    CONFIG_USER_IIB_FLASH_ADRS,
                                    CONFIG_USER_IIB_VERSION);
            if(FwRetVal != kFwRetSuccessful)
            {
                DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: checkFwImage() of user image failed with 0x%x\n", FwRetVal);

                usleep(5000000); // wait 5 seconds

                // user image was loaded, but has invalid IIB
                // -> reset to factory image
                FpgaCfg_reloadFromFlash(CONFIG_FACTORY_IMAGE_FLASH_ADRS);
            }
#endif // CONFIG_IIB_IS_PRESENT

            fIsUserImage_g = TRUE;
#ifdef LCD_BASE
            SysComp_LcdClear();
            SysComp_LcdSetText("USER");
#endif
            break;
        }

        case kFpgaCfgUserImageLoadedWatchdogEnabled:
        {
            DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "User image loaded.\n");

#ifdef CONFIG_IIB_IS_PRESENT
            FwRetVal = checkFwImage(CONFIG_USER_IMAGE_FLASH_ADRS,
                                    CONFIG_USER_IIB_FLASH_ADRS,
                                    CONFIG_USER_IIB_VERSION);
            if(FwRetVal != kFwRetSuccessful)
            {
                DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: checkFwImage() of user image failed with 0x%x\n", FwRetVal);

                usleep(5000000); // wait 5 seconds

                // user image was loaded, but has invalid IIB
                // -> reset to factory image
                FpgaCfg_reloadFromFlash(CONFIG_FACTORY_IMAGE_FLASH_ADRS);
            }
#endif // CONFIG_IIB_IS_PRESENT

            // watchdog timer has to be reset periodically
            //FpgaCfg_resetWatchdogTimer(); // do this periodically!
            fIsUserImage_g = TRUE;
            break;
        }

        case kFgpaCfgWrongSystemID:
        {
            DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "Fatal error after booting! Reset to Factory Image!\n");
            usleep(5000000); // wait 5 seconds

            // reset to factory image
            FpgaCfg_reloadFromFlash(CONFIG_FACTORY_IMAGE_FLASH_ADRS);

            goto exit; // fatal error
            break;
        }

        default:
        {
#ifdef CONFIG_USER_IMAGE_IN_FLASH
            DEBUG_TRACE0(DEBUG_LVL_ALWAYS, "Fatal error after booting! Reset to Factory Image!\n");
            usleep(5000000); // wait 5 seconds

            // reset to factory image
            FpgaCfg_reloadFromFlash(CONFIG_FACTORY_IMAGE_FLASH_ADRS);
            goto exit; // this is fatal error only, if image was loaded from flash
#endif
            break;
        }
    }
#ifdef LCD_BASE
    SysComp_LcdTest();
#endif

    PRINTF0("\n\nDigital I/O interface is running...\n");
    PRINTF0("starting openPowerlink...\n\n");

    if((bNodeId = SysComp_getNodeId()) == 0)
    {
        bNodeId = NODEID;
    }

#ifdef LCD_BASE
    SysComp_LcdPrintNodeInfo(fIsUserImage_g, bNodeId);
#endif

    while (1) {
        if (openPowerlink(bNodeId) != 0) {
            PRINTF0("openPowerlink was shut down because of an error\n");
            break;
        } else {
            PRINTF0("openPowerlink was shut down, restart...\n\n");
        }
        /* wait some time until we restart the stack */
        usleep(1000000);
    }

    PRINTF1("shut down processor...\n%c", 4);

    SysComp_freeProcessorCache();

exit:
    return 0;
}

/**
********************************************************************************
\brief    main function of digital I/O interface

*******************************************************************************/
int openPowerlink(BYTE bNodeId_p)
{
    DWORD                       ip = IP_ADDR; // ip address

    const BYTE                  abMacAddr[] = {MAC_ADDR};
    static tEplApiInitParam     EplApiInitParam; //epl init parameter
    // needed for process var
    tEplObdSize                 ObdSize;
    tEplKernel                  EplRet;
    unsigned int                uiVarEntries;
    UINT32                      uiApplicationSwDate = 0;
    UINT32                      uiApplicationSwTime = 0;
    tFwRet                      FwRetVal;

    fShutdown_l = FALSE;

    /* initialize port configuration */
    InitPortConfiguration(portIsOutput);

    /* Read application software date and time */
    FwRetVal = getImageApplicationSwDateTime(&uiApplicationSwDate, &uiApplicationSwTime);
    if (FwRetVal != kFwRetSuccessful)
    {
        DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: getImageApplicationSwDateTime() failed with 0x%x\n", FwRetVal);
    }

    /* Read FPGA configuration version of current used image */
    FwRetVal = getImageSwVersions(&uiFpgaConfigVersion_g, NULL, NULL);
    if (FwRetVal != kFwRetSuccessful)
    {
        DEBUG_TRACE1(DEBUG_LVL_ERROR, "ERROR: getImageSwVersions() failed with 0x%x\n", FwRetVal);
    }

    /* initialize firmware update */
    initFirmwareUpdate(CONFIG_IDENT_PRODUCT_CODE, CONFIG_IDENT_REVISION);

    /* setup the POWERLINK stack */

    // calc the IP address with the nodeid
    ip &= 0xFFFFFF00; //dump the last byte
    ip |= bNodeId_p; // and mask it with the node id

    // set EPL init parameters
    EplApiInitParam.m_uiSizeOfStruct = sizeof (EplApiInitParam);
    EPL_MEMCPY(EplApiInitParam.m_abMacAddress, abMacAddr, sizeof(EplApiInitParam.m_abMacAddress));
    EplApiInitParam.m_uiNodeId = bNodeId_p;
    EplApiInitParam.m_dwIpAddress = ip;
    EplApiInitParam.m_uiIsochrTxMaxPayload = CONFIG_ISOCHR_TX_MAX_PAYLOAD;
    EplApiInitParam.m_uiIsochrRxMaxPayload = CONFIG_ISOCHR_RX_MAX_PAYLOAD;
    EplApiInitParam.m_dwPresMaxLatency = 2000;
    EplApiInitParam.m_dwAsndMaxLatency = 2000;
    EplApiInitParam.m_fAsyncOnly = FALSE;
    EplApiInitParam.m_dwFeatureFlags = -1;
    EplApiInitParam.m_dwCycleLen = CYCLE_LEN;
    EplApiInitParam.m_uiPreqActPayloadLimit = 36;
    EplApiInitParam.m_uiPresActPayloadLimit = 36;
    EplApiInitParam.m_uiMultiplCycleCnt = 0;
    EplApiInitParam.m_uiAsyncMtu = 300;
    EplApiInitParam.m_uiPrescaler = 2;
    EplApiInitParam.m_dwLossOfFrameTolerance = 5000000;
    EplApiInitParam.m_dwAsyncSlotTimeout = 3000000;
    EplApiInitParam.m_dwWaitSocPreq = 0;
    EplApiInitParam.m_dwDeviceType = -1;
    EplApiInitParam.m_dwVendorId = CONFIG_IDENT_VENDOR_ID;
    EplApiInitParam.m_dwProductCode = CONFIG_IDENT_PRODUCT_CODE;
    EplApiInitParam.m_dwRevisionNumber = CONFIG_IDENT_REVISION;
    EplApiInitParam.m_dwSerialNumber = CONFIG_IDENT_SERIAL_NUMBER;
    EplApiInitParam.m_dwApplicationSwDate = uiApplicationSwDate;
    EplApiInitParam.m_dwApplicationSwTime = uiApplicationSwTime;
    EplApiInitParam.m_dwSubnetMask = SUBNET_MASK;
    EplApiInitParam.m_dwDefaultGateway = 0;
    EplApiInitParam.m_pfnCbEvent = AppCbEvent;
    EplApiInitParam.m_pfnCbSync  = AppCbSync;
    EplApiInitParam.m_pfnObdInitRam = EplObdInitRam;
    EplApiInitParam.m_pfnDefaultObdCallback = EplAppCbDefaultObdAccess; // called if objects do not exist in local OBD
    EplApiInitParam.m_pfnRebootCb = rebootCN;

    PRINTF1("\nNode ID is set to: %d\n", EplApiInitParam.m_uiNodeId);

    /************************/
    /* initialize POWERLINK stack */
    PRINTF0("init POWERLINK stack:\n");
    EplRet = EplApiInitialize(&EplApiInitParam);
    if(EplRet != kEplSuccessful) {
        PRINTF1("init POWERLINK Stack... error %X\n\n", EplRet);
        goto Exit;
    }
    PRINTF0("init POWERLINK Stack...ok\n\n");

    /**********************************************************/
    /* link process variables used by CN to object dictionary */
    PRINTF0("linking process vars:\n");



    //MANNI
    ObdSize = sizeof(FM_Control[0]);
    uiVarEntries = 2;
    EplRet = EplApiLinkObject(0x3000, FM_Control, &uiVarEntries, &ObdSize, 0x01);
    if (EplRet != kEplSuccessful)
    {
        printf("linking FM vars... error\n\n");
        goto ExitShutdown;
    }




    ObdSize = sizeof(digitalIn[0]);
    uiVarEntries = 4;
    EplRet = EplApiLinkObject(0x6000, digitalIn, &uiVarEntries, &ObdSize, 0x01);
    if (EplRet != kEplSuccessful)
    {
        printf("linking process vars... error\n\n");
        goto ExitShutdown;
    }

    ObdSize = sizeof(digitalOut[0]);
    uiVarEntries = 4;
    EplRet = EplApiLinkObject(0x6200, digitalOut, &uiVarEntries, &ObdSize, 0x01);
    if (EplRet != kEplSuccessful)
    {
        printf("linking process vars... error\n\n");
        goto ExitShutdown;
    }

    PRINTF0("linking process vars... ok\n\n");

    // start the POWERLINK stack
    EplRet = EplApiExecNmtCommand(kEplNmtEventSwReset);
    if (EplRet != kEplSuccessful) {
        goto ExitShutdown;
    }

    /*Start POWERLINK Stack*/
    PRINTF0("start POWERLINK Stack... ok\n\n");

    PRINTF0("Digital I/O interface with openPowerlink is ready!\n\n");

#ifdef STATUS_LEDS_BASE
    SysComp_setPowerlinkStatus(0xff);
#endif

    SysComp_enableInterrupts();

    while(1)
    {
        EplApiProcess();
        updateFirmwarePeriodic();               // periodically call firmware update state machine
        if (fShutdown_l == TRUE)
            break;
    }

ExitShutdown:
    PRINTF0("Shutdown EPL Stack\n");
    EplApiShutdown(); //shutdown node

Exit:
    return EplRet;
}

/**
********************************************************************************
\brief    event callback function called by EPL API layer

AppCbEvent() is the event callback function called by EPL API layer within
the user part (low priority).


\param    EventType_p             event type (IN)
\param    pEventArg_p             pointer to union, which describes the event in
                                detail (IN)
\param    pUserArg_p              user specific argument

\return error code (tEplKernel)
\retval    kEplSuccessful        no error
\retval    kEplReject             reject further processing
\retval    otherwise             post error event to API layer
*******************************************************************************/
tEplKernel PUBLIC AppCbEvent(tEplApiEventType EventType_p,
                             tEplApiEventArg* pEventArg_p, void GENERIC* pUserArg_p)
{
    tEplKernel          EplRet = kEplSuccessful;
    BYTE                bPwlState;

    // check if NMT_GS_OFF is reached
    switch (EventType_p)
    {
        case kEplApiEventNmtStateChange:
        {
#ifdef LCD_BASE
            SysComp_LcdPrintState(pEventArg_p->m_NmtStateChange.m_NewNmtState);
#endif

#ifdef LATCHED_IOPORT_CFG
            if (pEventArg_p->m_NmtStateChange.m_NewNmtState != kEplNmtCsOperational)
            {
                bPwlState = 0x0;
                memcpy(LATCHED_IOPORT_CFG+3,(BYTE *)&bPwlState,1);    ///< Set PortIO operational pin to low
            } else {
                /* reached operational state */
                bPwlState = 0x80;
                memcpy(LATCHED_IOPORT_CFG+3,(BYTE *)&bPwlState,1);    ///< Set PortIO operational pin to high
            }
#endif //LATCHED_IOPORT_CFG

            switch (pEventArg_p->m_NmtStateChange.m_NewNmtState)
            {
                case kEplNmtGsOff:
                {   // NMT state machine was shut down,
                    // because of critical EPL stack error
                    // -> also shut down EplApiProcess() and main()
                    EplRet = kEplShutdown;
                    fShutdown_l = TRUE;

                    PRINTF2("%s(kEplNmtGsOff) originating event = 0x%X\n", __func__, pEventArg_p->m_NmtStateChange.m_NmtEvent);
                    break;
                }

                case kEplNmtGsInitialising:
                case kEplNmtGsResetApplication:
                case kEplNmtGsResetConfiguration:
                case kEplNmtCsPreOperational1:
                case kEplNmtCsBasicEthernet:
                case kEplNmtMsBasicEthernet:
                {
                    PRINTF3("%s(0x%X) originating event = 0x%X\n",
                            __func__,
                            pEventArg_p->m_NmtStateChange.m_NewNmtState,
                            pEventArg_p->m_NmtStateChange.m_NmtEvent);
                    break;
                }

                case kEplNmtGsResetCommunication:
                {
                BYTE    bNodeId = 0xF0;
                DWORD   dwNodeAssignment = EPL_NODEASSIGN_NODE_EXISTS;

                    PRINTF3("%s(0x%X) originating event = 0x%X\n",
                            __func__,
                            pEventArg_p->m_NmtStateChange.m_NewNmtState,
                            pEventArg_p->m_NmtStateChange.m_NmtEvent);

                    // reset flow control manipulation
                    EplSdoAsySeqAppFlowControl(FALSE, FALSE);

                    // clean all default OBD accesses
                    EplAppDefObdAccCleanupAllPending();

                    EplRet = EplApiWriteLocalObject(0x1F81, bNodeId, &dwNodeAssignment, sizeof (dwNodeAssignment));
                    if (EplRet != kEplSuccessful)
                    {
                        goto Exit;
                    }

                    break;
                }

                case kEplNmtMsNotActive:
                    break;
                case kEplNmtCsNotActive:
                    break;
                case kEplNmtCsOperational:
                    break;
                case kEplNmtMsOperational:
                    break;

                default:
                {
                    break;
                }
            }

            break;
        }

        case kEplApiEventCriticalError:
        {
            // set error LED
#ifdef STATUS_LEDS_BASE
            SysComp_setPowerlinkStatus(0x2);
#endif
            // fall through
        }
        case kEplApiEventWarning:
        {   // error or warning occured within the stack or the application
            // on error the API layer stops the NMT state machine
            PRINTF3("%s(Err/Warn): Source=%02X EplError=0x%03X",
                    __func__,
                    pEventArg_p->m_InternalError.m_EventSource,
                    pEventArg_p->m_InternalError.m_EplError);
            // check additional argument
            switch (pEventArg_p->m_InternalError.m_EventSource)
            {
                case kEplEventSourceEventk:
                case kEplEventSourceEventu:
                {   // error occured within event processing
                    // either in kernel or in user part
                    PRINTF1(" OrgSource=%02X\n", pEventArg_p->m_InternalError.m_Arg.m_EventSource);
                    break;
                }

                case kEplEventSourceDllk:
                {   // error occured within the data link layer (e.g. interrupt processing)
                    // the DWORD argument contains the DLL state and the NMT event
                    PRINTF1(" val=%lX\n", pEventArg_p->m_InternalError.m_Arg.m_dwArg);
                    break;
                }

                default:
                {
                    PRINTF0("\n");
                    break;
                }
            }
            break;
        }

        case kEplApiEventLed:
        {   // status or error LED shall be changed
#ifdef STATUS_LEDS_BASE
            switch (pEventArg_p->m_Led.m_LedType)
            {
                case kEplLedTypeStatus:
                {
                    if (pEventArg_p->m_Led.m_fOn != FALSE)
                    {
                        SysComp_resetPowerlinkStatus(0x1);
                    }
                    else
                    {
                        SysComp_setPowerlinkStatus(0x1);
                    }
                    break;
                }
                case kEplLedTypeError:
                {
                    if (pEventArg_p->m_Led.m_fOn != FALSE)
                    {
                        SysComp_resetPowerlinkStatus(0x2);
                    }
                    else
                    {
                        SysComp_setPowerlinkStatus(0x2);
                    }
                    break;
                }
                default:
                    break;
            }
#endif
            break;
        }

        case kEplApiEventUserDef:
        {   // this case is assumed to handle only default OBD accesses

            EplRet = EplAppHandleUserEvent(pEventArg_p);
            break;
        }

        default:
            break;
    }

Exit:
    return EplRet;
}

/**
********************************************************************************
\brief    sync event callback function called by event module

AppCbSync() implements the event callback function called by event module
within kernel part (high priority). This function sets the outputs, reads the
inputs and runs the control loop.

\return    error code (tEplKernel)

\retval    kEplSuccessful            no error
\retval    otherwise                post error event to API layer
*******************************************************************************/
tEplKernel PUBLIC AppCbSync(void)
{
    tEplKernel         EplRet = kEplSuccessful;
    register int    iCnt;
    DWORD            ports; //<<< 4 byte input or output ports
    DWORD*            ulDigInputs = LATCHED_IOPORT_BASE;
    DWORD*            ulDigOutputs = LATCHED_IOPORT_BASE;

    /* read digital input ports */
    ports = AmiGetDwordFromLe((BYTE*) ulDigInputs);;

    for (iCnt = 0; iCnt <= 3; iCnt++)
    {

        if (portIsOutput[iCnt])
        {
            /* configured as output -> overwrite invalid input values with RPDO mapped variables */
            ports = (ports & ~(0xff << (iCnt * 8))) | (digitalOut[iCnt] << (iCnt * 8));
        }
        else
        {
            /* configured as input -> store in TPDO mapped variable */
            //digitalIn[iCnt] = (ports >> (iCnt * 8)) & 0xff;
        }
    }

    /* write digital output ports */
    AmiSetDwordToLe((BYTE*)ulDigOutputs, ports);

    //MANNI
    FM_PDO_Transfer(FM_Control[FM_ControlReg_Operation],&FM_Control[FM_ControlReg_Status]);


    return EplRet;
}

/**
********************************************************************************
\brief    init port configuration

InitPortConfiguration() reads the port configuration inputs. The port
configuration inputs are connected to general purpose I/O pins IO3V3[16..12].
The read port configuration if stored at the port configuration outputs to
set up the input/output selection logic.

\param    portIsOutput        pointer to array where output flags are stored
*******************************************************************************/
void InitPortConfiguration (BYTE *p_portIsOutput)
{
    register int    iCnt;
    volatile BYTE    portconf;
    unsigned int    direction = 0;

    /* read port configuration input pins */
    memcpy((BYTE *) &portconf, LATCHED_IOPORT_CFG, 1);
    portconf = (~portconf) & 0x0f;

    PRINTF1("\nPort configuration register value = 0x%1X\n", portconf);

    for (iCnt = 0; iCnt <= 3; iCnt++)
    {
        if (portconf & (1 << iCnt))
        {
            direction |= 0xff << (iCnt * 8);
            p_portIsOutput[iCnt] = TRUE;
        }
        else
        {
            direction &= ~(0xff << (iCnt * 8));
            p_portIsOutput[iCnt] = FALSE;
        }
    }
}

