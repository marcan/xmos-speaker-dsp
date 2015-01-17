/**
 * Module:  module_xud
 * Version: 0v60
 * Build:   7ed6557c2ff77fa277fa6978ed36e74898489f7a
 * File:    xud.h
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
/** @file      xud.h
  * @brief     User defines and functions for XMOS USB Device Layer 
  * @author    Ross Owen, XMOS Limited
  * @version   0.9
  **/

#ifndef XUD_H
#define XUD_H 1

#include <print.h>
#include <xs1.h>

/* Arch type defines */
typedef unsigned char 	uint8;
typedef unsigned int 	uint32;


/**
 * @var     typedef XUD_EpType
 * @brief   Typedef for endpoint types.  Note: it is important that ISO is 0
 */
typedef enum 
{
    XUD_EPTYPE_ISO = 0,          /**< Isoc */
    XUD_EPTYPE_INT,              /**< Interrupt */
    XUD_EPTYPE_BUL,              /**< Bulk */
    XUD_EPTYPE_CTL,              /**< Control */
    XUD_EPTYPE_DIS,              /**< Disabled */
} XUD_EpType;


typedef unsigned int XUD_ep;

/* Value to be or'ed in with EP type to enable bus state notifications */
#define XUD_STATUS_ENABLE           0x80000000                   

/* Bus state defines */
#define XUD_SPEED_FS                1
#define XUD_SPEED_HS                2

#define XUD_SUSPEND                 3

/* Control token defines - used to inform EPs of bus-state types */
#define USB_RESET_TOKEN             8        /* Control token value that signals RESET */
#define USB_SUSPEND_TOKEN           9        /* Control token value that signals SUSPEND */


/**********************************************************************************************
 * Below are prototypes for main assembly functions for data transfer to/from USB I/O thread 
 * All other Get/Set functions defined here use these.  These are implemented in XUD_EpFuncs.S
 * Wrapper functions are provided for conveniance (implemented in XUD_EpFunctions.xc).  
 */

/** XUD_GetData
 *  @brief      Gets a data from XUD
 *  @param      c   Out channel from XUD
 *  @param      buffer Buffer to store received data into
 *  @return     Datalength (in bytes) 
 */
inline int XUD_GetData(XUD_ep c, unsigned char buffer[]);

/** XUD_GetData
 *  @brief      Essentially the same as XUD_GetData but does not perform the initial handshake 
 *  @param      c   Out channel from XUD
 *  @param      buffer Buffer to store received data into
 *  @return     Datalength (in bytes) 
 */
inline int XUD_GetData_NoReq(XUD_ep c, unsigned char buffer[]);



/** XUD_GetSetupData
 *  @brief      Gets a data from XUD
 *  @param      c   Out channel from XUD
 *  @param      buffer Buffer to store received data into
 *  @return     Datalength (in bytes) 
 *  @TODO       Use generic GetData from this 
 */
int XUD_GetSetupData(XUD_ep c, unsigned char buffer[]); 

int XUD_SetData(XUD_ep c, unsigned char buffer[], unsigned datalength, unsigned startIndex, unsigned pidToggle);
int XUD_SetData_NoReq(XUD_ep c, unsigned char buffer[], unsigned datalength, unsigned startIndex);

/*****************************/

/* Typedef for BmRequestType structure */
typedef struct bmRequestType
{
  unsigned char Recipient;       // [4..0]   Request directed to:
                                 //          0b00000: Device
                                 //          0b00001: Specific interface
                                 //          0b00010: Specific endpoint
                                 //          0b00011: Other element in device                           
  unsigned char Type;            // [6..5]   0b00: Standard request
                                 //          0b01: Class specific request
                                 //          0b10: Request by vendor specific driver 
  unsigned char Direction;       // [7]      0 (Host->Dev)
                                 //          1 (Dev->Host)
} BmRequestType;


