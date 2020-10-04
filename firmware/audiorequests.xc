/**
* Module:  module_usb_aud_shared
* Version: 2v4
* Build:   870e5f8721fa9a8c8aa17caf9511a4a0ad454f6d
* File:    audiorequests.xc
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
/**
* @file    AudioRequests.xc
* @brief   Implements relevant requests from the USB Audio 2.0 Specification
* @author  Ross Owen, XMOS Semiconductor
* @version 1.4
*/

#include <xs1.h>
#include <stdio.h>

#include "xud.h"
#include "usb.h"
#include "usbaudio20.h"
#include "devicedefines.h"
#include "dbcalc.h"
#include "clockcmds.h"
#include "auto_descriptors.h"
#ifdef MIXER
#include "mixer.h"
#endif
#include <print.h>
#include "dsp.h"

#define UPDATE_MIXER_AND_ACK 42

extern unsigned int g_curSamFreq;
extern unsigned int g_curSamFreq48000Family;
extern unsigned int g_curSamFreqMultiplier;

void storeInt(unsigned char buffer[], int index, int val)
{
	buffer[index+3] = val>>24;
	buffer[index+2] = val>>16;
	buffer[index+1] = val>>8;
	buffer[index]  =  val;
}

void storeShort(unsigned char buffer[], int index, short val)
{
	buffer[index+1] = val>>8;
	buffer[index]  =  val;
}

unsigned int getInt(unsigned char buffer[], int index)
{
	return buffer[0+index] | (buffer[1+index]<<8) | (buffer[2+index]<<16) | (buffer[3+index]<<24);
}

unsigned short getShort(unsigned char buffer[])
{
	return buffer[0] | (buffer[1]<<8);
}

unsigned longMul(unsigned a, unsigned b, int prec)
{
	unsigned x,y;
	unsigned ret;

	//    {x, y} = lmul(a, b, 0, 0);
	asm("lmul %0, %1, %2, %3, %4, %5":"=r"(x),"=r"(y):"r"(a),"r"(b),"r"(0),"r"(0));


	ret = (x << (32-prec) | (y >> prec));
	return ret;
}

enum request {
	GET_CUR,
	SET_CUR,
	GET_RANGE
};

// -127.5dB to 0dB in 0.5dB steps
short vol_range[4] = {
	1,
	0x8080, 0x0000, 0x0080
};
// -127.5dB to 20dB in 0.5dB steps
short in_range[4] = {
	    1,
		    0x8080, 0x1400, 0x0080
};

struct volume {
	short val;
	short mute;
};

struct aux_state {
	int balanced;
	int clfe;
	struct volume cap[2];
	struct volume play[2];
	struct volume mix[6];
	int rot;
};

struct mixer_state {
	struct aux_state aux[3];
	struct volume pcm[1];
	struct volume hp[2];
	struct volume spkr[6];
	struct volume spkr_master[1];
	int cap_sel;
};

static struct mixer_state mixer_state;

static int mix_mult[MAX_MIX_COUNT][MIX_INPUTS];
static int in_mix_mult[2][3];

#define FL 0
#define FR 1
#define C 4
#define LFE 5
#define RL 2
#define RR 3
#define HL 6
#define HR 7

#define FRAC 25

#define SQRT2 0x016a09e6
#define DBM10  0x00a1e89b
#define DBM20  0x00333333
#define DBP10  0x0653160e

static unsigned int vol2mul(struct volume &vol)
{
	if (vol.mute || vol.val == 0x8000)
		return 0;
	else
		return db_to_mult(vol.val, 8, FRAC);
}

