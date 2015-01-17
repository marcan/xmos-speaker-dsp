/**
 * Module:  app_usb_aud_l2
 * Version: 5v00
 * Build:   bdb0bad2e22d60206c570bfea8758095c46d1519
 * File:    audiostream.xc
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
 * These need implementing for a specific design.
 *
 * Implementations for the L2 USB Audio Reference Design 
 */

/* Any actions required for stream start e.g. DAC un-mute - run every stream start 
 */
void AudioStreamStart(void)
{
   // Do nothing... 
}

/* Any actions required on stream stop e.g. DAC mute - run every steam stop 
 */
void AudioStreamStop(void)
{
   // Do nothing... 
}
#endif

