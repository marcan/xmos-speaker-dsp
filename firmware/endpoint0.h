/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta12
 * Build:   51aff4f427c5b2c11624d86ac8ca955d8976bfb2
 * File:    endpoint0.h
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

#ifndef _ENDPOINT0_H_
#define _ENDPOINT0_H_

/** Function implementing Endpoint 0 for enumeration, control and configuration 
 *  of USB audio devices. It uses the descriptors defined in ``descriptors_2.h``.
 *  
 *  \param c_ep0_out Chanend connected to the XUD_Manager() out endpoint array
 *  \param c_ep0_in Chanend connected to the XUD_Manager() in endpoint array
 *  \param c_audioCtrl Chanend connected to the decouple thread for control 
 *                     audio (sample rate changes etc.)
 *  \param c_mix_ctl Optional chanend to be connected to the mixer thread if
 *                   present
 *  \param c_clk_ctl Optional chanend to be connected to the clockgen thread if
 *                   present.
 */
void Endpoint0( chanend c_ep0_out, chanend c_ep0_in, chanend c_audioCtrl, chanend ?c_mix_ctl,chanend ?c_clk_ctl, chanend c_dsp_ctl
);

#endif
