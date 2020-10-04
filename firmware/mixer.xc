/**
 * Module:  module_usb_aud_shared
 * Version: 2v3
 * Build:   b8b701010296296860417a33c03ee283d2b4ad97
 * File:	mixer.xc
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


#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include "mixer.h"
#include "devicedefines.h"

#define LDW(dest, array, index) asm("ldw %0, %1[%2]":"=r"(dest):"r"(array),"r"(index))
#define STW(array, index, value) asm("stw %0, %1[%2]"::"r"(value),"r"(array),"r"(index))

#ifdef MIXER

#define FAST_MIXER 1

static int mix_in_samples[MIX_INPUTS];
static int mix_out_samples[MAX_MIX_COUNT];
static int aux_in_samples[2][AUX_COUNT];
static int usb_in_samples[NUM_USB_CHAN_IN];

static int mix_mult[MAX_MIX_COUNT][MIX_INPUTS];
static int in_mix_mult[2][AUX_COUNT];
static int aux_balanced[AUX_COUNT];

static int input_map[NUM_USB_CHAN_OUT] = {
	0, 1, 4, 5, 2, 3,
};

static int output_map[MAX_MIX_COUNT] = {
	6, 7, 0, 1, 2, 3, 4, 5,
};

int doMix_out(const int samples[], int mult[]);
int doMix_in(const int samples[], int mult[]);

#pragma unsafe arrays
void giveSamplesToHost(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < NUM_USB_CHAN_IN; i++)
		outuint(c, usb_in_samples[i]);
}

#pragma unsafe arrays
static void getSamplesFromHost(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < NUM_USB_CHAN_OUT; i++)
		STW(mix_in_samples, input_map[i], inuint(c));
}

#pragma unsafe arrays
static void giveSamplesToDevice(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < MAX_MIX_COUNT; i++)
		outuint(c, mix_out_samples[output_map[i]]);
}

#pragma unsafe arrays
static void getSamplesFromDevice(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < IN_CHANNELS; i++)
		STW(mix_in_samples, i + NUM_USB_CHAN_OUT, inuint(c));
}

#pragma unsafe arrays
void mixer1(chanend c_host, chanend c_mix_ctl, chanend c_mixer2)
{
	int mixed;
	unsigned cmd;

	while (1) {
		inuint(c_mixer2);

		/* Request data from decouple thread */
		outuint(c_host, 0);
	
		/* Between request to decouple and respose ~ 400nS latency for interrupt to fire */
		select
		{
			case inuint_byref(c_mix_ctl, cmd):
			{
				int mix, index, val;
				switch (cmd)
				{
					case SET_MIX_MULT:
						for (int i = 0; i < MAX_MIX_COUNT; i++) {
							for (int j = 0; j < MIX_INPUTS; j++) {
								STW(mix_mult[i], j, inuint(c_mix_ctl));
							}
						}
						for (int i = 0; i < 2; i++) {
							for (int j = 0; j < AUX_COUNT; j++) {
								STW(in_mix_mult[i], j, inuint(c_mix_ctl));
							}
						}
						for (int i = 0; i < AUX_COUNT; i++) {
							STW(aux_balanced, i, inuint(c_mix_ctl));
						}
						inct(c_mix_ctl);
						break;
				}
				break;
			}
			default:
			/* Select default */
				break;
		}

		inuint(c_host);
		outuint(c_mixer2, 0);
		giveSamplesToHost(c_host);

		outuint(c_mixer2, 0);
		inuint(c_mixer2);
		getSamplesFromHost(c_host);
		outuint(c_mixer2, 0);
		inuint(c_mixer2);

		mixed = doMix_out(mix_in_samples, mix_mult[0]);
		STW(mix_out_samples, 0, mixed);
#if MAX_MIX_COUNT > 2
		mixed = doMix_out(mix_in_samples, mix_mult[2]);
		STW(mix_out_samples, 2, mixed);
#endif
#if MAX_MIX_COUNT > 4
		mixed = doMix_out(mix_in_samples, mix_mult[4]);
		STW(mix_out_samples, 4, mixed);
#endif
#if MAX_MIX_COUNT > 6
		mixed = doMix_out(mix_in_samples, mix_mult[6]);
		STW(mix_out_samples, 6, mixed);
#endif
		for (int i = 0; i < AUX_COUNT; i++)
			STW(aux_in_samples[0], i, mix_in_samples[6 + i * 2]);
		mixed = doMix_in(aux_in_samples[0], in_mix_mult[0]);
		STW(usb_in_samples, 0, mixed);
	}
}

#pragma unsafe arrays
void mixer2(chanend c_mixer1, chanend c_audio)
{
	int mixed;

	while (1) {
		outuint(c_mixer1, 0);
		inuint(c_audio);
		(void) inuint(c_mixer1);
		giveSamplesToDevice(c_audio);
		inuint(c_mixer1);
		outuint(c_mixer1, 0);
		getSamplesFromDevice(c_audio);
#pragma loop unroll
		for (int i = 0; i < AUX_COUNT; i++) {
			int off = i*2 + NUM_USB_CHAN_OUT;
			if (aux_balanced[i]) {
				int p = mix_in_samples[off] >> 1;
				int m = mix_in_samples[off+1] >> 1;
				int r = p - m;
				STW(mix_in_samples, off, r);
				STW(mix_in_samples, off+1, r);
			}
		}
		inuint(c_mixer1);
		outuint(c_mixer1, 0);

#if MAX_MIX_COUNT > 1
		mixed = doMix_out(mix_in_samples, mix_mult[1]);
		STW(mix_out_samples, 1, mixed);
#endif
#if MAX_MIX_COUNT > 3
		mixed = doMix_out(mix_in_samples, mix_mult[3]);
		STW(mix_out_samples, 3, mixed);
#endif
#if MAX_MIX_COUNT > 5
		mixed = doMix_out(mix_in_samples, mix_mult[5]);
		STW(mix_out_samples, 5, mixed);
#endif
#if MAX_MIX_COUNT > 7
		mixed = doMix_out(mix_in_samples, mix_mult[7]);
		STW(mix_out_samples, 7, mixed);
#endif
		for (int i = 0; i < AUX_COUNT; i++)
			STW(aux_in_samples[1], i, mix_in_samples[7 + i * 2]);
		mixed = doMix_in(aux_in_samples[1], in_mix_mult[1]);
		STW(usb_in_samples, 1, mixed);
	}
}

void mixer(chanend c_mix_in, chanend c_mix_out, chanend c_mix_ctl)
{
	chan c;
	for (int i = 0; i < MIX_INPUTS; i++)
		mix_in_samples[i] = 0;
	for (int i = 0; i < MAX_MIX_COUNT; i++)
		mix_out_samples[i] = 0;
	for (int i = 0; i < NUM_USB_CHAN_IN; i++)
		usb_in_samples[i] = 0;

	for (int i = 0; i < MAX_MIX_COUNT; i++) {
		for (int j = 0;j < MIX_INPUTS; j++) {
			mix_mult[i][j] = 0;
		}
	}
	for (int i = 0; i < 2; i++) {
		for (int j = 0; j < AUX_COUNT; j++) {
			in_mix_mult[i][j] = 0;
		}
	}
	for (int i = 0; i < AUX_COUNT; i++)
		aux_balanced[i] = 0;
	par {
		mixer1(c_mix_in, c_mix_ctl, c);
		mixer2(c, c_mix_out);
	}
}

#endif
