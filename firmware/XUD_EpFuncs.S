/**
 * Module:  module_xud
 * Version: 0v60
 * Build:   5749c99b7821363ba858462b29442d52f62eafe2
 * File:    XUD_EpFuncs.S
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2010
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/                                   
/** XUD_EpFuncs.S
  * @brief     Functions for data transfer to/from XUD
  * @author    Ross Owen, XMOS Limited
  * @version   0v9
  */
#include "usb.h"
    
#define SR_EEBLE_BIT 0x1
//int XUD_GetSetupData(chanend c, unsigned buffer[]); 
//                 r0          r1           
// TODO just use GetData
.globl   XUD_GetSetupData
.globl   XUD_GetSetupData.nstackwords
.linkset XUD_GetSetupData.nstackwords, 0
.text

.cc_top XUD_GetSetupData.func, XUD_GetSetupData
XUD_GetSetupData:
    ldw        r2, r0[0]
    ldw        r11,  r0[1]
    stw        r11, r2[0]
    ldw        r0,  r0[2]        

XUD_GetSetupData_Retry: 
    out        res[r0], r1                    // TODO Should only need CT
    
    
    testct     r11, res[r0]                      // Test whether there is a RESET/SUSPEND exception
    bt         r11, ResetSuspend
        
    in         r11, res[r0]
SetupDataLoop:
    testct     r11,  res[r0]
    bt         r11, XUD_GetSetupData_Retry
    in         r11,  res[r0]                  // r2: 0
    stw        r11,  r1[0]
    testct     r11,  res[r0]
    bt         r11, XUD_GetSetupData_Retry        
    in         r11,  res[r0]                  // r2: 0
    stw        r11,  r1[1]
    inct       r11,  res[r0]                  // tail or 9 for crc error
    sub        r11, r11, 9
    bf         r11, XUD_GetSetupData_Retry
    ldc        r11, 0
    stw        r11, r2[0]                        // Zero ready entry                    
    ldc r0, 8
        
    retsp    	0
.cc_bottom XUD_GetSetupData.func


.globl   XUD_GetData_NoReq
.globl   XUD_GetData_NoReq.nstackwords
.linkset XUD_GetData_NoReq.nstackwords, 0

//int XUD_GetData(chanend c, unsigned buffer[]); 
//                 r0          r1           

.globl   XUD_GetData
.globl   XUD_GetData.nstackwords
.linkset XUD_GetData.nstackwords, 0
.text

.cc_top XUD_GetData.func, XUD_GetData
XUD_GetData:					  
    ldw        r2, r0[0]
    ldw        r11, r0[1]
    stw        r11, r2[0]                   // Mark EP as ready
    ldw        r0,  r0[2]
XUD_GetDataRetry:					  
    out        res[r0], r1                  // TODO Should only need CT
        
    testct     r11, res[r0]                      // Test whether there is a RESET/SUSPEND exception
    bt         r11, ResetSuspend
    
    in         r11, res[r0]                 // Wait for XUD response
        
XUD_GetData_NoReq:                           // Entry for _NoReq 
    testct     r3,  res[r0]                 // Wait for data (or end)
    bt         r3,  DataEnd
     
DataLoop:
    in         r11,  res[r0]                // r2: 0
    stw        r11,  r1[r3]      
    add        r3,   r3,   1
    testct     r11,  res[r0]
    bf         r11,  DataLoop
                    
DataEnd:
    inct       r11, res[r0]                  // r11 is tail length (bytes + 10)
                                             // or 9 for crc error
    sub        r11, r11, 10
    
CalcdataLength:
    shl        r3, r3, 2                     // Num received words to bytes
    add        r3, r11, r3                   // r11: Total bytes received (Note this includes 2 byte crc)

    add        r11, r11, 1        
    bf         r11,    XUD_GetDataBadCRC             // CRC error, restart        

    ldc        r11, 0
    stw        r11, r2[0]                        // Zero ready entry        
        
    sub        r0, r3, 6                     // CRC correction and extra increment 
        
    retsp    	0
    
