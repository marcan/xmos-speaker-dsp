/**
 * Module:  module_usb_aud_shared
 * Version: 2v0
 * Build:   a5a29cb961dbeda79384d1319b2a9dc4f8f6efca
 * File:    codec.h
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
#ifndef _CODEC_H_
#define _CODEC_H_

/* These functions must be implemented for the CODEC/ADC/DAC arrangement of a specific design */

/* TODO Are the channel args required? */

/* Any required CODEC initialisation - run once at start up */
void CodecInit(chanend ?c_codec);

/* Configure condec for a specific mClk/Sample frquency - run on every sample frequency change */
void CodecConfig(unsigned samFreq, unsigned mClk, chanend ?c_codec);

#endif
