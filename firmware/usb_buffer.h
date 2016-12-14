/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta12
 * Build:   a3e26005ac327c50f978224d03666749aea1c70a
 * File:    usb_buffer.h
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
#ifndef __usb_buffer_h__
#define __usb_buffer_h__
/** USB Audio Buffering Thread.
 *
 *  This function buffers USB audio data between the XUD layer and the decouple
 *  thread. Most of the chanend parameters to the function should be connected to
 *  XUD_Manager()
 *
 *  \param c_aud_out Audio OUT endpoint channel connected to the XUD
 *  \param c_aud_in  Audio IN endpoint channel connected to the XUD
 *  \param c_aud_fb  Audio feedback endpoint channel connected to the XUD
 *  \param c_midi_from_host  MIDI OUT endpoint channel connected to the XUD
 *  \param c_midi_to_host  MIDI IN endpoint channel connected to the XUD
 *  \param c_int  Audio clocking interrupt endpoint channel connected to the XUD
 *  \param c_sof  Start of frame channel connected to the XUD
 *  \param c_aud_ctl Audio control channel connected to  Endpoint0()
 *  \param p_off_mclk A port that is clocked of the MCLK input (not the MCLK input itself)
 */
void buffer(chanend c_aud_out, chanend c_aud_in, chanend c_aud_fb, 
            chanend c_int, 
            chanend c_sof, 
            chanend c_aud_ctl,
            in port p_off_mclk);


#endif
