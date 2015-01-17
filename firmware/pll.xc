/**
 * Module:  app_usb_aud_l2
 * Version: 5v00
 * Build:   4ecd7ef5e1e14be120ba7c10316070b643809339
 * File:    pll.xc
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
#include <platform.h>
#include <assert.h>

#include "i2c.h"

#define DEV_ADR      0x9C   

#define PLL_REGRD(reg) 		I2cRegRead(DEV_ADR, reg,  p_i2c_scl, p_i2c_sda)
#define PLL_REGWR(reg, val) I2cRegWrite(DEV_ADR, reg, val,  p_i2c_scl, p_i2c_sda)

/* I2C ports */
extern port p_i2c_sda;
extern port p_i2c_scl;

/* Init of CS2300 */
void PllInit(void)
{
	/* Enable init */
    //PLL_REGWR(0x1e, 0b01110000); // increase pll bandwidth to reduce lock time
    PLL_REGWR(0x03, 0x07);
    PLL_REGWR(0x05, 0x01);
    PLL_REGWR(0x16, 0x10);
    //    PLL_REGWR(0x17, 0x10); //0x10 for always gen clock even when unlocked
    PLL_REGWR(0x17, 0x00); //0x10 for always gen clock even when unlocked


  	/* Check */
	assert(PLL_REGRD(0x03) == 0x07);
    assert(PLL_REGRD(0x05) == 0x01);
    assert(PLL_REGRD(0x16) == 0x10);
    assert(PLL_REGRD(0x17) == 0x00);
    //assert(PLL_REGRD(0x1e) == 0b01110000);
}

/* Setup PLL multiplier */
void PllMult(unsigned mult)
{
	/* Multiplier is translated to 20.12 format by shifting left by 12 */
  	PLL_REGWR(0x06, (mult >> 12) & 0xFF);
  	PLL_REGWR(0x07, (mult >> 4) & 0xFF);
  	PLL_REGWR(0x08, (mult << 4) & 0xFF);
  	PLL_REGWR(0x09, 0x00);

	/* Check */
	assert(PLL_REGRD(0x06) == ((mult >> 12) & 0xFF));
    assert(PLL_REGRD(0x07) == ((mult >> 4) & 0xFF));
    assert(PLL_REGRD(0x08) == ((mult << 4) & 0xFF));
    assert(PLL_REGRD(0x09) == 0x00);
}


