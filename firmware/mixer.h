/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta12
 * Build:   782797bf7a66eb5078d3ad6655b9f2ce768f1274
 * File:    mixer.h
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
#ifndef __mixer_h__
#define __mixer_h__

enum mix_ctl_cmd {
  SET_SAMPLES_TO_HOST_MAP,
  SET_SAMPLES_TO_DEVICE_MAP,
  SET_MIX_MULT,
  SET_MIX_MAP,
  SET_MIX_IN_VOL,
  SET_MIX_OUT_VOL,
  GET_INPUT_LEVELS,
  GET_STREAM_LEVELS,
  GET_OUTPUT_LEVELS
};


/** Digital sample mixer.
 *
 *  This thread mixes audio streams between the decouple() thread and
 *  the audio() thread.
 * 
 *  \param c_to_host a chanend connected to the decouple() thread for
 *                   receiving/transmitting samples
 *  \param c_to_audio a chanend connected to the audio() thread for
 *                    receiving/transmitting samples
 *  \param c_mix_ctl a chanend connected to the Endpoint0() thread for
 *                   receiving control commands 
 * 
 */
void mixer(chanend c_to_host, chanend c_to_audio, chanend c_mix_ctl);

#endif
