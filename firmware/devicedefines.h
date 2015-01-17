/**
 * Module:  module_usb_aud_shared
 * Version: 2v4
 * Build:   0d7477798fc2c4749eec66c9d1555b9dd2c3fe8a
 * File:    devicedefines.h
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
 * @file        internaldefines.h
 * @brief       Defines relating to device configuration and customisation.
 * @author      Ross Owen, XMOS Limited
 */

#ifndef _DEVICEDEFINES_H_
#define _DEVICEDEFINES_H_

#include "customdefines.h"

/* Tidy up historical INPUT/OUTPUT defines. INPUT/OUTPUT now enabled based on channel count defines */
#if !defined(NUM_USB_CHAN_IN)
    #error NUM_USB_CHAN_IN must be defined!
#else
    #if (NUM_USB_CHAN_IN == 0)
        #undef INPUT
    #else
        #define INPUT 1
    #endif
#endif

#if !defined(NUM_USB_CHAN_OUT)
    #error NUM_USB_CHAN_OUT must be defined!
#else
    #if (NUM_USB_CHAN_OUT == 0)
        #undef OUTPUT
    #else
        #define OUTPUT 1
    #endif
#endif

#if defined(INPUT) && (INPUT == 0)
#undef INPUT
#endif

#if defined(OUTPUT) && (OUTPUT == 0)
#undef OUTPUT
#endif

#if defined(CODEC_SLAVE) && (CODEC_SLAVE == 0)
#undef CODEC_SLAVE
#endif

#if defined(LEVEL_METER_LEDS) && !defined(LEVEL_UPDATE_RATE)
#define LEVEL_UPDATE_RATE   400000
#endif

#define AUDIO_CLASS 2

/* Number of IS2 chans to DAC */
#ifndef I2S_CHANS_DAC
#error I2S_CHANS_DAC not defined
#else
#define I2S_WIRES_DAC               (I2S_CHANS_DAC >> 1)
#endif

/* Number of I2S chans from ADC */
#ifndef I2S_CHANS_ADC
#error I2S_CHANS_ADC not defined
#else
#define I2S_WIRES_ADC               (I2S_CHANS_ADC >> 1)
#endif

/* Max supported freq for device */
#ifndef MAX_FREQ
#warning MAX_FREQ not defined! Using 48000
#define MAX_FREQ                        (48000)       
#endif

/* Default device freq */
#ifndef DEFAULT_FREQ
#warning DEFAULT not defined! Using MAX_FREQ
#define DEFAULT_FREQ                    (MAX_FREQ)     
#endif

/* Master clock defines (in Hz) */
#ifndef MCLK_441                 
#error MCLK_441 not defined
#endif

#ifndef MCLK_48                
#error MCLK_441 not defined
#endif

/* The number of clock ticks to wait for the audio PLL to lock */
#define AUDIO_PLL_LOCK_DELAY     (40000000) 

/* Vendor/Product strings */
#ifndef VENDOR_STR
#define VENDOR_STR               "XMOS "   
//#warning VENDOR_STR not defined. Using XMOS
#endif

#ifndef VENDOR_ID
#warning VENDOR_ID not defined. Using XMOS vendor ID
#define VENDOR_ID                (0x20B1)        /* XMOS VID */
#endif

#ifndef PID_AUDIO_1
#define PID_AUDIO_1               (0x0001)        
#warning PRODUCT_ID not defined. Using 0x0001
#endif

#ifndef PID_AUDIO_2
#define PID_AUDIO_2               (0x0001)        
#warning PRODUCT_ID not defined. Using 0x0001
#endif

/* Device release number in BCD: 0xJJMNi */
#ifndef BCD_DEVICE
#define BCD_DEVICE               (0x0000)       
#warning BCD_DEVICE not defined. Using 0x0000
#endif

/* Addition interfaces based on defines */
#if defined(DFU) && DFU != 0
#define DFU_INTERFACES          (1)               /* DFU interface count */
#else
#define DFU_INTERFACES          (0)
#endif

#ifdef INPUT
#define INPUT_INTERFACES        (1)
#else
#define INPUT_INTERFACES        (0)
#endif

#if defined(OUTPUT) && OUTPUT != 0
#define OUTPUT_INTERFACES       (1)
#else
#define OUTPUT_INTERFACES       (0)
#endif


#if defined(MIDI)
#define MIDI_INTERFACES         (2)
#else
#define MIDI_INTERFACES         (0)
#endif

#define AUDIO_STOP_FOR_DFU	    (0x12345678)
#define AUDIO_START_FROM_DFU    (0x87654321)
#define AUDIO_REBOOT_FROM_DFU   (0xa5a5a5a5)


