/**
 * Module:  module_usb_aud_shared
 * Version: 2v3
 * Build:   e7a385b28d1c8c508ddaa0746176088124c18651
 * File:    decouple.h
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
#ifndef __decouple_h__
#define __decouple_h__


/** Manage the data transfer between the USB audio buffer and the 
 *  Audio I/O driver.
 *  
 * \param c_audio_out Channel connected to the audio() or mixer() threads
 * \param c_led Optional chanend connected to an led driver thread for
 *              debugging purposes
 * \param c_midi Optional chanend connect to usb_midi() thread if present
 * \param c_clk_int Optional chanend connected to the clockGen() thread if present
 */
void decouple(chanend c_audio_out,
              chanend ?c_clk_int, chanend ?c_led);

#endif // __decouple_h__
