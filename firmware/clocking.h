/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta14
 * Build:   396662e655a947309bcc1f260c601ec64836abc1
 * File:    clocking.h
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

#ifndef _CLOCKING_H_
#define _CLOCKING_H_

/* Functions that handle master clock generation.  These need modifying for an existing design */

/* Any initialisation required for master clock generation - run once at start up */
void ClockingInit(void);

/* Configuration for a specific master clock frequency - run every sample frequency change */
void ClockingConfig(unsigned mClkFreq);


/** Clock generation and digital audio I/O handling.
 *
 *  \param c_spdif_rx channel connected to S/PDIF receive thread
 *  \param c_adat_rx channel connect to ADAT receive thread
 *  \param p port to output clock signal to drive external frequency synthesizer
 *  \param c_audio channel connected to the audio() thread
 *  \param c_clk_ctl channel connected to Endpoint0() for configuration of the 
 *                   clock
 *  \param c_clk_int channel connected to the decouple() thread for clock
                     interrupts
 */
void clockGen (streaming chanend c_spdif_rx, chanend c_adat_rx, out port p, chanend c_audio, chanend c_clk_ctl, chanend c_clk_int);
#endif

