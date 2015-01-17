/**
* Module:  module_usb_aud_shared
* Version: 2v4
* Build:   7e402c1ce8e5187affe0ebfc9e3ea3fe1f8d1d01
* File:    descriptors_2.h
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
* @file    DeviceDescriptors_2.h
* @brief   Device Descriptors and params for Audio 2.0
* @author  Ross Owen, XMOS Limited
* @version 1.4
*/

#ifndef _DEVICE_DESCRIPTORS_2_
#define _DEVICE_DESCRIPTORS_2_

#include "usb.h"
#include "usbaudio20.h"             /* Defines from the USB Audio 2.0 Specifications */
#include "devicedefines.h"      	/* Define specific define */

/***** Device Descriptors *****/

/* Device Descriptor for Audio Class 2.0 (Assumes High-Speed ) */
unsigned char devDesc_Audio2[] =
{
	18,              				/* 0  bLength : Size of descriptor in Bytes (18 Bytes) */
	DEVICE,               			/* 1  bdescriptorType */
	0,               				/* 2  bcdUSB */
	2,               				/* 3  bcdUSB */
	0xEF,            				/* 4  bDeviceClass (See Audio Class Spec page 45) */
	0x02,               			/* 5  bDeviceSubClass */
	0x01,               			/* 6  bDeviceProtocol */
	64,              				/* 7  bMaxPacketSize */
	(VENDOR_ID & 0xFF),            	/* 8  idVendor */
	(VENDOR_ID >> 8),              	/* 9  idVendor */
	(PID_AUDIO_2 & 0xFF),           /* 10 idProduct */
	(PID_AUDIO_2 >> 8),             /* 11 idProduct */
	(BCD_DEVICE & 0xFF),           	/* 12 bcdDevice : Device release number */
	(BCD_DEVICE >> 8),              /* 13 bcdDevice : Device release number */
	MANUFACTURER_STR_INDEX,         /* 14 iManufacturer : Index of manufacturer string */
	PRODUCT_STR_INDEX,           	/* 15 iProduct : Index of product string descriptor */
	SERIAL_STR_INDEX,            	/* 16 iSerialNumber : Index of serial number decriptor */
	0x01             				/* 17 bNumConfigurations */
};

/* Device Descriptor for Null Device */
unsigned char devDesc_Null[] =
{
	18,              				/* 0  bLength : Size of descriptor in Bytes (18 Bytes) */
	DEVICE,               			/* 1  bdescriptorType */
	0,               				/* 2  bcdUSB */
	2,               				/* 3  bcdUSB */
	0x0,            				/* 4  bDeviceClass */
	0x0  ,               			/* 5  bDeviceSubClass */
	0x00,               			/* 6  bDeviceProtocol */
	64,              				/* 7  bMaxPacketSize */
	(VENDOR_ID & 0xFF),            	/* 8  idVendor */
	(VENDOR_ID >> 8),              	/* 9  idVendor */
	(PID_AUDIO_2 & 0xFF),           /* 10 idProduct */
	(PID_AUDIO_2 >> 8),             /* 11 idProduct */
	(BCD_DEVICE & 0xFF),           	/* 12 bcdDevice : Device release number */
	(BCD_DEVICE >> 8),              /* 13 bcdDevice : Device release number */
	MANUFACTURER_STR_INDEX,         /* 14 iManufacturer : Index of manufacturer string */
	PRODUCT_STR_INDEX,              /* 15 iProduct : Index of product string descriptor */
	SERIAL_STR_INDEX,            	/* 16 iSerialNumber : Index of serial number decriptor */
	0x01             				/* 17 bNumConfigurations : Number of possible configs */
};


/****** Device Qualifier Descriptors *****/

/* Device Qualifier Descriptor for Audio 2.0 device (Use when running at full-speed. Matches audio 2.0 device descriptor) */
unsigned char devQualDesc_Audio2[] =
{
	10,                             /* 0  bLength (10 Bytes) */
	DEVICE_QUALIFIER, 				/* 1  bDescriptorType */
	0x00,							/* 2  bcdUSB (Binary Coded Decimal of usb version) */
	0x02,      						/* 3  bcdUSB */
	0xEF,                           /* 4  bDeviceClass */
	0x02,                           /* 5  bDeviceSubClass */
	0x01,                           /* 6  bDeviceProtocol */
	64,                             /* 7  bMaxPacketSize */
	0x01,                           /* 8  bNumConfigurations : Number of possible configs */
	0x00                            /* 9  bReserved (must be zero) */
};