/* Typedef for SetupPacket structure */
typedef struct setupPacket
{ 
  BmRequestType bmRequestType;   /* (1 byte) Specifies direction of dataflow, type of rquest and recipient */
  unsigned char bRequest;        /* Specifies the request */
  unsigned short wValue;         /* Host can use this to pass info to the device in its own way */
  unsigned short wIndex;         /* Typically used to pass index/offset such as interface or EP no */
  unsigned short wLength;        /* Number of data bytes in the data stage (for Host -> Device this                                               this is exact count, for Dev->Host is a max. */
} SetupPacket;


/** This performs the low level USB I/O operations. Note that this
 *  needs to run in a thread with at least 80 MIPS worst case execution
 *  speed.
 * 
      \param c_ep_out   An array of channel ends, one channel end per 
                        output endpoint (USB OUT transaction); this includes
                        a channel to obtain requests on Endpoint 0.
      \param num_out    The number of output endpoints, should
                        be at least 1 (for Endpoint 0).
      \param c_ep_in    An array of channel ends, one channel end
                        per input endpoint (USB IN transaction); this
                        includes a channel to respond to
                        requests on Endpoint 0.
      \param num_in The number of output endpoints, should be 
                    at least 1 (for Endpoint 0).
      \param c_sof   A channel to receive SOF tokens on. This channel
                     must be connected to a process that
                     can receive a token once every 125 ms. If
                     tokens are not read, the USB layer will block up.
                     If no SOF tokens are required ``null`` 
                     should be used as this channel.

      \param ep_type_table_out See ep_type_table_in
      \param ep_type_table_in This and ep_type_table_out are two arrays
                              indicating the type of channel ends. 
                              Legal types include: 
                             ``XUD_EPTYPE_CTL`` (Endpoint 0), 
                             ``XUD_EPTYPE_BUL`` (Bulk endpoint),
                             ``XUD_EPTYPE_ISO`` (Isochronous endpoint),
                             ``XUD_EPTYPE_DIS`` (Endpoint not used).
                              The first array contains the
                              endpoint types for each of the OUT
                              endpoints, the second array contains the
                              endpoint types for each of the IN
                              endpoints.
      \param p_usb_rst The port to send reset signals to.
      \param clk The clock block to use for the USB reset - 
                 this should not be clock block 0.
      \param reset_mask The mask to use when sending a reset. The mask is
                        ORed into the port to enable reset, and unset when
                        deasserting reset. Use '-1' as a default mask if this
                        port is not shared.
      \param desired_speed This parameter specifies whether the
                           device must be full-speed (ie, USB-1.0) or
                           whether high-speed is acceptable if supported
                           by the host (ie, USB-2.0). Pass ``XUD_SPEED_HS``
                           if high-speed is allowed, and ``XUD_SPEED_FS``
                           if not. Low speed USB is not supported by XUD.
      \param test_mode This should always be null.

 */
int XUD_Manager(chanend c_ep_out[], int noEpOut, 
                chanend c_ep_in[], int noEpIn,
                chanend ?c_sof,
                XUD_EpType epTypeTableOut[], XUD_EpType epTypeTableIn[],
                out port p_usb_rst, clock clk, unsigned rstMask, unsigned desiredSpeed,
								chanend ?c_usb_testmode);



/** XUD_ParseSetupPacket
  * @brief Parses a setup data buffer into passed SetupPacket structure 
  */
void XUD_ParseSetupPacket(unsigned char b[], SetupPacket &p);

/** XUD_PrintSetupPacket 
 *  @brief Prints out passed SetupPacket struct using debug IO
 */
void XUD_PrintSetupPacket(SetupPacket sp);


/** XUD_GetBuffer()  
  * @brief  Request data from USB buffer for specified EP, pauses untill data is available
  * @param  c Data channel from XUD
  * @param  buffer char buffer passed by ref into which data is returned
  * @return datalength in bytes
  **/
int XUD_GetBuffer(XUD_ep c, unsigned char buffer[]);


/** XUD_GetSetupBuffer() 
  * @brief  Request setup data from usb buffer for a specific EP, pauses until data is available.  
  * @param  c Data channel from XUD
  * @param  buffer char buffer passed by ref into which data is returned
  * @return datalength in bytes (always 8)
  **/
int XUD_GetSetupBuffer(XUD_ep c_out, unsigned char buffer[]);