static void update_aux(int aux, struct aux_state &auxs, unsigned int hl, unsigned int hr, unsigned int spkr_mul[6], int cap_active)
{
	unsigned int left, right;
	unsigned int fl, fr, flr, cl, cr, rr, rl, rlr, lfel, lfer, lfe_mul, cmix_sqrt2, lfemix_sqrt2;
	int idx = NUM_USB_CHAN_OUT + 2 * aux;

	left = vol2mul(auxs.play[0]);
	right = vol2mul(auxs.play[1]);

	if (auxs.clfe) {
		fl = longMul(left, vol2mul(auxs.mix[FL]), FRAC);
		flr = longMul(left, vol2mul(auxs.mix[FR]), FRAC);
		fr = 0;
		rl = longMul(left, vol2mul(auxs.mix[RL]), FRAC);
		rlr = longMul(left, vol2mul(auxs.mix[RR]), FRAC);
		rr = 0;

		cl = longMul(left, vol2mul(auxs.mix[C]), FRAC);
		cr = 0;

		lfel = 0;
		lfer = longMul(right, vol2mul(auxs.mix[LFE]), FRAC);
	} else {
		fl = longMul(left, vol2mul(auxs.mix[FL]), FRAC);
		fr = longMul(right, vol2mul(auxs.mix[FR]), FRAC);
		flr = 0;
		rl = longMul(left, vol2mul(auxs.mix[RL]), FRAC);
		rr = longMul(right, vol2mul(auxs.mix[RR]), FRAC);
		rlr = 0;

		cmix_sqrt2 = longMul(vol2mul(auxs.mix[C]), SQRT2, FRAC);
		lfemix_sqrt2 = longMul(vol2mul(auxs.mix[LFE]), SQRT2, FRAC);
		cl = longMul(left, cmix_sqrt2, FRAC);
		cr = longMul(right, cmix_sqrt2, FRAC);
		lfel = longMul(left, lfemix_sqrt2, FRAC);
		lfer = longMul(right, lfemix_sqrt2, FRAC);
	}

	lfe_mul = longMul(spkr_mul[LFE], DBM10, FRAC);

	mix_mult[C][idx + 0] = longMul(cl, spkr_mul[C], FRAC);
	mix_mult[C][idx + 1] = longMul(cr, spkr_mul[C], FRAC);
	mix_mult[LFE][idx + 0] = longMul(lfel, lfe_mul, FRAC);
	mix_mult[LFE][idx + 1] = longMul(lfer, lfe_mul, FRAC);
	mix_mult[HL][idx + 0] = longMul(left, hl, FRAC);
	mix_mult[HR][idx + 1] = longMul(right, hr, FRAC);

	switch (auxs.rot) {
		case 0:
			mix_mult[FL][idx + 0] = longMul(fl, spkr_mul[FL], FRAC);
			mix_mult[FR][idx + 0] = longMul(flr, spkr_mul[FR], FRAC);
			mix_mult[FR][idx + 1] = longMul(fr, spkr_mul[FR], FRAC);
			mix_mult[RR][idx + 1] = longMul(rr, spkr_mul[RR], FRAC);
			mix_mult[RR][idx + 0] = longMul(rlr, spkr_mul[RR], FRAC);
			mix_mult[RL][idx + 0] = longMul(rl, spkr_mul[RL], FRAC);
			break;
		case 1:
			mix_mult[FR][idx + 0] = longMul(fl, spkr_mul[FR], FRAC);
			mix_mult[RR][idx + 0] = longMul(flr, spkr_mul[RR], FRAC);
			mix_mult[RR][idx + 1] = longMul(fr, spkr_mul[RR], FRAC);
			mix_mult[RL][idx + 1] = longMul(rr, spkr_mul[RL], FRAC);
			mix_mult[RL][idx + 0] = longMul(rlr, spkr_mul[RL], FRAC);
			mix_mult[FL][idx + 0] = longMul(rl, spkr_mul[FL], FRAC);
			break;
		case 2:
			mix_mult[RR][idx + 0] = longMul(fl, spkr_mul[RR], FRAC);
			mix_mult[RL][idx + 0] = longMul(flr, spkr_mul[RL], FRAC);
			mix_mult[RL][idx + 1] = longMul(fr, spkr_mul[RL], FRAC);
			mix_mult[FL][idx + 1] = longMul(rr, spkr_mul[FL], FRAC);
			mix_mult[FL][idx + 0] = longMul(rlr, spkr_mul[FL], FRAC);
			mix_mult[FR][idx + 0] = longMul(rl, spkr_mul[FR], FRAC);
			break;
		case 3:
			mix_mult[RL][idx + 0] = longMul(fl, spkr_mul[RL], FRAC);
			mix_mult[FL][idx + 0] = longMul(flr, spkr_mul[FL], FRAC);
			mix_mult[FL][idx + 1] = longMul(fr, spkr_mul[FL], FRAC);
			mix_mult[FR][idx + 1] = longMul(rr, spkr_mul[FR], FRAC);
			mix_mult[FR][idx + 0] = longMul(rlr, spkr_mul[FR], FRAC);
			mix_mult[RR][idx + 0] = longMul(rl, spkr_mul[RR], FRAC);
			break;
	}

	if (cap_active) {
		in_mix_mult[FL][aux] = vol2mul(auxs.cap[FL]);
		in_mix_mult[FR][aux] = vol2mul(auxs.cap[FR]);
	}
}