ResetSuspend:
    ldc        r11, 0
    stw        r11, r2[0]                        // Zero ready entry        
        
    mkmsk      r0, 32
Return:
    retsp      0

XUD_GetDataBadCRC:
    bu XUD_GetDataRetry
.cc_bottom XUD_GetData.func












// Note: Assumes startIndex is word aligned
//int XUD_SetData_indexed(chanend c, unsigned buffer[], unsigned datasize, unsigned startIndex unsigned pid); 
//                           r0             r1                  r2                r3

.globl   XUD_SetData_NoReq
.globl   XUD_SetData_NoReq.nstackwords
.linkset XUD_SetData_NoReq.nstackwords, 0

.globl   XUD_SetData
.globl   XUD_SetData.nstackwords
.linkset XUD_SetData.nstackwords, 7
.text

.cc_top XUD_SetData.func, XUD_SetData
XUD_SetData:
    entsp       7    
    stw         r0, sp[1]                        // Reg save (for retry) 
    stw         r1, sp[2]
    stw         r2, sp[3]
    stw         r3, sp[4]
    stw         r5, sp[5]

XUD_SetDataRetry:       
    stw         r4, sp[0]                        
        
    ldw         r11, sp[8]                       // Load PID toggle param from stack
    bt          r11, XUD_SetData_PidReset
   
XUD_SetData_PidToggle:
    ldw         r11, r0[4]                       // Load EP PID from structure 
    ldc         r4, 0x88
    xor         r11, r11, r4
    stw         r11, r0[4]

XUD_SetData_PidReset: 
    stw         r11, r0[4]                          // Store back Reset PID

   
XUD_SetData_NoReq:	
    add         r1, r1, r3                         // Add start index to buffer address

CalcTailLength:
    shl         r3, r2, 5                           // Taillength: bytes to bits * 2
    zext        r3, 7

SetupLoopTerm:
    shr         r2, r2, 2                           // r2: datalength (bytes) ---> r2: datalength (words)

AdjustBufferPointer:
    shl         r5, r2, 2                           // Get end off buffer address
    add         r1, r1, r5

NegativeIndex:                                      // Produce negtive offset from end of buffer
    neg         r2, r2                               

LoadFirstWord:
    ldw         r5, r1[r2]                          // Load first word.. (done to save branching to load)

    ldw         r4, r0[2]                           // Load channel
    out        res[r4], r11                        // Send PID 

    ldw         r4, r0[0]        
    ldw         r11, r0[1]                          // Load chan
    ldw         r0,  r0[2]

    outct       res[r0], r3                          // Out tail length
    bf          r2, XUD_SetData_ShortPacket

XUD_SetData_DataRdy:
    stw         r11, r4[0]                          // Mark EP as ready to go
        
    testct      r11, res[r0]                        // Test whether there is a RESET/SUSPEND exception
    bt          r11, ResetSuspend2
    in          r11, res[r0]                        // Wait for response to request to send 

XUD_SetData_OutputLoop_Out:
OutputLoop:
    out         res[r0], r5
    add         r2, r2, 1
    ldw         r5, r1[r2]
    bt          r2, OutputLoop                      // NOTE: We have a instruction spare here
                                                        
XUD_SetData_OutputLoop_End:
    outct       res[r0], r3                             // Send out tail length, note: safe as only CT 1 and 2 are reserved (END and PAUSE)
                                                                
SendTail:
    out         res[r0], r5
    in          r1, res[r0]        
    ldc         r0, 0  
    bf          r1, Return2

    ldw         r0, sp[1]
    ldw         r1, sp[2]
    ldw         r2, sp[3]
    ldw         r3, sp[4]  
    ldw         r5, sp[5]      

    bu          XUD_SetDataRetry        
        
Return2:
    ldc         r11, 0
    stw         r11, r4[0]                        // Zero ready entry                    
    ldw         r4, sp[0]        
    ldw         r5, sp[5]      
    retsp       7
    