int XUD_SetBuffer(XUD_ep c, unsigned char buffer[], unsigned datalength);
int XUD_SetBuffer_ResetPid(XUD_ep c, unsigned char buffer[], unsigned datalength, unsigned char pid);

/* Same as above but takes a max packet size for the endpoint, breaks up data to transfers of no 
 * greater than this.
 *
 * NOTE: This function reasonably assumes the max transfer size for an EP is word aligned  
 **/
int XUD_SetBuffer_ResetPid_EpMax(XUD_ep c, unsigned epNum, unsigned char buffer[], 
  unsigned datalength, unsigned epMax, unsigned char pid);


/** XUD_DoGetReuest()
  * @brief  Does a "get" request.  These take the form:
  *                 - Send data (with reset pid sequencing)
  *	                - Zero-length out transaction status stage
  * 
  * @param  c_out 		XUD_Ep to/from XUD
  * @param  c_in        XUD_Ep to XUD epNum
  * @param  buffer 	    Data buffer to send
  * @param  length	    Length of data to be sent
  * @param  requested   Max length the host has requested
  * 
  * @return		Returns non-zero on error	
  **/
int XUD_DoGetRequest(XUD_ep c_out, XUD_ep c_in,  uint8 buffer[], unsigned length, unsigned requested);



int XUD_DoSetRequestStatus(XUD_ep c, unsigned epnNum);

/** XUD_SetDevAddr()
 * @brief   Sets current device address
 * @param   addr Address to be set
 * @return  void
 * @warning must be run on USB core
 */
void XUD_SetDevAddr(unsigned addr);

int XUD_ResetEndpoint(XUD_ep one, XUD_ep &?two);

XUD_ep XUD_Init_Ep(chanend c_ep);


/** XUD_SetStall_Out()
 * @brief   Mark an OUT endpoint as STALL.  Note: is cleared automatically if a SETUP received on EP
 * @param   epNum Endpoint number
 * @return  void
 * @warning must be run on USB core
 */
void XUD_SetStall_Out(int epNum);


/** XUD_SetStall_In()
 * @brief   Mark an IN endpoint as STALL.  Note: is cleared automatically if a SETUP received on EP
 * @param   epNum Endpoint number
 * @return  void
 * @warning must be run on USB core
 */
void XUD_SetStall_In(int epNum);


/** XUD_UnStall_Out()
 * @brief   Mark an OUT endpoint as NOT STALLed.
 * @param   epNum Endpoint number
 * @return  void
 * @warning must be run on USB core
 */
void XUD_UnStall_Out(int epNum);


/** XUD_UnStall_In()
 * @brief   Mark an IN endpoint as NOT STALLed.
 * @param   epNum Endpoint number
 * @return  void
 * @warning must be run on USB core
 */
void XUD_UnStall_In(int epNum);



inline void XUD_SetReady(XUD_ep e, int pid)
{
    int chan_array_ptr;
    int xud_chan;
    int my_chan;
    asm ("ldw %0, %1[0]":"=r"(chan_array_ptr):"r"(e));
    asm ("ldw %0, %1[1]":"=r"(xud_chan):"r"(e));
    asm ("ldw %0, %1[2]":"=r"(my_chan):"r"(e));
    asm ("out res[%0], %1"::"r"(my_chan),"r"(pid));  
    asm ("stw %0, %1[0]"::"r"(xud_chan),"r"(chan_array_ptr));
}

#if 0
inline void XUD_SetReady_Out(XUD_ep e, int x, unsigned bufferPtr)
{
    int chan_array_ptr;
    int xud_chan;
    int my_chan;
    asm ("ldw %0, %1[0]":"=r"(chan_array_ptr):"r"(e));
    asm ("ldw %0, %1[1]":"=r"(xud_chan):"r"(e));
    asm ("ldw %0, %1[2]":"=r"(my_chan):"r"(e));
    asm ("out res[%0], %1"::"r"(my_chan),"r"(1));  

    /* Store buffer pointer */
    asm ("stw %0, %1[5]"::"r"(bufferPtr),"r"(e));
    
    /* Mark EP as ready with ID */
    asm ("stw %0, %1[0]"::"r"(xud_chan),"r"(chan_array_ptr));
}
#endif

