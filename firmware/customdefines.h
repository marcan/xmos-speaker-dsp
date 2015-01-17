/**
 * Module:  app_usb_aud_l2
 * Version: 5v3rc0
 * Build:   c653036bf3addcd9dae8deb06615fc62ae14ac93
 * File:    customdefines.h
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
 * @file        customdefines.h
 * @brief       Defines relating to device configuration and customisation.
 * @author      Ross Owen, XMOS Limited
 */
#ifndef _CUSTOMDEFINES_H_
#define _CUSTOMDEFINES_H_

//#define XUD_DEBUG_VERSION
//#define DEBUG

#ifdef DEBUG
#define dprintf printf
#else
#define dprintf(...) while(0)
#endif

#define DEBUG_LEDS

/***** Device configuration option defines.  Build can be customised but changing these defines  *****/

/* Audio Class Version */
#define AUDIO_CLASS         2

/* Defines relating to channel count and channel arrangement (0 for disable) */ 
/* Number of USB streaming channels */
#define NUM_USB_CHAN_IN             (2)               /* Device to Host */
#define NUM_USB_CHAN_OUT            (6)               /* Host to Device */

#define OUT_VOLUME_IN_MIXER 0
#define IN_VOLUME_IN_MIXER 0
#define OUT_VOLUME_AFTER_MIX 0
#define IN_VOLUME_AFTER_MIX 0

#define MAX_MIX_COUNT 8
#define MIX_INPUTS 12

#define SELF_POWERED 1

/* Define for CODEC operation mode (i.e. slave/master)*/
#if defined(CODEC_SLAVE) && (CODEC_SLAVE==0)
#undef CODEC_SLAVE
#else
// Enabled by default
#define CODEC_SLAVE        1    
#endif

/* Define for enabling mixer interface */
#if defined(MIXER) && (MIXER==0)
#undef MIXER
#else
// Enabled by default
#define MIXER
#endif

/* Number of IS2 chans to DAC..*/
#define I2S_CHANS_DAC               (8)

/* Number of I2S chans from ADC */
#define I2S_CHANS_ADC               (6)


/* Master clock defines (in Hz) */
#define MCLK_441                 (256*44100)      /* 44.1, 88.2 etc */
#define MCLK_48                  (256*48000)      /* 48, 96 etc */

/* Maximum frequency device runs at */
#define MAX_FREQ                 (96000)       

/* Default frequency device reports as running at */
#define DEFAULT_FREQ             (MAX_FREQ)       

/***** Defines relating to USB descriptors etc *****/
#define VENDOR_STR				 "XMOS "
#define VENDOR_ID                (0x20B1)        /* XMOS VID */
#define PID_AUDIO_1              (0x0005)        
#define PID_AUDIO_2              (0x0004)  
#ifndef BCD_DEVICE
#define BCD_DEVICE               (0x0530)        /* Device release number in BCD: 0xJJMN
                                                 * JJ: Major, M: Minor, N: Sub-minor */
#endif

//#define  LEVEL_METER_PROCESSING     1
//#define  LEVEL_METER_LEDS           1           /* Enables call to VendorLedRefresh() */
//#define  CLOCK_VALIDITY_CALL        1           /* Enables calls to VendorClockValidity(int valid) */ 
#define  HOST_ACTIVE_CALL           1           /* Enabled call to VendorHostActive(int active); */

#ifdef HOST_ACTIVE_CALL                         /* L2 ref design board uses audio core reqs for host active */
/*
#ifndef VENDOR_AUDCORE_REQS
#define  VENDOR_AUDCORE_REQS        1
#endif

#ifndef VENDOR_AUDIO_REQS
#define  VENDOR_AUDIO_REQS          1
#endif
*/
#endif

//#define MAX_MIX_OUTPUTS             0


#endif
