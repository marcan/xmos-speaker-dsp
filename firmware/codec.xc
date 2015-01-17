/**
* Module:  app_usb_aud_l2
* Version: 3v00
* Build:   89ae0a5f3b92ea061d7202203563a40eef315ca4
* File:    codec.xc
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
#include "devicedefines.h"
#include "i2c.h"
#include <print.h>

/* I2C ports */
extern port p_i2c_sda;
extern port p_i2c_scl;

extern out port p_aud_cfg;

#define COD_DEV_ADRS       0x90
#define SYNC_DEV_ADRS      0x9C

/* CODEC initialisation for Cirrus Logic CS42448 */
void CodecInit(chanend ?c_codec)
{
	unsigned tmp;

	/* Clock buffers and CODEC out of reset */
#ifdef CODEC_SLAVE
	p_aud_cfg <: 0b0000 @ tmp;
	tmp += 1000;
	p_aud_cfg @ tmp <: 0b1000;
#else
	p_aud_cfg <: 0b0010 @ tmp;
	tmp += 1000;
	p_aud_cfg @ tmp  <: 0b1010;
#endif

	/* Power Control Register (Address 02h) */
	/* 0    Power Down                           (PDN)   = 1 Enable, 0 Disable */
	/* 1:4  Power Down DAC Pairs            (PDN_DACX)   = 1 Enable, 0 Disable */
	/* 5:7  Power Down ADC Pairs            (PDN_ADCX)   = 1 Enable, 0 Disable */
	tmp = 0x01;
	I2cRegWrite(COD_DEV_ADRS, 0x2, tmp, p_i2c_scl, p_i2c_sda);

	/* Interface Formats Register (Address 04h)             */
	/* 0    Freeze Controls                    (FREEZE)     = 0,               */
	/* 1    Auxiliary Digital Interface Format (AUX_DIF)    = 0, */
	/* 2:4  DAC Digital Interface Format       (DAC_DIF)    = 001 (I2S) */
	/* 5:7  ADC Digital Interface Format       (ADC_DIF)    = 001 (I2S) */
	tmp = 0x09;
	I2cRegWrite(COD_DEV_ADRS, 0x4, tmp, p_i2c_scl, p_i2c_sda);

	tmp = (-12) & 0xff;
	I2cRegWrite(COD_DEV_ADRS, 0x11, tmp, p_i2c_scl, p_i2c_sda);
	I2cRegWrite(COD_DEV_ADRS, 0x12, tmp, p_i2c_scl, p_i2c_sda);
	I2cRegWrite(COD_DEV_ADRS, 0x13, tmp, p_i2c_scl, p_i2c_sda);
	I2cRegWrite(COD_DEV_ADRS, 0x14, tmp, p_i2c_scl, p_i2c_sda);
	I2cRegWrite(COD_DEV_ADRS, 0x15, tmp, p_i2c_scl, p_i2c_sda);
	I2cRegWrite(COD_DEV_ADRS, 0x16, tmp, p_i2c_scl, p_i2c_sda);

	/* ADC Control & DAC De-Emphasis (Address 05h) */
	/* 0   ADC1-2_HPF FREEZE = 0, */
	/* 1   ADC3_HPF FREEZE = 0, */
	/* 2   DAC_DEM = 0, */
	/* 3   ADC1_SINGLE = 1(single ended), */
	/* 4   ADC2_SINGLE = 1, */
	/* 5   ADC3_SINGLE = 1, */
	/* 6   AIN5_MUX = 0, */
	/* 7   AIN6_MUX = 0 */
	tmp = 0x1C;
	I2cRegWrite(COD_DEV_ADRS, 0x5, tmp, p_i2c_scl, p_i2c_sda);

	/* Power Control Register (Address 02h) - PDN disable */
	tmp = 0x00;
	I2cRegWrite(COD_DEV_ADRS, 0x2, tmp, p_i2c_scl, p_i2c_sda);

}

/* CODEC configuration for sample frequency change for Cirrus Logic CS42448 */
void CodecConfig(unsigned samFreq, unsigned mClk, chanend ?c_codec)
{
	unsigned tmp;

	/* Functional Mode (Address 03h) */
	/* 0:1  DAC Functional Mode                    Slave:Auto-detect samp rate      11 */
	/* 2:3  ADC Functional Mode                    Slave:Auto -detect samp rate     11 */
	/*                                             Master: Single                   00 */
	/*                                             Master: Double                   01 */
	/*                                             Master: Quad                     10 */
	/* 4:6  MCLK Frequency                         256/128/64 :                    000 */
	/*                                             512/256/128:                    010 */
	/* 7                                           Reserved                            */
#ifdef CODEC_SLAVE
	tmp = 0b11110000;                                             /* Autodetect */
#else
	if(samFreq < 50000)
	{
		tmp = 0b00000000;
	}
	else if(samFreq < 100000)
	{
		tmp = 0b01010000;
	}
	else
	{
		tmp = 0b10100000;
	}
#endif
	if(mClk < 15000000)
	{
		tmp |= 0;                   // 256/128/64
	}
	else if(mClk < 25000000)
	{
		tmp |= 0b00000100;            // 512/256/128
	}
	else
	{
		printstrln("Err: MCLK currently not supported");
	}

	I2cRegWrite(COD_DEV_ADRS, 0x3, tmp, p_i2c_scl, p_i2c_sda);
}