void update_mixer(chanend c_mix_ctl)
{
	unsigned int pcm, pcm_sqrt2, pcm_hl, pcm_hr, pcm_hl_sqrt2, pcm_hr_sqrt2, master_vol, spkr_mul[6], hl, hr;

	// Reset
	for (int i = 0; i < MAX_MIX_COUNT; i++)
		for (int j = 0; j < MIX_INPUTS; j++)
			mix_mult[i][j] = 0;
	for (int i = 0; i < 2; i++)
		for (int j = 0; j < 3; j++)
			in_mix_mult[i][j] = 0;

	// Compute speaker channel volume
	master_vol = vol2mul(mixer_state.spkr_master[0]);
	for (int i = 0; i < 6; i++)
		spkr_mul[i] = longMul(master_vol, vol2mul(mixer_state.spkr[i]), FRAC);

	// PCM input
	pcm = vol2mul(mixer_state.pcm[0]);
	for (int i = 0; i < NUM_USB_CHAN_OUT; i++)
		mix_mult[i][i] = longMul(pcm, spkr_mul[i], FRAC);


	// PCM to headphones
	hl = vol2mul(mixer_state.hp[0]);
	hr = vol2mul(mixer_state.hp[1]);
	pcm_sqrt2 = longMul(pcm, SQRT2, FRAC);
	pcm_hl = longMul(pcm, hl, FRAC);
	pcm_hr = longMul(pcm, hr, FRAC);
	pcm_hl_sqrt2 = longMul(pcm_sqrt2, hl, FRAC);
	pcm_hr_sqrt2 = longMul(pcm_sqrt2, hr, FRAC);
	mix_mult[HL][FL] = pcm_hl;
	mix_mult[HR][FR] = pcm_hr;
	mix_mult[HL][C] = pcm_hl_sqrt2;
	mix_mult[HR][C] = pcm_hr_sqrt2;
	mix_mult[HL][RL] = pcm_hl;
	mix_mult[HR][RR] = pcm_hr;
	// This is correct, but may not be a good idea. We'll see.
	mix_mult[HL][LFE] = longMul(pcm_hr_sqrt2, DBP10, FRAC);
	mix_mult[HR][LFE] = longMul(pcm_hr_sqrt2, DBP10, FRAC);

	// Mix in aux inputs
	for (int i = 0; i < 3; i++) {
		int cap_active = 0;
		if (mixer_state.cap_sel == i || mixer_state.cap_sel == 3)
			cap_active = 1;
		update_aux(i, mixer_state.aux[i], hl, hr, spkr_mul, cap_active);
	}

	// Mix down all channels into LFE, 10dB down (THX spec) and apply volume
	// -10dB more for headroom purposes (this is cancelled out in the DSP stage)
	mix_mult[LFE][LFE] = longMul(mix_mult[LFE][LFE], DBM10, FRAC);
	for (int i = 0; i < MIX_INPUTS; i++) {
		int lfe = longMul(mix_mult[FL][i], DBM20, FRAC);
		lfe += longMul(mix_mult[FR][i], DBM20, FRAC);
		lfe += longMul(mix_mult[C][i], DBM20, FRAC);
		lfe += longMul(mix_mult[RL][i], DBM20, FRAC);
		lfe += longMul(mix_mult[RR][i], DBM20, FRAC);
		mix_mult[LFE][i] += longMul(lfe, vol2mul(mixer_state.spkr[LFE]), FRAC);
	}

	/*
	dprintf("Mix map:\n");
	for (int i = 0; i < MAX_MIX_COUNT; i++) {
		dprintf("%02d: [", i);
		for (int j = 0;j < MIX_INPUTS; j++)
			dprintf("%08x ", mix_mult[i][j]);
		dprintf("\n");
	}

	for (int i = 0; i < 2; i++) {
		dprintf(">%02d: [", i);
		for (int j = 0; j < 3; j++)
			dprintf("%08x ", in_mix_mult[i][j]);
		dprintf("\n");
	}
	*/

	outuint(c_mix_ctl, SET_MIX_MULT);
	for (int i = 0; i < MAX_MIX_COUNT; i++) {
		for (int j = 0; j < MIX_INPUTS; j++) {
			outuint(c_mix_ctl, mix_mult[i][j]);
		}
	}
	for (int i = 0; i < 2; i++) {
		for (int j = 0; j < 3; j++) {
			outuint(c_mix_ctl, in_mix_mult[i][j]);
		}
	}
	for (int i = 0; i < 3; i++) {
		outuint(c_mix_ctl, mixer_state.aux[i].balanced);
	}
	outct(c_mix_ctl, XS1_CT_END);
}

