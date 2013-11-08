


#define FM_Task_Base            FRAMEMANIPULATOR_0_ST_SLAVE_TASKS_BASE
#define FM_Control_Base         FRAMEMANIPULATOR_0_SC_SLAVE_CONTROL_BASE
#define FM_NoOFTasks            FRAMEMANIPULATOR_0_ST_SLAVE_TASKS_SPAN/(8*4)    //Whole Span in Bytes
                                // 8Byte for a Word in 4 Memory

#define FM_ContrOpeAddr         0
#define FM_ContrErrorAddr       1

#define FM_ControlReg_Operation 0
#define FM_ControlReg_Status    1

//nios2 declarations
#include "io.h"
#define IORD32(base, offset)        IORD_32DIRECT(base+offset, 0)
#define IORD16(base, offset)        IORD_16DIRECT(base+offset, 0)
#define IORD8(base, offset)         IORD_8DIRECT(base+offset, 0)
#define IOWR32(base, offset, data)  IOWR_32DIRECT(base+offset, 0, data)
#define IOWR16(base, offset, data)  IOWR_16DIRECT(base+offset, 0, data)
#define IOWR8(base, offset, data)   IOWR_8DIRECT(base+offset, 0, data)


//prototypes

//PDO Transfer
void FM_PDO_Transfer(char operation_byte_p,char* p_error_byte_p);

//SDO Callback
EPLDLLEXPORT tEplKernel PUBLIC FMConfigObdAccess(tEplObdCbParam MEM* pParam_p);
