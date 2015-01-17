/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta10
 * Build:   f542ddaaa188ea8357dea7b588dca0ca2bdb2343
 * File:    dbcalc.h
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
#ifndef __dbcalc_h__
#define __dbcalc_h__

/* Function: db_to_mult

     This function converts decibels into a volume multiplier. It uses a fixed-point polynomial approximation
     to 10^(db/10).

   Parameters:
       db               - The db value to convert.
       db_frac_bits     - The number of binary fractional bits in the supplied decibel value  
       result_frac_bits - The number of required fractional bits in the result.

   Returns:
       The multiplier value as a fixed point value with the number of fractional bits as specified by
       the result_frac_bits parameter.
*/
unsigned db_to_mult(int db, int db_frac_bits, int result_frac_bits);

#endif // __dbcalc_h__
