/**
* Module:  module_usb_aud_shared
* Version: 2v4
* Build:   0d7477798fc2c4749eec66c9d1555b9dd2c3fe8a
* File:    endpoint0.xc
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
/**
* @file    endpoint0.xc
* @brief   Implements endpoint zero for an USB Audio 1.0/2.0 device
* @author  Ross Owen, XMOS Semiconductor
*/

#include <xs1.h>
#include <stdio.h>
#include <safestring.h>

#include "xud.h"                 /* XUD user defines and functions */
#include "usb.h"                 /* Defines from USB 2.0 Spec */
#include "usbaudio20.h"          /* Defines from USB Audio 2.0 spec */

#include "devicedefines.h"
#include "DescriptorRequests.h"  /* This device's descriptors */
#include "descriptors_2.h"       /* Descriptors */
#include "clockcmds.h"
#include "audiostream.h"

/* Handles Audio Class requests */
int AudioClassRequests_2(XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, chanend c_audioControl, chanend ?c_mix_ctl, chanend ?c_clk_ctl);
int VendorRequests(XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, chanend c_dsp_ctl);

/* Global var for current frequency, set to default freq */
unsigned int g_curSamFreq = DEFAULT_FREQ;
unsigned int g_curSamFreq48000Family = DEFAULT_FREQ % 48000 == 0;
unsigned int g_curSamFreqMultiplier = DEFAULT_FREQ / 48000;

int min(int x, int y);

/* Records alt setting for each interface */
int interfaceAlt[NUM_INTERFACES] = {0};

/* Global current device config var*/
unsigned g_config = 0;

/* Global endpoint status arrays */
unsigned g_epStatusOut[NUM_EP_OUT];
unsigned g_epStatusIn[NUM_EP_IN];

/* Global variable for current USB bus speed (i.e. FS/HS) */
unsigned g_curUsbSpeed = 0;

/* Used when setting/clearing EP halt */
void SetEndpointStatus(unsigned epNum, unsigned status)
{
/* Inspect for IN bit */
	if( epNum & 0x80 )
	{
		epNum &= 0x7f;

		/* Range check */
		if(epNum < NUM_EP_IN)
		{
			g_epStatusIn[ epNum & 0x7F ] = status;
		}
	}
	else
	{
		if(epNum < NUM_EP_OUT)
		{
			g_epStatusOut[ epNum ] = status;
		}
	}
}

#define STR_USENG 0x0409

#define DESC_STR_LANGIDS \
{ \
STR_USENG & 0xff,               /* 2  wLangID[0] */ \
STR_USENG>>8,            /* 3  wLangID[0] */ \
'\0' \
}

/* String descriptors */
static unsigned char strDesc_langIDs[] = DESC_STR_LANGIDS;