inline void XUD_SetReady_In(XUD_ep e, int pid, unsigned bufferPtr, int len)
{
    int chan_array_ptr;
    int xud_chan;
    int my_chan;
    int tail;


    if(!pid)
    {
        asm ("ldw %0, %1[4]":"=r"(pid):"r"(e));
        pid ^= 0x88;
        asm ("stw %0, %1[4]"::"r"(pid),"r"(e));
    }
 
    asm ("ldw %0, %1[0]":"=r"(chan_array_ptr):"r"(e));
    asm ("ldw %0, %1[2]":"=r"(my_chan):"r"(e));
    asm ("out res[%0], %1"::"r"(my_chan),"r"(pid)); 

    tail = len & 0x3;
    bufferPtr += (len-tail);
    tail <<= 5;
    
    //tmp = len << 5;
    //tmp = zext(tmp, 7);
    
    /* Output tail */
    asm("outct res[%0], %1":: "r"(my_chan), "r"(tail));
    asm ("ldw %0, %1[1]":"=r"(xud_chan):"r"(e));

    len >>= 2;
    len = -len;

    /* Store buffer pointer */
    asm ("stw %0, %1[5]"::"r"(bufferPtr),"r"(e));
    
    /* Store length */
    asm ("stw %0, %1[3]"::"r"(len),"r"(e));

    /* Mark EP ready with pointer */
    asm ("stw %0, %1[0]"::"r"(xud_chan),"r"(chan_array_ptr));
}


#if 0
inline int XUD_GetData_Inline(XUD_ep e, chanend c)
{
    int tailLen, dataLen;
    unsigned p, p0;

    asm("#XUD_GetData_Inline");

    /* Load EP Buffer pointer */ 

    while (!testct(c)) 
    {
        unsigned int datum = inuint(c);
        asm("stw %0, %1[0]"::"r"(datum),"r"(p));
        p += 4;
    }  
    tailLen = inct(c);

    tailLen -= 10;

    /* Calc datalength (in bytes) */
    dataLen = p - p0;
    dataLen <<= 2;
    dataLen += taiLen;
   
    /*TODO BAD CRC REPORT */ 

    /* Lenght correction for CRC and extra increment */
    dataLen -= 6;

    return dataLen;


#if 0
                // XUD_GetData
                {
                    xc_ptr p = aud_from_host_buffer+4;
                    xc_ptr p0 = p;
                    int tail;
                    numSamples = 0;
                    while (!testct(c_aud_out)) 
                    {
                        unsigned int datum = inuint(c_aud_out);
                        write_via_xc_ptr(p, datum);
                        p += 4;
                    }  
                    tail = inct(c_aud_out);
                    datalength = p - p0 - 4;
                    switch (tail) 
                    {                  
                        case 10:
                        // the tail is 0 which means 
                        datalength -= 2;
                        break;
                        default:
                        // the tail is 2 which means the input was word aligned      
                        break;
                    }                
                }
#endif
}
#endif

inline void XUD_SetData_Inline(XUD_ep e, chanend c)
{
    unsigned datum;
    unsigned p;
    unsigned chan_array_ptr;
    int len;

    asm ("ldw %0, %1[0]":"=r"(chan_array_ptr):"r"(e));
    asm ("ldw %0, %1[5]":"=r"(p):"r"(e));
    asm ("ldw %0, %1[3]":"=r"(len):"r"(e));

    asm("ldw %0, %1[%2]":"=r"(datum):"r"(p),"r"(len));
                
    while (len) 
    {
        len += 1;
        outuint(c, datum);
        asm("ldw %0, %1[%2]":"=r"(datum):"r"(p),"r"(len));
    }
                
    outct(c, 0);
    outuint(c, datum);
    (void) inuint(c);

}
/* Error printing functions */
#ifdef XUD_DEBUG_VERSION
void XUD_Error(char errString[]);
void XUD_Error_hex(char errString[], int i_err);
#else
#define XUD_Error(a) /* */
#define XUD_Error_hex(a, b) /* */
#endif

#endif /* _XUD_H_ */
