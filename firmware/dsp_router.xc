#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include "mixer.h"
#include "devicedefines.h"
#include "dsp.h"

#define LDW(dest, array, index) asm("ldw %0, %1[%2]":"=r"(dest):"r"(array),"r"(index))
#define STW(array, index, value) asm("stw %0, %1[%2]"::"r"(value),"r"(array),"r"(index))

static int dsp_in_samples[I2S_CHANS_DAC];
static int dsp_out_samples[I2S_CHANS_DAC];
static int in_samples[I2S_CHANS_ADC];

static struct biquad lfe_biquads[DSP_FILTERS+1] = {
		{0,0,DB10,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},
		{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},
		{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},
		{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,ONE,0,0,0,0},{0,0,0,0,0,0,0},
};

static int audiobuf[DELAY_BUF];
static int p_write;
static int lfe_delay;

#pragma unsafe arrays
static void giveSamplesToDevice(chanend c)
{
	outuint(c, dsp_in_samples[0]);
	outuint(c, dsp_in_samples[1]);
	outuint(c, dsp_out_samples[2]);
	outuint(c, dsp_out_samples[3]);
	outuint(c, dsp_out_samples[4]);
	outuint(c, dsp_out_samples[5]);
	outuint(c, dsp_out_samples[6]);
	outuint(c, dsp_out_samples[7]);
}

#pragma unsafe arrays
static void getSamplesFromDevice(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < I2S_CHANS_ADC; i++)
		STW(in_samples, i, inuint(c));
}

#pragma unsafe arrays
static void giveSamplesToMixer(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < I2S_CHANS_ADC; i++)
		outuint(c, in_samples[i]);
}

#pragma unsafe arrays
static void getSamplesFromMixer(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < I2S_CHANS_DAC; i++)
		STW(dsp_in_samples, i, inuint(c));
}

#pragma unsafe arrays
static void giveSamplesToDSP(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < DSP_EXT_CH; i++)
		outuint(c, dsp_in_samples[2+i]);
}

#pragma unsafe arrays
static void getSamplesFromDSP(chanend c)
{
#pragma loop unroll
	for (int i = 0; i < DSP_EXT_CH; i++)
		STW(dsp_out_samples, 2+i, inuint(c));
}

#pragma unsafe arrays
void dsp_router(chanend c_mixer, chanend c_audio, chanend c_dsp, chanend c_dsp_ctl)
{
	int result = 0;
	unsigned char ct;
	while(1) {
		inuint(c_audio);
		giveSamplesToDevice(c_audio);
		getSamplesFromDevice(c_audio);
		outuint(c_mixer, 0);
		getSamplesFromMixer(c_mixer);
		giveSamplesToMixer(c_mixer);

		select {
			case inct_byref(c_dsp_ctl, ct): {
				int ch, i;
				switch (ct) {
					case SET_DSP_BIQUAD:
						ch = inuint(c_dsp_ctl);
						if (ch == DSP_EXT_CH) {
							i = inuint(c_dsp_ctl);
							lfe_biquads[i].xn1 = 0;
							lfe_biquads[i].xn2 = 0;
							lfe_biquads[i].b0 = inuint(c_dsp_ctl);
							lfe_biquads[i].b1 = inuint(c_dsp_ctl);
							lfe_biquads[i].b2 = inuint(c_dsp_ctl);
							lfe_biquads[i].a1 = inuint(c_dsp_ctl);
							lfe_biquads[i].a2 = inuint(c_dsp_ctl);
						} else {
							outct(c_dsp, SET_DSP_BIQUAD);
							outuint(c_dsp, ch);
							outuint(c_dsp, inuint(c_dsp_ctl));
							outuint(c_dsp, inuint(c_dsp_ctl));
							outuint(c_dsp, inuint(c_dsp_ctl));
							outuint(c_dsp, inuint(c_dsp_ctl));
							outuint(c_dsp, inuint(c_dsp_ctl));
							outuint(c_dsp, inuint(c_dsp_ctl));
						}
						break;
					case SET_DSP_DELAY:
						ch = inuint(c_dsp_ctl);
						if (ch == DSP_EXT_CH) {
							lfe_delay = inuint(c_dsp_ctl);
						} else {
							outct(c_dsp, SET_DSP_DELAY);
							outuint(c_dsp, ch);
							outuint(c_dsp, inuint(c_dsp_ctl));
						}
						break;
				}
				chkct(c_dsp_ctl, XS1_CT_END);
				break;
			}
			default:
				break;
		}
		outuint(c_dsp, 0);
		getSamplesFromDSP(c_dsp);
		STW(dsp_out_samples, 2+DSP_EXT_CH, result);
		giveSamplesToDSP(c_dsp);
		p_write = (p_write + 1) & MAX_DELAY;
		result = biquad_cascade(dsp_in_samples[2+DSP_EXT_CH], DSP_FILTERS, lfe_biquads, LFE_HEADROOMBITS);
		STW(audiobuf, p_write, result);
		result = audiobuf[(p_write - lfe_delay) & MAX_DELAY];
		
	}
}
