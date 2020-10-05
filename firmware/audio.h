/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta14
 * Build:   396662e655a947309bcc1f260c601ec64836abc1
 * File:    audio.h
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
#ifndef __audio_h__
#define __audio_h__

/** The audio driver thread.
 *
 *  This function drives I2S ports and handles samples to/from other digital 
 *  I/O threads.
 * 
 *  \param c_in Audio sample channel connected to the mixer() thread or the
 *              decouple() thread
 *  \param c_dig channel connected to the clockGen() thread for 
 *               receiving/transmitting samples
 *  \param c_config An optional channel that will be passed on to the 
 *                  CODEC configuration functions.
 */
void audio(chanend c_in, chanend ?c_dig, chanend ?c_config, chanend ?c_peaks);

#endif // __audio_h__