ResetSuspend2:
        
    mkmsk      r0, 32
    bu         Return2

    .cc_bottom XUD_SetData.func

XUD_SetData_ShortPacket:

    stw         r11, r4[0]
        
    testct      r11, res[r0]                        // Test whether there is a RESET/SUSPEND exception
    bt          r11, ResetSuspend2
    in          r11, res[r0]                        // Wait for response to request to send 

    //outct       res[r0], r3                         // Out tail length

XUD_SetData_OutTail_Short:
    outct   res[r0], r3                      // Send out tail length, note: safe as only CT 1 and 2 are reserved (END and PAUSE)
                                                                
    out     res[r0], r5
    in      r1, res[r0]        
    ldc     r0, 0  
    bf      r1, Return2

    ldw        r0, sp[1]
    ldw        r1, sp[2]
    ldw        r2, sp[3]
    ldw        r3, sp[4]  
    ldw        r5, sp[5]      

    bu XUD_SetDataRetry    


.globl XUD_ResetEndpoint
.globl   XUD_ResetEndpoint.nstackwords
.linkset XUD_ResetEndpoint.nstackwords, 1
        
.cc_top XUD_ResetEndpoint.func, XUD_ResetEndpoint
XUD_ResetEndpoint:
        entsp 1
        ldw r0, r0[2]
        bf  r1, .L0
        ldw r1, r1[0]
        ldw r1, r1[2]
.L0:        
        bl XUD_ResetEndpoint0
        retsp 1
.cc_bottom XUD_ResetEndpoint.func

.globl   XUD_SetReady.nstackwords
.linkset XUD_SetReady.nstackwords, 0
        
.cc_top XUD_SetReady.func, XUD_SetReady
XUD_SetReady:
    ldw        r0,  r0[2]               
    out        res[r0], r1                      
    ldw        r11, r0[0]
    ldw        r2,  r0[1]
    stw        r2, r11[0]
    retsp 0
.cc_bottom XUD_SetReady.func     


.globl   XUD_SetStall_Out
.globl   XUD_SetStall_Out.nstackwords
.linkset XUD_SetStall_Out.nstackwords, 0
        
/* R0: ep number */
.cc_top XUD_SetStall_Out.func, XUD_SetStall_Out
XUD_SetStall_Out:
    ldaw       r1,  dp[handshakeTable_OUT]
    ldc        r2, PIDn_STALL
    stw        r2, r1[r0]               
    retsp 0
.cc_bottom XUD_SetStall_Out.func   


 .globl   XUD_SetStall_In
.globl   XUD_SetStall_In.nstackwords
.linkset XUD_SetStall_In.nstackwords, 0
        
/* R0: ep number */
.cc_top XUD_SetStall_In.func, XUD_SetStall_In
XUD_SetStall_In:
    ldaw       r1,  dp[handshakeTable_IN]
    ldc        r2, PIDn_STALL
    stw        r2, r1[r0]               
    retsp 0
.cc_bottom XUD_SetStall_In.func       

.globl   XUD_UnStall_Out
.globl   XUD_UnStall_Out.nstackwords
.linkset XUD_UnStall_Out.nstackwords, 0
        
/* R0: ep number */
.cc_top XUD_UnStall_Out.func, XUD_UnStall_Out
XUD_UnStall_Out:
    ldaw       r1,  dp[handshakeTable_OUT]
    ldc        r2, PIDn_NAK
    stw        r2, r1[r0]               
    retsp 0
.cc_bottom XUD_UnStall_Out.func   


.globl   XUD_UnStall_In
.globl   XUD_UnStall_In.nstackwords
.linkset XUD_UnStall_In.nstackwords, 0
        
/* R0: ep number */
.cc_top XUD_UnStall_In.func, XUD_UnStall_In
XUD_UnStall_In:
    ldaw       r1,  dp[handshakeTable_IN]
    ldc        r2, PIDn_NAK
    stw        r2, r1[r0]               
    retsp 0
.cc_bottom XUD_UnStall_In.func  