static int handle_volume(unsigned char buffer[], struct volume vol[], XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, enum request request, int channels, short range[])
{
	int control = sp.wValue >> 8;
	int channel = sp.wValue & 0xff;
	int chidx = 0;

	if (channels) {
		if (channel < 1 || channel > channels)
			return 1;
		chidx = channel - 1;
	} else {
		if (channel != 0)
			return 1;
		chidx = 0;
	}

	if (control == FU_VOLUME_CONTROL) {
		if (request == SET_CUR) {
			if (sp.wLength != 2)
				return 1;
			XUD_GetBuffer(ep0_out, buffer);
			vol[chidx].val = getShort(buffer);
			return UPDATE_MIXER_AND_ACK;
		} else if (request == GET_CUR) {
			storeShort(buffer, 0, vol[chidx].val);
			return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
		} else if (request == GET_RANGE) {
			return XUD_DoGetRequest(ep0_out, ep0_in, (range, char[]), sizeof(vol_range), sp.wLength);
		}
	} else if (control == FU_MUTE_CONTROL) {
		if (request == SET_CUR) {
			if (sp.wLength > 2 || sp.wLength < 1)
				return 1;
			XUD_GetBuffer(ep0_out, buffer);
			vol[chidx].mute = buffer[0] ? 1 : 0;
			return UPDATE_MIXER_AND_ACK;
		} else if (request == GET_CUR) {
			buffer[0] = vol[chidx].mute ? 1 : 0;
			buffer[1] = 0;
			return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
		}
	}
	return 1;
}

static int AuxMixerRequest(unsigned char buffer[], XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, enum request request, int unit)
{
	int aux = (unit >> 5) - 1;

	if (aux < 0 || aux > 2)
		return 1;

	switch (unit & 0x1f) {
		case ID_AUX_CAP_VOL:
			return handle_volume(buffer, mixer_state.aux[aux].cap, ep0_out, ep0_in, sp, request, 2, in_range);
		case ID_AUX_PLAY_VOL:
			return handle_volume(buffer, mixer_state.aux[aux].play, ep0_out, ep0_in, sp, request, 2, in_range);
		case ID_AUX_MIX_VOL:
			return handle_volume(buffer, mixer_state.aux[aux].mix, ep0_out, ep0_in, sp, request, 6, vol_range);
		case ID_AUX_ROT_SEL:
			if (request == SET_CUR) {
				if (sp.wLength > 2 || sp.wLength < 1)
					return 1;
				XUD_GetBuffer(ep0_out, buffer);
				if (buffer[0] < 1 || buffer[0] > 4)
					return 1;
				mixer_state.aux[aux].rot = buffer[0] - 1;
				return UPDATE_MIXER_AND_ACK;
			} else if (request == GET_CUR) {
				buffer[0] = mixer_state.aux[aux].rot + 1;
				buffer[1] = 0;
				return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
			}
			break;
		case ID_AUX_MODE_SEL:
			if (request == SET_CUR) {
				if (sp.wLength > 2 || sp.wLength < 1)
					return 1;
				XUD_GetBuffer(ep0_out, buffer);
				if (buffer[0] < 1 || buffer[0] > 3)
					return 1;
				mixer_state.aux[aux].balanced = buffer[0] == 2;
				mixer_state.aux[aux].clfe = buffer[0] == 3;
				return UPDATE_MIXER_AND_ACK;
			} else if (request == GET_CUR) {
				buffer[0] = mixer_state.aux[aux].balanced ? 2 : mixer_state.aux[aux].clfe ? 3 : 1;
				buffer[1] = 0;
				return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
			}
			break;
	}
	return 1;
}

