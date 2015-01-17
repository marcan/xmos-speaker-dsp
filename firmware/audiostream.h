/**
 * Module:  module_usb_aud_shared
 * Version: 2v1
 * Build:   c94813789b307c33f0bdf39ef72362df7ec27ce3
 * File:    audiostream.h
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
#ifndef _AUDIOSTREAM_H_
#define _AUDIOSTREAM_H_

/* Functions that handle functions that must occur on stream start/stop e.g. DAC mute/un-mute
 *
 * THESE NEED IMPLEMENTING FOR A SPECIFIC DESIGN
 *
 * */

/* Any actions required for stream start e.g. DAC un-mute - run every stream start */
void AudioStreamStart(void);

/* Any actions required on stream stop e.g. DAC mute - run every steam stop  */
void AudioStreamStop(void);

#endif