/* Device Qualifier Descriptor for Null Device (Use when running at high-speed) */
unsigned char devQualDesc_Null[] =
{
	10,                             /* 0  bLength (10 Bytes) */
	DEVICE_QUALIFIER, 				/* 1  bDescriptorType */
	0x00,							/* 2  bcdUSB (Binary Coded Decimal of usb version) */
	0x02,      						/* 3  bcdUSB */
	0x00,                           /* 4  bDeviceClass */
	0x00,                           /* 5  bDeviceSubClass */
	0x00,                           /* 6  bDeviceProtocol */
	64,                             /* 7  bMaxPacketSize */
	0x01,                           /* 8  bNumConfigurations : Number of possible configs */
	0x00                            /* 9  bReserved (must be zero) */
};

/* Total length of config descriptor */
#define CFG_TOTAL_LENGTH_A2			(7 + 26 + (INPUT_INTERFACES * 55) + (OUTPUT_INTERFACES * 62) + AC_TLEN)

/* Define for number of audio interfaces (+1 for mandatory control interface) */
#define AUDIO_INTERFACES			(INPUT_INTERFACES + OUTPUT_INTERFACES + 1)

#include "auto_descriptors.h"

/* Configuration Descriptor for Audio 2.0 (HS) operation */
unsigned char cfgDesc_Audio2[] =
{
	0x09,            				/* 0  bLength */
	CONFIGURATION,            		/* 1  bDescriptorType */
	(CFG_TOTAL_LENGTH_A2 & 0xFF),   /* 2  wTotalLength */
	(CFG_TOTAL_LENGTH_A2 >> 8),     /* 3  wTotalLength */
	NUM_INTERFACES,               	/* 4  bNumInterface: Number of interfaces*/
	0x01,            				/* 5  bConfigurationValue */
	0x00,            				/* 6  iConfiguration */
#ifdef SELF_POWERED
	192,                            /* 7  bmAttributes */
	5,             				    /* 8  bMaxPower */
#else
	128,                            /* 7  bmAttributes */
	250,             				/* 8  bMaxPower */
#endif

	/* Interface Association Descriptor */
	0x08,            				/* 0  bLength */
	0x0b,            				/* 1  bDescriptorType */
	0x00,            				/* 2  bFirstInterface */
	AUDIO_INTERFACES,            	/* 3  bInterfaceCount */
	AUDIO_FUNCTION,            		/* 4  bFunctionClass: AUDIO_FUNCTION */
	FUNCTION_SUBCLASS_UNDEFINED,    /* 5  bFunctionSubClass: FUNCTION_SUBCLASS_UNDEFINED */
	AF_VERSION_02_00,            	/* 6  bFunctionProtocol: AF_VERSION_02_00 */
	0x00,            				/* 7  iFunction (String Index) *(re-use iProduct) */

	/* Standard Audio Control Interface Descriptor (Note: Must be first with lowest interface number)r */
	0x09,            				/* 0  bLength: 9 */
	INTERFACE,            			/* 1  bDescriptorType: INTERFACE */
	0x00,            				/* 2  bInterfaceNumber */
	0x00,            				/* 3  bAlternateSetting: Must be 0 */
	0x01,            				/* 4  bNumEndpoints (0 or 1 if optional interrupt endpoint is present */
	AUDIO,               			/* 5  bInterfaceClass: AUDIO */
	AUDIOCONTROL,               	/* 6  bInterfaceSubClass: AUDIOCONTROL*/
	IP_VERSION_02_00,            	/* 7  bInterfaceProtocol: IP_VERSION_02_00 */
	PRODUCT_STR_INDEX,              /* 8  iInterface (re-use iProduct) */

	/* Class Specific Audio Control Descriptors */
	AC_DESCRIPTORS

#if 1
	/* Standard AS Interrupt Endpoint Descriptor (4.8.2.1): */
	0x07,                           /* 0  bLength: 7 */
	0x05,                           /* 1  bDescriptorType: ENDPOINT */
	0x84,                           /* 2  bEndpointAddress (D7: 0:out, 1:in) */
	3,                              /* 3  bmAttributes (bitmap)  */
	6,0,                            /* 4  wMaxPacketSize */
	8,                              /* 6  bInterval */
#endif

#ifdef OUTPUT
	/* Standard AS Interface Descriptor (4.9.1) */
	0x09,           				/* 0  bLength: (in bytes, 9) */
	INTERFACE,           			/* 1  bDescriptorType: INTERFACE */
	1,              				/* 2  bInterfaceNumber: Number of interface */
	0,              				/* 3  bAlternateSetting */
	0,              				/* 4  bNumEndpoints */
	AUDIO,           				/* 5  bInterfaceClass: AUDIO */
	AUDIOSTREAMING,           		/* 6  bInterfaceSubClass: AUDIO_STREAMING */
	IP_VERSION_02_00,           	/* 7  bInterfaceProtocol: IP_VERSION_02_00 */
	4,              				/* 8  iInterface: (Sting index) */

	/* Standard AS Interface Descriptor (4.9.1) (Alt) */
	0x09,           				/* 0  bLength: (in bytes, 9) */
	INTERFACE,           			/* 1  bDescriptorType: INTERFACE */
	1,              				/* 2  bInterfaceNumber: Number of interface */
	1,              				/* 3  bAlternateSetting */
	2,              				/* 4  bNumEndpoints */
	AUDIO,           				/* 5  bInterfaceClass: AUDIO */
	AUDIOSTREAMING,           		/* 6  bInterfaceSubClass: AUDIO_STREAMING */
	IP_VERSION_02_00,           	/* 7  bInterfaceProtocol: IP_VERSION_02_00 */
	4,              				/* 8  iInterface: (Sting index) */

	/* Class Specific AS Interface Descriptor */
	0x10,           				/* 0  bLength: 16 */
	CS_INTERFACE,           		/* 1  bDescriptorType: 0x24 */
	AS_GENERAL,     				/* 2  bDescriptorSubType */
	ID_USB_IN,              		/* 3  bTerminalLink (Linked to USB input terminal) */
	0x00,           				/* 4  bmControls */
	0x01,           				/* 5  bFormatType */
	PCM, 0x00, 0x00, 0x00,  		/* 6:10  bmFormats (note this is a bitmap) */
	NUM_USB_CHAN_OUT,               /* 11 bNrChannels */
	0x3f,0,0,0,    					/* 12:14: bmChannelConfig */
	0,              				/* 15 iChannelNames */

	/* Type 1 Format Type Descriptor */
	0x06,         					/* 0  bLength (in bytes): 6 */
	CS_INTERFACE,         			/* 1  bDescriptorType: 0x24 */
	FORMAT_TYPE,         			/* 2  bDescriptorSubtype: FORMAT_TYPE */
	FORMAT_TYPE_I,         			/* 3  bFormatType: FORMAT_TYPE_1 */
	0x04,         					/* 4  bSubslotSize (Number of bytes per subslot) */
	24,         					/* 5  bBitResolution (Number of bits used per subslot) */

	/* Standard AS Isochronous Audio Data Endpoint Descriptor (4.10.1.1) */
	0x07,           				/* 0  bLength: 7 */
	ENDPOINT,           			/* 1  bDescriptorType: ENDPOINT */
	0x01,            				/* 2  bEndpointAddress (D7: 0:out, 1:in) */
	0x05,              				/* 3  bmAttributes (bitmap)  */
	0,4,            				/* 4  wMaxPacketSize */
	1,              				/* 6  bInterval */

	/* Class-Specific AS Isochronous Audio Data Endpoint Descriptor (4.10.1.2) */
	0x08,           				/* 0   bLength */
	CS_ENDPOINT,           			/* 1   bDescriptorType */
	0x01,           				/* 2   bDescriptorSubtype */
	0x00,           				/* 3   bmAttributes */
	0x00,           				/* 4   bmControls (Bitmap: Pitch control, over/underun etc) */
	0x02,           				/* 5   bLockDelayUnits: Decoded PCM samples */
	8,0,            				/* 6:7 bLockDelay */

	/* Feedback EP */
	0x07,           				/* 0  bLength: 7 */
	ENDPOINT,           			/* 1  bDescriptorType: ENDPOINT */
	0x81,            				/* 2  bEndpointAddress (D7: 0:out, 1:in) */
	17,              				/* 3  bmAttributes (bitmap)  */
	4,0,            				/* 4  wMaxPacketSize */
	4,              				/* 6  bInterval. Only values <= 1 frame (8) supported by MS */

#endif /* OUTPUT */

#ifdef INPUT
	/* Standard AS Interface Descriptor (4.9.1) */
	0x09,          			 		/* 0  bLength: (in bytes, 9) */
	INTERFACE,           			/* 1  bDescriptorType: INTERFACE */
	(OUTPUT_INTERFACES + 1),        /* 2  bInterfaceNumber: Number of interface */
	0,              				/* 3  bAlternateSetting */
	0,              				/* 4  bNumEndpoints */
	AUDIO,           				/* 5  bInterfaceClass: AUDIO */
	AUDIOSTREAMING,           		/* 6  bInterfaceSubClass: AUDIO_STREAMING */
	0x20,           				/* 7  bInterfaceProtocol: IP_VERSION_02_00 */
	5,              				/* 8  iInterface: (Sting index) */

	/* Standard AS Interface Descriptor (4.9.1) (Alt) */
	0x09,           				/* 0  bLength: (in bytes, 9) */
	INTERFACE,           			/* 1  bDescriptorType: INTERFACE */
	(OUTPUT_INTERFACES + 1),        /* 2  bInterfaceNumber: Number of interface */
	1,              				/* 3  bAlternateSetting */
	1,              				/* 4  bNumEndpoints */
	AUDIO,           				/* 5  bInterfaceClass: AUDIO */
	AUDIOSTREAMING,           		/* 6  bInterfaceSubClass: AUDIO_STREAMING */
	IP_VERSION_02_00,           	/* 7  bInterfaceProtocol: IP_VERSION_02_00 */
	5,              				/* 8  iInterface: (Sting index) */

	/* Class Specific AS Interface Descriptor */
	0x10,           				/* 0  bLength: 16 */
	CS_INTERFACE,           		/* 1  bDescriptorType: 0x24 */
	AS_GENERAL,     				/* 2  bDescriptorSubType */
	ID_USB_OUT,              		/* 3  bTerminalLink */
	0x00,           				/* 4  bmControls */
	0x01,           				/* 5  bFormatType */
	PCM, 0x00, 0x00, 0x00,  		/* 6:10  bmFormats (note this is a bitmap) */
	NUM_USB_CHAN_IN,             /* 11 bNrChannels */
	0x3,0,0,0,    					/* 12:14: bmChannelConfig */
	0,            				    /* 15 iChannelNames */

	/* Type 1 Format Type Descriptor */
	0x06,         					/* 0  bLength (in bytes): 6 */
	CS_INTERFACE,         			/* 1  bDescriptorType: 0x24 */
	FORMAT_TYPE,         			/* 2  bDescriptorSubtype: FORMAT_TYPE */
	FORMAT_TYPE_I,         			/* 3  bFormatType: FORMAT_TYPE_1 */
	0x04,         					/* 4  bSubslotSize (Number of bytes per subslot) */
	24,         					/* 5  bBitResolution (Number of bits used per subslot) */

	/* Standard AS Isochronous Audio Data Endpoint Descriptor (4.10.1.1) */
	0x07,           				/* 0  bLength: 7 */
	ENDPOINT,           			/* 1  bDescriptorType: ENDPOINT */
	0x82,            				/* 2  bEndpointAddress (D7: 0:out, 1:in) */
	5,              				/* 3  bmAttributes (bitmap)  */
	0,4,            				/* 4  wMaxPacketSize */
	1,              				/* 6  bInterval */

	/* Class-Specific AS Isochronous Audio Data Endpoint Descriptor (4.10.1.2) */
	0x08,           				/* 0   bLength */
	CS_ENDPOINT,           			/* 1   bDescriptorType */
	0x01,           				/* 2   bDescriptorSubtype */
	0x00,          					/* 3   bmAttributes */
	0x00,           				/* 4   bmControls (Bitmap: Pitch control, over/underun etc) */
	0x02,           				/* 5   bLockDelayUnits: Decoded PCM samples */
	8,0,             				/* 6:7 bLockDelay */
#endif

};

