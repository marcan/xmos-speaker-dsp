// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include "dsp.h"

#define NWORDS 7

    .globl biquad_cascade
    .globl biquad_cascade.nstackwords
    .linkset biquad_cascade.nstackwords,NWORDS
    .align 4
biquad_cascade:
    entsp NWORDS
    stw   r4, sp[0]
    stw   r5, sp[1]
    stw   r6, sp[2]
    stw   r7, sp[3]
    stw   r8, sp[4]
    stw   r9, sp[5]
    stw   r10, sp[6]

    mov   r10, r3

    // r0: xn
    // r1: count
    // r2: biquads
    // r3: xn1
    // r4: xn2
    // r5: tmp
    // r6: FRACTIONALBITS
    // r7: 1<<(FRACTIONALBITS-1)
    // r8: accl
    // r9: acch
    // r10: headroombits

    ldc   r6, FRACTIONALBITS

    ldw   r3, r2[0]

    ashr   r0, r0, r10

    ldc   r9, 0
    ldc   r7, 1
    ldw   r4, r2[1]
    shl   r7, r7, r6
    shr   r7, r7, 1

loop:
    mov    r8, r7
    ldw   r5, r2[2]               // Coefficient b0
    maccs r9, r8, r5, r0          // Multiply by xn
    ldw   r5, r2[3]               // Coefficient b1
    maccs r9, r8, r5, r3          // Multiply by xn1
    ldw   r5, r2[4]               // Coefficient b2
    maccs r9, r8, r5, r4          // Multiply by xn2

    stw   r0, r2[0]               // Save xn into xn1
    stw   r3, r2[1]               // Save xn1 into xn2

    ldw   r5, r2[5]               // Coefficient a1
    ldw   r3, r2[7]               // Load yn1 (next filter xn1)
    maccs r9, r8, r5, r3
    ldw   r5, r2[6]               // Coefficient a2
    ldw   r4, r2[8]               // Load yn2 (next filter xn2)
    maccs r9, r8, r5, r4

    ldaw  r2, r2[7]               // Advance to next biquad

    mov   r5, r9                  // copy r9 into r5, to check for overflow
    sext  r5, r6                  // because sext sign extends in place
    eq    r5, r9, r5              // If sext makes no change, result is ok
    bt    r5, resultFits
    ldc   r0, 0x80                // not ok, create MININT or MAXINT
    shl   r0, r0, 24
    lss   r5, r5, r9
    sub   r0, r0, r5
    bu    resultDone

resultFits:
    ldc  r5, 32-FRACTIONALBITS    // Merge two halves
    shl  r9, r9, r5               // By shifting both halves and oring them together.
    shr  r8, r8, r6
    or   r0, r9, r8

resultDone:
    sub  r1, r1, 1                // Dec counter
    eq   r9, r1, 0                // Last bank?
    bf   r9, loop                 // If not, jump, this clears r9

    stw   r0, r2[0]               // store yn1
    stw   r3, r2[1]               // store yn2

    ldc   r1, 32
    sub   r1, r1, r10
    mov   r2, r0
    sext  r2, r1
    eq    r2, r0, r2              // If sext makes no change, result is ok
    bt    r2, finalResultFits
    ldc   r1, 0x80                // not ok, create MININT or MAXINT
    shl   r1, r1, 24
    lss   r2, r2, r0
    sub   r0, r1, r2
    bu    allDone

finalResultFits:
    shl   r0, r0, r10

allDone:                          // Now just restore all registers.

    ldw   r4, sp[0]
    ldw   r5, sp[1]
    ldw   r6, sp[2]
    ldw   r7, sp[3]
    ldw   r8, sp[4]
    ldw   r9, sp[5]
    ldw   r10, sp[6]
    retsp NWORDS