int AudioClassRequests_2_Argh(XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, chanend c_audioControl)
{
	int control = sp.wValue >> 8;
	unsigned char buffer[1024];
	int unit = sp.wIndex >> 8;
	enum request request;

	/*dprintf("U:%02x %d.%d.%d %02x %04x %04x %04x\n", unit,
		sp.bmRequestType.Direction, sp.bmRequestType.Type, sp.bmRequestType.Recipient,
		sp.bRequest, sp.wIndex, sp.wValue, sp.wLength);*/

	if (sp.bmRequestType.Direction == 0) {
		if (sp.bRequest == CUR)
			request = SET_CUR;
		else
			return 1;
	} else {
		if (sp.bRequest == CUR)
			request = GET_CUR;
		else if (sp.bRequest == RANGE)
			request = GET_RANGE;
		else
			return 1;
	}

	if (unit >= 0x20)
		return AuxMixerRequest(buffer, ep0_out, ep0_in, sp, request, unit);

	switch (unit) {
		case ID_CLKSRC:
			if (control == CS_SAM_FREQ_CONTROL) {
				if (request == SET_CUR) {
					int tmp;
					if (sp.wLength != 4)
						return 1;
					XUD_GetBuffer(ep0_out, buffer);
					dprintf("Set sample freq: %d\n", getInt(buffer, 0));
					/* Instruct audio thread to change sample freq */
					g_curSamFreq = getInt(buffer, 0);
					g_curSamFreq48000Family = g_curSamFreq % 48000 == 0;

					if(g_curSamFreq48000Family)
					{
						tmp = MCLK_48;
					}
					else
					{
						tmp = MCLK_441;
					}

					asm("stw %0, dp[g_curSamFreqMultiplier]" :: "r"(g_curSamFreq/(tmp/512)));
					dprintf("Mul: %d\n", g_curSamFreqMultiplier);

					outuint(c_audioControl, SET_SAMPLE_FREQ);
					outuint(c_audioControl, g_curSamFreq);

					/* Wait for handshake back - i.e. pll locked and clocks okay */
					chkct(c_audioControl, XS1_CT_END);

					/* Allow time for our feedback to stabalise*/
					{
						timer t;
						unsigned time;
						t :> time;
						t when timerafter(time+5000000):> void;
					}

					return XUD_DoSetRequestStatus(ep0_in, 0);
				} else if (request == GET_CUR) {
					storeInt(buffer, 0, 96000);
					return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 4, sp.wLength);
				} else if (request == GET_RANGE) {
					storeShort(buffer, 0, 1);
					storeInt(buffer, 2, 96000);
					storeInt(buffer, 6, 96000);
					storeInt(buffer, 10, 0);
					return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 14, sp.wLength);
				}
			} else if (control == CS_CLOCK_VALID_CONTROL) {
				if (request == GET_CUR) {
					// Always valid
					buffer[0] = 1;
					buffer[1] = 0;
					return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
				}
			}
			break;
		case ID_PCM_VOL:
			return handle_volume(buffer, mixer_state.pcm, ep0_out, ep0_in, sp, request, 0, vol_range);
		case ID_HP_VOL:
			return handle_volume(buffer, mixer_state.hp, ep0_out, ep0_in, sp, request, 2, vol_range);
		case ID_SPKR_MASTER:
			return handle_volume(buffer, mixer_state.spkr_master, ep0_out, ep0_in, sp, request, 0, vol_range);
		case ID_SPKR_VOL:
			return handle_volume(buffer, mixer_state.spkr, ep0_out, ep0_in, sp, request, 6, vol_range);
		case ID_CAP_SEL:
			if (request == SET_CUR) {
				if (sp.wLength > 2 || sp.wLength < 1)
					return 1;
				XUD_GetBuffer(ep0_out, buffer);
				if (buffer[0] < 1 || buffer[0] > 4)
					return 1;
				mixer_state.cap_sel = buffer[0] - 1;
				return UPDATE_MIXER_AND_ACK;
			} else if (request == GET_CUR) {
				buffer[0] = mixer_state.cap_sel + 1;
				buffer[1] = 0;
				return XUD_DoGetRequest(ep0_out, ep0_in, buffer, 2, sp.wLength);
			}
			break;
	}
	return 1;
}