/* Endpoint 0 function.  Handles all requests to the device */
void Endpoint0( chanend c_ep0_out, chanend c_ep0_in, chanend c_audioControl, chanend ?c_mix_ctl, chanend ?c_clk_ctl, chanend c_dsp_ctl)
{
	unsigned char buffer[512];
	SetupPacket sp;
	XUD_ep ep0_out = XUD_Init_Ep(c_ep0_out);
	XUD_ep ep0_in  = XUD_Init_Ep(c_ep0_in);

	/* Init endpoint status tables */
	for (int i = 0; i++; i < NUM_EP_OUT)
		g_epStatusOut[i] = 0;

	for (int i = 0; i++; i < NUM_EP_IN)
		g_epStatusIn[i] = 0;

	/* Copy langIDs string desc into string[0] */
	safememcpy(strDescs_Audio2[0], strDesc_langIDs, sizeof(strDesc_langIDs));

	while(1)
	{
		int retVal = 1;

		/* Do standard enumeration requests */
		if(g_curUsbSpeed == XUD_SPEED_HS)
		{

			/* Return Audio 2.0 Descriptors */
			cfgDesc_Audio2[1] = CONFIGURATION;
			cfgDesc_Null[1] = OTHER_SPEED_CONFIGURATION;

			retVal = DescriptorRequests(ep0_out, ep0_in,
				devDesc_Audio2, sizeof(devDesc_Audio2),
				cfgDesc_Audio2, sizeof(cfgDesc_Audio2),
				devQualDesc_Null, sizeof(devQualDesc_Null),
				cfgDesc_Null, sizeof(cfgDesc_Null),
				strDescs_Audio2, sp);
		}
		else
		{
			/* Return descriptors for full-speed - NULL */
			cfgDesc_Null[1] = CONFIGURATION;
			cfgDesc_Audio2[1] = OTHER_SPEED_CONFIGURATION;

			retVal = DescriptorRequests(ep0_out, ep0_in,
				devDesc_Null, sizeof(devDesc_Null),
				cfgDesc_Null, sizeof(cfgDesc_Null),
				devQualDesc_Audio2, sizeof(devQualDesc_Audio2),
				cfgDesc_Audio2, sizeof(cfgDesc_Audio2),
				strDescs_Audio2, sp);
		}

		if (retVal == 1)
		{
			/* Request not covered by XUD_DoEnumReqs() so decode ourselves */
			/* Inspect Request type and Receipient */
			switch( (sp.bmRequestType.Recipient ) | (sp.bmRequestType.Type << 5) )
			{
				case STANDARD_INTERFACE_REQUEST:

					switch(sp.bRequest)
					{
						/* Set Interface */
						case SET_INTERFACE:


#if defined(OUTPUT) && defined(INPUT)
							/* Check for stream start stop on output and input audio interfaces */
							if(sp.wValue && !interfaceAlt[1] && !interfaceAlt[2])
							{
								/* If start and input AND output not currently running */
								AudioStreamStart();
							}
							else if(((sp.wIndex == 1)&& (!sp.wValue)) && interfaceAlt[1] && (!interfaceAlt[2]))
							{
								/* if output stop and output running and input not running */
								AudioStreamStop();
							}
							else if(((sp.wIndex == 2) && (!sp.wValue)) && interfaceAlt[2] && (!interfaceAlt[1]))
							{
								/* if input stop and input running and output not running */
								AudioStreamStop();
							}
#elif defined(OUTPUT) || defined(INPUT)
							if(sp.wValue && (!interfaceAlt[1]))
							{
								/* if start and not currently running */
								AudioStreamStart();
							}
							else if (!sp.wValue && interfaceAlt[1])
							{
								/* if stop and currently running */
								AudioStreamStop();
							}

#endif
							/* Record interface change */
							if( sp.wIndex < NUM_INTERFACES )
								interfaceAlt[sp.wIndex] = sp.wValue;
#if 1
							/* Check for audio stream from host start/stop */
							if(sp.wIndex == 2) // Input interface
							{
								switch(sp.wValue)
								{
									case 0:

										break;

									case 1:
										/* Stream active + 0 chans */
										outuint(c_audioControl, SET_CHAN_COUNT_IN);
										outuint(c_audioControl, NUM_USB_CHAN_IN);

#ifdef ADAT_RX
										outuint(c_clk_ctl, SET_SMUX);
										outuint(c_clk_ctl, 0);
										outct(c_clk_ctl, XS1_CT_END);
#endif

										break;

#ifdef ADAT_RX
									case 2:

										/* Stream active + 8 chans */
										outuint(c_audioControl, SET_CHAN_COUNT_IN);
										outuint(c_audioControl, NUM_USB_CHAN_IN-4);

										outuint(c_clk_ctl, SET_SMUX);
										outuint(c_clk_ctl, 1);
										outct(c_clk_ctl, XS1_CT_END);
										break;

									case 3:
										outuint(c_audioControl, SET_CHAN_COUNT_IN);
										outuint(c_audioControl, NUM_USB_CHAN_IN-6);


										outuint(c_clk_ctl, SET_SMUX);
										outuint(c_clk_ctl, 1);
										outct(c_clk_ctl, XS1_CT_END);
										/* Stream active + 8 chans */
										//outuint(c_audioControl, 8);
										// Handshake
										//chkct(c_audioControl, XS1_CT_END);

										break;

#endif

								}
							}
#endif
							/* No data stage for this request, just do data stage */
							retVal = XUD_DoSetRequestStatus(ep0_in, 0);
							break;

						/* A device must support the GetInterface request if it has alternate setting for that interface */
						case GET_INTERFACE:

							buffer[0] = 0;

							/* Bounds check */
							if( sp.wIndex < NUM_INTERFACES )
								buffer[0] = interfaceAlt[sp.wIndex];

							retVal = XUD_DoGetRequest(ep0_out, ep0_in,  buffer, 1, sp.wLength);
							break;


						default:
								printstr("Unknown Standard Interface Request: ");
								printhexln(sp.bRequest);
								printhexln(sp.bmRequestType.Type);
								printhexln(sp.bmRequestType.Recipient);
								printhexln(sp.bmRequestType.Recipient | (sp.bmRequestType.Type << 5));
								break;
				}
				break;

				/* Recipient: Device */
				case STANDARD_DEVICE_REQUEST:

					/* Standard Device requests (8) */
					switch( sp.bRequest )
					{

						/* Set Device Address: This is a unique set request. */
						case SET_ADDRESS:

							/* Status stage: Send a zero length packet */
							retVal = XUD_SetBuffer_ResetPid(ep0_in,  buffer, 0, PIDn_DATA1);

							/* TODO We should wait until ACK is received for status stage before changing address */
							//XUD_Sup_Delay(50000);
							{
								timer t;
								unsigned time;
								t :> time;
								t when timerafter(time+50000) :> void;
							}

							/* Set device address in XUD */
							XUD_SetDevAddr(sp.wValue);

							break;


						/* TODO Check direction */
						/* Standard request: SetConfiguration */
						case SET_CONFIGURATION:

							g_config = sp.wValue;

							/* No data stage for this request, just do status stage */
							retVal = XUD_DoSetRequestStatus(ep0_in, 0);
							break;

						case GET_CONFIGURATION:
							buffer[0] = g_config;
							retVal = XUD_DoGetRequest(ep0_out, ep0_in, buffer, 1, sp.wLength);
						break;

						/* Get Status request */
						case GET_STATUS:

							buffer[0] = 0; // bus powered
							buffer[1] = 0; // remote wakeup not supported

							retVal = XUD_DoGetRequest(ep0_out, ep0_in, buffer,  2, sp.wLength);
							break;


						default:
						XUD_Error("Unknown device request");
							break;

					}
					break;

				/* Receipient: Endpoint */
				case STANDARD_ENDPOINT_REQUEST:

					/* Standard endpoint requests */
					switch ( sp.bRequest )
					{

						/* ClearFeature */
						case CLEAR_FEATURE:

							switch ( sp.wValue )
							{
								case ENDPOINT_HALT:

									/* Mark the endpoint status */

									SetEndpointStatus(sp.wIndex, 0);

									/* No data stage for this request, just do status stage */
									retVal = XUD_DoSetRequestStatus(ep0_in, 0);

									break;


								default:
									XUD_Error( "Unknown request in Endpoint ClearFeature" );
									break;
							}
							break; /* B_REQ_CLRFEAR */

						/* SetFeature */
						case SET_FEATURE:

							switch( sp.wValue )
							{
								case ENDPOINT_HALT:

									/* Check request is in range */
									SetEndpointStatus(sp.wIndex, 1);

									break;

								default:
									XUD_Error("Unknown feature in SetFeature Request");
									break;
							}


							retVal = XUD_DoSetRequestStatus(ep0_in, 0);

							break;



						/* Endpoint GetStatus Request */
						case GET_STATUS:

							buffer[0] = 0;
							buffer[1] = 0;

							if( sp.wIndex & 0x80 )
							{
								/* IN Endpoint */
								if((sp.wIndex&0x7f) < NUM_EP_IN)
								{
									buffer[0] = ( g_epStatusIn[ sp.wIndex & 0x7F ] & 0xff );
									buffer[1] = ( g_epStatusIn[ sp.wIndex & 0x7F ] >> 8 );
								}
							}
							else
							{
								/* OUT Endpoint */
								if(sp.wIndex < NUM_EP_OUT)
								{
									buffer[0] = ( g_epStatusOut[ sp.wIndex ] & 0xff );
									buffer[1] = ( g_epStatusOut[ sp.wIndex ] >> 8 );
								}
							}

							retVal = XUD_DoGetRequest(ep0_out, ep0_in, buffer,  2, sp.wLength);

						break;

						default:
							//printstrln("Unknown Standard Endpoint Request");
							break;

					}
					break;

				case CLASS_INTERFACE_REQUEST:
				case CLASS_ENDPOINT_REQUEST:
				{
					unsigned interfaceNum = sp.wIndex & 0xff;
					unsigned request = (sp.bmRequestType.Recipient ) | (sp.bmRequestType.Type << 5);

					retVal = AudioClassRequests_2(ep0_out, ep0_in, sp, c_audioControl, c_mix_ctl, c_clk_ctl);

				}
					break;

				case VENDOR_DEVICE_REQUEST: {
					retVal = VendorRequests(ep0_out, ep0_in, sp, c_dsp_ctl);
					break;
				}
					
				default:
					//printstr("unrecognised request\n");
					//printhexln(sp.bRequest);
					//printhexln(sp.bmRequestType.Type);
					//printhexln(sp.bmRequestType.Recipient);
					//printhexln(sp.bmRequestType.Recipient | (sp.bmRequestType.Type << 5));
					break;


			}

		} /* if(retVal == 0) */

		if(retVal == 1)
		{
			/* Did not handle request - Protocol Stall Secion 8.4.5 of USB 2.0 spec
			* Detailed in Section 8.5.3. Protocol stall is unique to control pipes.
			Protocol stall differs from functional stall in meaning and duration.
			A protocol STALL is returned during the Data or Status stage of a control
			transfer, and the STALL condition terminates at the beginning of the
			next control transfer (Setup). The remainder of this section refers to
			the general case of a functional stall */

			dprintf("Stall\n");
			XUD_SetStall_Out(0);
			XUD_SetStall_In(0);
		}

		if (retVal < 0)
		{
			g_curUsbSpeed = XUD_ResetEndpoint(ep0_in, ep0_out);

			g_config = 0;
		}
	}
}
