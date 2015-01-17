/**
 * Module:  module_xud
 * Version: 0v28
 * Build:   82d90eaec387c8d8d70f373b60f30ed4792d7bbd
 * File:    XUD_EpFunctions.xc
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
/** @file      XUD_EPFunctions.xc
  * @brief     Implementation of user API fuctions.  See xud.h for documentation.
  * @author    Ross Owen, XMOS Limited
  * @version   0.9
  **/

#include <xs1.h>
#include <print.h>

#include "xud.h"
#include "usb.h"

#if  0
#pragma xta command "analyse path XUD_SetData_DataRdy XUD_SetData_OutputLoop_Out"
#pragma xta command "set required - 266 ns"   

#endif


static int min(int x, int y)
{
    if (x < y)
        return x;
    return y;
}

void XUD_ParseSetupPacket(unsigned char b[], SetupPacket &p)
{
  // Byte 0: bmRequestType.
  p.bmRequestType.Recipient = b[0] & 0x1f;
  p.bmRequestType.Type      = (b[0] & 0x60) >> 5;
  p.bmRequestType.Direction = b[0] >> 7;

  // Byte 1:  bRequest 
  p.bRequest = b[1];

  // Bytes [2:3] wValue
  p.wValue = (b[3] << 8) | (b[2]);

  // Bytes [4:5] wIndex
  p.wIndex = (b[5] << 8) | (b[4]);

  // Bytes [6:7] wLength
  p.wLength = (b[7] << 8) | (b[6]);

}

void XUD_PrintSetupPacket(SetupPacket sp)
{
  printstr("Setup data\n");
  printstr("bmRequestType.Recipient: ");
  printhexln(sp.bmRequestType.Recipient);
  printstr("bmRequestType.Type: ");
  printhexln(sp.bmRequestType.Type);
  printstr("bmRequestType.Direction: ");
  printhexln(sp.bmRequestType.Direction);  
  printstr("bRequest: ");
  printhexln(sp.bRequest); 
  printstr("bmRequestType.wValue: ");
  printhexln(sp.wValue);   
  printstr("bmRequestType.wIndex: ");
  printhexln(sp.wIndex);
  printstr("bmRequestType.wLength: ");
  printhexln(sp.wLength);
}

/** XUD_GetBuffer_()
  * @brief        Requests data from the endpoint related to the passed channel
  * @param c      Channel to USB I/O thread for this endpoint 
  * @param buffer Buffer for returned data
  * @return       datalength of received data in bytes
  **/
int XUD_GetBuffer(XUD_ep c, unsigned char buffer[])
{
    return XUD_GetData(c, buffer);
}


/** XUD_GetSetupBuffer() 
  * @brief Request setup data from usb buffer for a specific EP, pauses until data is available.  
  * @param c Data channel to/from XUD
  * @param c_ctl Control channel from XUD
  * @param epNum EP number 
  * @param buffer char buffer passed by ref into which data is returned
  * @return datalength in bytes (always 8), -1 if kill received
  **/
int XUD_GetSetupBuffer(XUD_ep c_out, unsigned char buffer[])
{
    return XUD_GetSetupData(c_out, buffer);
}




/** XUD_SetBuffer_ResetPid(()
  * @brief      Sends USB data with PID reset to specified
  * @param      c
  * @param      epNum
  * @param      buffer
  * @param      datalengh in bytes!
  **/
int XUD_SetBuffer_ResetPid(XUD_ep c, unsigned char buffer[], unsigned datalength, unsigned char pid)
{
    return XUD_SetData(c, buffer, datalength, 0, pid);  
}

int XUD_SetBuffer(XUD_ep c, unsigned char buffer[], unsigned datalength)
{
    /* No PID reset, 0 start index */
    return XUD_SetData(c, buffer, datalength, 0, 0);  
}




/* Datalength in bytes */
int XUD_SetBuffer_ResetPid_EpMax(XUD_ep c, unsigned epNum, unsigned char buffer[], 
  unsigned datalength, unsigned epMax, unsigned char pid)
{
    int i = 0;
 
    /* Note: We could encompass this in the SetData function */ 
    if(datalength <= epMax)
    {
        /* Datalength is less than the maximum per transaction of the EP, so just send */
        return XUD_SetData(c, buffer, datalength, 0, pid); 
    }
    else
    {
        /* Send first packet out and reset PID */
        if (XUD_SetData(c, buffer, epMax, 0, pid) < 0) return -1;
        i+= epMax;
        datalength-=epMax;

        while(1)
	    {
	  
            if(datalength > epMax)
	        {
                /* PID Automatically toggled */
                if (XUD_SetData(c, buffer, epMax, i, 0) < 0) return -1;

                datalength-=epMax;
                i += epMax;
	        }
	        else
	        {
                /* PID automatically toggled */
                if (XUD_SetData(c, buffer, datalength, i, 0) < 0) return -1;

	            break; //out of while loop
	        }
	    }
    }
   
    return 0;
}



/* TODO Should take ep max length as a param - currently hardcoded as 64  */
int XUD_DoGetRequest(XUD_ep c, XUD_ep c_in, uint8 buffer[], unsigned length, unsigned requested)
{
    unsigned char tmpBuffer[1024];

    if (XUD_SetBuffer_ResetPid_EpMax(c_in, 0, buffer, min(length, requested), 64, PIDn_DATA1) < 0) 
    {
        return -1;
    }

    /* USB 2.0 8.5.3.2 */
    if((requested > length) && (length % 64) == 0)
    {
        XUD_SetBuffer(c_in, tmpBuffer, 0);
    }
   
    /* Status stage */ 
    return XUD_GetData(c, tmpBuffer);
}


/* Send 0 length status 
 * Simply sends a 0 length packet */
 //TODO dont need epNum
int XUD_DoSetRequestStatus(XUD_ep c, unsigned epNum)
{
    unsigned char tmp[8];

    return XUD_SetData(c, tmp, 0, 0, PIDn_DATA1);
}

#ifdef XUD_DEBUG_VERSION
void XUD_Error(char errString[])
{
    printstr("XUD Err: ");
    printstr(errString);
}

void XUD_Error_hex(char errString[], int i_err)
{
    printstr("XUD Err: ");
    printstr(errString);
    printhexln(i_err);
}
#endif


//???
int XUD_ResetEndpoint0(chanend one, chanend ?two) 
{
    int busStateCt;
    int busSpeed;

    

    outct(one, XS1_CT_END);
    busStateCt = inct(one);

    if (!isnull(two)) 
    {
        outct(two, XS1_CT_END);
        inct(two);
    }

    /* Inspect for reset, if so we expect a CT with speed */
    if(busStateCt == USB_RESET_TOKEN)
    {
        busSpeed = inuint(one);
        if(!isnull(two))
        {
            inuint(two);
        }

        return busSpeed;
    }
    else
    {
        /* Suspend cond */
        /* TODO Currently suspend condition is never communicated */
        return XUD_SUSPEND;
    }
}

XUD_ep XUD_Init_Ep(chanend c)
{
  XUD_ep ep = inuint(c);
  return ep;
}