/* String table */

static unsigned char strDescs_Audio2[][40] =
{
	/* 00 */ "Langids",       /* String 0 (LangIDs) place holder */
	/* 01 */ "XMOS",          /* iManufacturer (at MANUFACTURER_STRING_INDEX) */
	/* 02 */ "USB Audio 2.0", /* iProduct and iInterface for control interface (at PRODUCT_STR_INDEX) */
	/* 03 */ SERIAL_STR,      /* iSerialNumber (at SERIAL_STR_INDEX) */
	/* 04 */ "USB 2.0 Audio Out", /* iInterface for Streaming interaces */
	/* 05 */ "USB 2.0 Audio In",
	AC_STRINGS
};

/* Configuration Descriptor for Null device */
unsigned char cfgDesc_Null[] =
{
	0x09,                          	/* 0  bLength */
	CONFIGURATION,		            /* 1  bDescriptorType */
	0x12,                           /* 2  wTotalLength */
	0x00,                           /* 3  wTotalLength */
	0x01,                           /* 4  bNumInterface: Number of interfaces*/
	0x01,                           /* 5  bConfigurationValue */
	0x00,                           /* 6  iConfiguration */
#ifdef SELF_POWERED
	192,                             /* 7  bmAttributes */
#else
	128,
#endif
	250,                            /* 8  bMaxPower */

	0x09,                           /* 0 bLength : Size of this descriptor, in bytes. (field size 1 bytes) */
	0x04,                           /* 1 bDescriptorType : INTERFACE descriptor. (field size 1 bytes) */
	0x00,                         	/* 2 bInterfaceNumber : Index of this interface. (field size 1 bytes) */
	0x00,                          	/* 3 bAlternateSetting : Index of this setting. (field size 1 bytes) */
	0x00,                         	/* 4 bNumEndpoints : 0 endpoints. (field size 1 bytes) */
	0x00,                        	/* 5 bInterfaceClass :  */
	0x00,                          	/* 6 bInterfaceSubclass */
	0x00,                          	/* 7 bInterfaceProtocol : Unused. (field size 1 bytes) */
	0x00,                          	/* 8 iInterface : Unused. (field size 1 bytes) */
	0x09,            				/* 0  bLength */
};


#endif