int AudioClassRequests_2(XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, chanend c_audioControl, chanend ?c_mix_ctl, chanend ?c_clk_ctl)
{
	int ret;
	ret = AudioClassRequests_2_Argh(ep0_out, ep0_in, sp, c_audioControl);
	if (ret == UPDATE_MIXER_AND_ACK) {
		update_mixer(c_mix_ctl);
		return XUD_DoSetRequestStatus(ep0_in, 0);
	}
	return ret;
}

#define SET_BIQUAD 1
#define SET_DELAY 2

int VendorRequests(XUD_ep ep0_out, XUD_ep ep0_in, SetupPacket &sp, chanend c_dsp_ctl)
{
	unsigned char buffer[512];
	if (sp.bmRequestType.Direction == 0 && sp.bRequest == SET_BIQUAD) {
		int ch = sp.wIndex >> 8;
		int idx = sp.wIndex & 0xff;
		if (ch < 0 || ch >= DSP_CH)
			return 1;
		if (idx < 0 || idx >= DSP_FILTERS)
			return 1;
		if (sp.wLength != 5*4)
			return 1;
		XUD_GetBuffer(ep0_out, buffer);
		outct(c_dsp_ctl, SET_DSP_BIQUAD);
		outuint(c_dsp_ctl, ch);
		outuint(c_dsp_ctl, idx);
		outuint(c_dsp_ctl, getInt(buffer, 0));
		outuint(c_dsp_ctl, getInt(buffer, 4));
		outuint(c_dsp_ctl, getInt(buffer, 8));
		outuint(c_dsp_ctl, getInt(buffer, 12));
		outuint(c_dsp_ctl, getInt(buffer, 16));
		outct(c_dsp_ctl, XS1_CT_END);
		return XUD_DoSetRequestStatus(ep0_in, 0);
	} else if (sp.bmRequestType.Direction == 0 && sp.bRequest == SET_DELAY) {
		int ch = sp.wIndex;
		int delay = sp.wValue;
		if (ch < 0 || ch >= DSP_CH)
			return 1;
		if (delay < 0 || delay > MAX_DELAY)
			return 1;
		if (sp.wLength != 0)
			return 1;
		outct(c_dsp_ctl, SET_DSP_DELAY);
		outuint(c_dsp_ctl, ch);
		outuint(c_dsp_ctl, delay);
		outct(c_dsp_ctl, XS1_CT_END);
		return XUD_DoSetRequestStatus(ep0_in, 0);
	}
	return 1;
}

void InitMixers(chanend c_mix_ctl) {
	int i,j;
	mixer_state.spkr_master[0].val = -20 << 8;
	//mixer_state.spkr[5].val = -22 << 8;
	for (i = 0; i < 3; i++) {
		for (j = 0; j < 2; j++) {
			mixer_state.aux[i].play[j].mute = 1;
			mixer_state.aux[i].mix[j + 4].mute = 1;
		}
	}
	update_mixer(c_mix_ctl);
}
