#ifndef DSP_H
#define DSP_H

#define FRACTIONALBITS 28
#define HEADROOMBITS 4
#define LFE_HEADROOMBITS 0

#ifdef __XC__

#define DSP_CH 6
#define DSP_EXT_CH 5
#define DSP_FILTERS 15

#define DELAY_BITS 10
#define DELAY_BUF ((1<<DELAY_BITS))
#define MAX_DELAY (DELAY_BUF - 1)

#define ONE (1<<(FRACTIONALBITS))
#define DB10 0x194c583a

struct biquad {
	int xn1, xn2;
	int b0, b1, b2;
	int a1, a2;
};

#define SET_DSP_BIQUAD 5
#define SET_DSP_DELAY 6

// the const is a horrible lie but fuck XC
int biquad_cascade(int s, int count, const struct biquad biquads[], int headroombits);

#endif

#endif
