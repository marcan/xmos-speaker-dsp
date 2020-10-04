/**
 * Module:  module_usb_aud_shared
 * Version: 2v2beta14
 * Build:   828cd13ccba5efa7d63ff5d0c967357ccd0c8ad4
 * File:    fastmix.S
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

#define DOMIX_TOP(i) \
.cc_top doMix##i.function,doMix##i; \
          .align    4 ;\
.globl doMix##i ;\
.globl doMix##i##.nstackwords ;\
.globl doMix##i##.maxthreads ; \
.globl doMix##i##.maxtimers ; \
.globl doMix##i##.maxchanends ; \
.globl doMix##i##.maxsync ;\
.linkset doMix##i##.locnoside, 1; \
.linkset doMix##i##.locnochandec, 1;\
.linkset doMix##i##.nstackwords, 0 ;\
.linkset doMix##i##.maxchanends, 0 ;\
.linkset doMix##i##.maxtimers, 0 ;\
.linkset doMix##i##.maxthreads, 1; \
doMix##i##: ;\
          set       cp, r0; \
          set       dp, r1; \
          lsub      r0, r1, r0, r0, r0;\

#define DOMIX_BOT(i) \
         ldap      r11, _dp; \
          set       dp, r11;\
          ldap      r11, _cp;\
          set       cp, r11;\
\
          mov       r0, r1;\
          ldc       r2, 0x19;\
          sext      r0, r2;\
          eq        r0, r0, r1;\
          bf        r0, .L20; \
\
          shl       r0, r1, 0x7;\
          retsp     0x0;\
\
\
.cc_bottom doMix##i##.function;

#define BODY(i) \
          ldw       r2, cp[i]; \
          ldw       r11, dp[i];  \
          maccs     r1, r0, r2, r11;


.text 

.L20:\
          lss       r0, r1, r3;\
          bt        r0, .L16; \
          ldw       r0, cp[.LC0];\
          retsp     0x0; \
.L16:\
          ldw       r0, cp[.LC1];\
          retsp     0x0; \




#define N MIX_INPUTS
DOMIX_TOP(_out)
#include "repeat.h" 
DOMIX_BOT(_out)

#undef N
#define N AUX_COUNT
DOMIX_TOP(_in)
#include "repeat.h"
DOMIX_BOT(_in)

          .section .cp.const4,     "acM", @progbits, 4
.LC0:
          .align    4
          .int      0x7fffff00
.LC1:
          .int      0x80000000

#undef N
#undef BODY



