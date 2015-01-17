/**
 * Module:  app_usb_aud_l2
 * Version: 3v00
 * Build:   89ae0a5f3b92ea061d7202203563a40eef315ca4
 * File:    clocking.xc
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
/* These functions must be implemented for the clocking arrangement of specific design */

#include "pll.h"

void ClockingInit()
{
    /* For L2 reference design initialise the external fractional-n clock multiplier - see pll.xc */
    PllInit();
}

void ClockingConfig(unsigned mClkFreq)
{
    /* For L2 reference design configure external fractional-n clock multiplier for 300Hz -> mClkFreq */
    PllMult(mClkFreq/300);
}
