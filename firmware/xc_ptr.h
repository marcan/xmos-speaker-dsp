/**
 * Module:  module_usb_aud_shared
 * Version: 2v0
 * Build:   c0b2e34218aec54736ad1259d95377c59ed03dd3
 * File:    xc_ptr.h
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
#ifndef __xc_ptr__
#define __xc_ptr__

typedef unsigned int xc_ptr;

inline xc_ptr array_to_xc_ptr(unsigned a[]) {
  xc_ptr x;
  asm("mov %0, %1":"=r"(x):"r"(a));
  return x;
}

#define write_via_xc_ptr(p,x)   asm("stw %0, %1[0]"::"r"(x),"r"(p))

#define write_via_xc_ptr_indexed(p,i,x)   asm("stw %0, %1[%2]"::"r"(x),"r"(p),"r"(i))

#define read_via_xc_ptr(x,p)  asm("ldw %0, %1[0]":"=r"(x):"r"(p));

#define read_via_xc_ptr_indexed(x,p,i)  asm("ldw %0, %1[%2]":"=r"(x):"r"(p),"r"(i));

#define GET_SHARED_GLOBAL(x, g) asm("ldw %0, dp[" #g "]":"=r"(x))
#define SET_SHARED_GLOBAL(g, v) asm("stw %0, dp[" #g "]"::"r"(v))

#endif 
