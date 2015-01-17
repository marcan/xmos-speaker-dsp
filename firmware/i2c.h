/**
 * Module:  module_usb_aud_shared
 * Version: 2v0
 * Build:   334eaf5834c010b803eaca46139f6c8c8412879c
 * File:    i2c.h
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

void I2cRegWrite(int deviceAdrs, int Adrs, int WrData,  port AUD_SCLK, port AUD_SDIN);

int I2cRegRead(int deviceAdrs, int Adrs, port AUD_SCLK, port AUD_SDIN);