#define MAX_VOL                 (0x20000000)

#define NUM_EP_OUT               3               /* Max number of device endpoints used */
#define NUM_EP_IN                5
/* Length of clock unit/clock-selector units */
#define NUM_CLOCKS                  1


/* Total number of USB interfaces this device implements (+1 for required control interface) */
#define NUM_INTERFACES          INPUT_INTERFACES + OUTPUT_INTERFACES + DFU_INTERFACES + MIDI_INTERFACES + 1

#ifndef SERIAL_STR
#define SERIAL_STR                  "0000"          /* Serial number string */
#endif

#define SERIAL_STR_INDEX	        0x03
#define MANUFACTURER_STR_INDEX	    0x01
#define PRODUCT_STR_INDEX           0x02

/* Mixer defines */
#ifndef MIX_INPUTS
#define MIX_INPUTS                  18
#endif

#ifndef MAX_MIX_COUNT
#define MAX_MIX_COUNT               8
#endif


/* Volume defines */

#ifndef MIN_VOLUME
/* The minimum volume setting above -inf. This is a signed 8.8 fixed point
   number that must be strictly greater than -128 (0x8000) */
/* Default min volume is -127db */
#define MIN_VOLUME (0x8100)
#endif

#ifndef MAX_VOLUME
/* The maximum volume setting. This is a signed 8.8 fixed point number. */
/* Default max volume is 0db */
#define MAX_VOLUME (0x0000)
#endif

#ifndef VOLUME_RES
/* The resolution of the volume control in db as a 8.8 fixed point number */
/* Default volume resolution 1db */
#define VOLUME_RES (0x100)
#endif


#ifndef MIN_MIXER_VOLUME
/* The minimum volume setting for the mixer unit above -inf. 
   This is a signed 8.8 fixed point
   number that must be strictly greater than -128 (0x8000) */
/* Default min volume is -127db */
#define MIN_MIXER_VOLUME (0x8100)
#endif

#ifndef MAX_MIXER_VOLUME
/* The maximum volume setting for the mixer. 
   This is a signed 8.8 fixed point number. */
/* Default max volume is 0db */
#define MAX_MIXER_VOLUME (0x0000)
#endif

#ifndef VOLUME_RES_MIXER
/* The resolution of the volume control in db as a 8.8 fixed point number */
/* Default volume resolution 1db */
#define VOLUME_RES_MIXER (0x100)
#endif

/* Handle out volume control in the mixer */
#if defined(OUT_VOLUME_IN_MIXER) && (OUT_VOLUME_IN_MIXER==0)
#undef OUT_VOLUME_IN_MIXER
#else
#if defined(MIXER)
// Enabled by default
#define OUT_VOLUME_IN_MIXER
#endif
#endif

/* Apply out volume controls after the mix */
#if defined(OUT_VOLUME_AFTER_MIX) && (OUT_VOLUME_AFTER_MIX==0)
#undef OUT_VOLUME_AFTER_MIX
#else
#if defined(MIXER) && defined(OUT_VOLUME_IN_MIXER)
// Enabled by default
#define OUT_VOLUME_AFTER_MIX
#endif
#endif

/* Define for reporting as self or bus-powered to the host */
#if defined(SELF_POWERED) && (SELF_POWERED==0)
#undef SELF_POWERED
#endif

/* Handle in volume control in the mixer */
#if defined(IN_VOLUME_IN_MIXER) && (IN_VOLUME_IN_MIXER==0)
#undef IN_VOLUME_IN_MIXER
#else
#if defined(MIXER)
/* Enabled by default */
#define IN_VOLUME_IN_MIXER
#endif
#endif

/* Apply in volume controls after the mix */
#if defined(IN_VOLUME_AFTER_MIX) && (IN_VOLUME_AFTER_MIX==0)
#undef IN_VOLUME_AFTER_MIX
#else
#if defined(MIXER) && defined(IN_VOLUME_IN_MIXER)
// Enabled by default
#define IN_VOLUME_AFTER_MIX
#endif
#endif

#if defined(AUDIO_CLASS_FALLBACK) && (AUDIO_CLASS_FALLBACK==0)
#undef AUDIO_CLASS_FALLBACK
#endif

/* Defines for DFU */
#ifndef PID_DFU
#define PID_DFU PID_AUDIO_2
#endif

#define DFU_VENDOR_ID               VENDOR_ID
#define DFU_BCD_DEVICE              BCD_DEVICE
#define DFU_SERIAL_STR_INDEX        SERIAL_STR_INDEX
#define DFU_MANUFACTURER_INDEX      MANUFACTURER_STR_INDEX
#define DFU_PRODUCT_INDEX           PRODUCT_STR_INDEX
#endif
