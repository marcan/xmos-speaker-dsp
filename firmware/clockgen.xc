/**
 * Module:  module_usb_aud_shared
 * Version: 2v3
 * Build:   f4d4a01320f0e885f2a41b6bcc76ef47d5a5ebc1
 * File:    clockgen.xc
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
#include <assert.h>
#include <print.h>

#include "devicedefines.h"
#include "clockcmds.h"
#include "auto_descriptors.h"


#ifdef SPDIF_RX
#include "SpdifReceive.h"
#pragma xta command "analyse path digital_out digital_out"
#pragma xta command "set required - 5200 ns"             /* 192kHz */
#endif

#define LOCAL_CLOCK_INCREMENT       166667
#define LOCAL_CLOCK_MARGIN          1666

#define MAX_SAMPLES                 64                      /* Must be power of 2 */
#define MAX_SPDIF_SAMPLES           (2 * MAX_SAMPLES)       /* Must be power of 2 */
#define MAX_ADAT_SAMPLES            (8 * MAX_SAMPLES)       /* Must be power of 2 */

#define SPDIF_FRAME_ERRORS_THRESH	40

unsigned g_digData[10];

typedef struct
 {
    int receivedSamples;
    int samples;
    int savedSamples;
    int lastDiff;
    unsigned identicaldiffs;
    int samplesPerTick;
} Counter;

static int clockFreq[NUM_CLOCKS];                           /* Store current clock freq for each clock unit */
static int clockValid[NUM_CLOCKS];                          /* Store current validity of each clock unit */
static int clockInt[NUM_CLOCKS];                            /* Interupt flag for clocks */
static int clockId[NUM_CLOCKS];

int abs(int x) 
{
    if (x < 0) return -x;
    return x;
}

int channelContainsControlToken(chanend x)
{
    unsigned char tmpc;

    select
    {
        case inct_byref(x, tmpc):
            return 1;
        default:
            return 0;
    }

}

void outInterrupt(chanend c_interruptControl, int value) 
{
    /* Non-blocking check for control token */
    //if (channelContainsControlToken(c_interruptControl)) 
    {
        outuint(c_interruptControl, value);
        outct(c_interruptControl, XS1_CT_END);
    }
}

#ifdef CLOCK_VALIDITY_CALL
void VendorClockValidity(int valid);
#endif

#if defined(SPDIF_RX) || defined(ADAT_RX)
static inline void setClockValidity(chanend c_interruptControl, int clkIndex, int valid, int currentClkMode)
{
    if (clockValid[clkIndex] != valid) 
    {
        clockValid[clkIndex] = valid;
        outInterrupt(c_interruptControl, clockId[clkIndex]);

#ifdef CLOCK_VALIDITY_CALL
#ifdef ADAT_RX
        if (currentClkMode == CLOCK_ADAT && clkIndex == CLOCK_ADAT_INDEX) 
        {
            VendorClockValidity(valid);
        }
#endif
#ifdef SPDIF_RX
        if (currentClkMode == CLOCK_SPDIF && clkIndex == CLOCK_SPDIF_INDEX) 
        {
            VendorClockValidity(valid);
        }
#endif
#endif
    }
}




/* Returns 1 for valid clock found else 0 */
static inline int validSamples(Counter &counter, int clockIndex) 
{
    int diff = counter.samples - counter.savedSamples;

    counter.savedSamples = counter.samples;
    
    /* Check for stable sample rate (with some small margin) */
    if (diff != 0 && abs( diff - counter.lastDiff ) < 5 ) 
    {
        counter.identicaldiffs++;           
        
        if (counter.identicaldiffs > 10) 
        {
            /* Detect current sample rate (round to nearest) */
            int s = -1;
           
            if (diff > 137 && diff < 157) 
            {
                s = 147;
            } 
            else if (diff > 150 && diff < 170) 
            {
                s = 160;
            }
            else if(diff > 284 && diff < 304)
            {
                s = 294; 
            }
            else if (diff > 310 && diff < 330) 
            {
                s = 320;
            } 
            else if (diff > 578 && diff < 598)
            {
                s = 588;
            }
            else if (diff > 630 && diff < 650) 
            {
                s = 640;
            }
                   
            /* Check if we found a valid freq */ 
            if (s != -1) 
            { 
                /* Update expected samples per tick */
                counter.samplesPerTick = s;
               
                /* Update record of external clock source sample frequency */
                s *= 300;
                 

                if (clockFreq[clockIndex] != s) 
                {
                    clockFreq[clockIndex] = s;
                }
                
                return 1;
            } 
            else 
            { 
                /* Not a valid frequency - Reset counter and find another run of samples */
                counter.identicaldiffs = 0;
            }
        }
    } 
    else 
    {
        counter.identicaldiffs = 0;
        counter.lastDiff = diff;
    }
    return 0;
}
#endif

#ifdef SPDIF_RX
//:badParity
/* Returns 1 for bad parity, else 0 */ 
static inline int badParity(unsigned x)
{
    unsigned X = (x>>4);
    crc32(X, 0, 1);
    return X & 1;
}
//:
#endif

#ifdef LEVEL_METER_LEDS
void VendorLedRefresh(unsigned levelData[]);
unsigned g_inputLevelData[NUM_USB_CHAN_IN];
extern int samples_to_host_inputs[NUM_USB_CHAN_IN];
extern int samples_to_host_inputs_buff[NUM_USB_CHAN_IN];        /* Audio transmitted to host i.e. dev inputs */
#endif

int VendorAudCoreReqs(unsigned cmd, chanend c);

#pragma unsafe arrays
void clockGen (streaming chanend c_spdif_rx, chanend c_adat_rx, out port p, chanend c_dig_rx, chanend c_clk_ctl, chanend c_clk_int)
{
    timer t_local;
    unsigned timeNextEdge, timeLastEdge, timeNextClockDetection;
    unsigned pinVal = 0;
    unsigned short  pinTime;
    unsigned clkMode = CLOCK_INTERNAL;              /* Current clocking mode in operation */
    unsigned tmp;

    /* start in no-SMUX (8-channel) mode */
    int smux = 0;

#ifdef LEVEL_METER_LEDS
    timer t_level;
    unsigned levelTime;
#endif

#if defined(SPDIF_RX) || defined(ADAT_RX)
    timer t_external;
#endif

#ifdef SPDIF_RX
    /* S/PDIF buffer state */
	int spdifSamples[MAX_SPDIF_SAMPLES];           /* S/PDIF sample buffer */
	int spdifWr = 0;                               /* Write index */
	int spdifRd = 0;                               /* Read index */ //(spdifWriteIndex ^ (MAX_SPDIF_SAMPLES >> 1)) & ~1;   // Start in middle
	int spdifOverflow = 0;                         /* Overflow/undeflow flags */
    int spdifUnderflow = 1;
    int spdifSamps = 0;                            /* Number of samples in buffer */
    Counter spdifCounters;
    int spdifReceivedTime;
    unsigned tmp2;
    unsigned spdifLeft = 0;
#endif 

#ifdef ADAT_RX
    /* ADAT buffer state */
    int adatSamples[MAX_ADAT_SAMPLES];
    int adatWr = 0;
    int adatRd = 0;
    int adatOverflow = 0;
    int adatUnderflow = 1;
    //int adatFrameErrors = 0;
    int adatSamps = 0;
    Counter adatCounters;
    int adatReceivedTime;

    unsigned adatFrame[8];
    int adatChannel = 0;
    int adatSamplesEver = 0;
#endif
    for(int i = 0; i < 10; i++)
    {
       g_digData[i] = 0;
    }
   
 
    /* Init clock unit state */ 
#ifdef SPDIF_RX
    clockFreq[CLOCK_SPDIF_INDEX] = 0;
    clockValid[CLOCK_SPDIF_INDEX] = 0;
    clockInt[CLOCK_SPDIF_INDEX] = 0;
    clockId[CLOCK_SPDIF_INDEX] = ID_CLKSRC_SPDIF;
#endif
    clockFreq[CLOCK_INTERNAL_INDEX] = 0;
    clockId[CLOCK_INTERNAL_INDEX] = 0;
    clockValid[CLOCK_INTERNAL_INDEX] = 0;
    clockInt[CLOCK_INTERNAL_INDEX] = 0;
    clockId[CLOCK_INTERNAL_INDEX] = ID_CLKSRC_INT;
#ifdef ADAT_RX
    clockFreq[CLOCK_ADAT_INDEX] = 0;
    clockInt[CLOCK_ADAT_INDEX] = 0;
    clockValid[CLOCK_ADAT_INDEX] = 0;
    clockId[CLOCK_ADAT_INDEX] = ID_CLKSRC_ADAT; 
#endif 
#ifdef SPDIF_RX 
    spdifCounters.receivedSamples = 0;
    spdifCounters.samples = 0;
    spdifCounters.savedSamples = 0;
    spdifCounters.lastDiff = 0;
    spdifCounters.identicaldiffs = 0;
    spdifCounters.samplesPerTick = 0;
#endif

#ifdef ADAT_RX
    adatCounters.receivedSamples = 0;
    adatCounters.samples = 0;
    adatCounters.savedSamples = 0;
    adatCounters.lastDiff = 0;
    adatCounters.identicaldiffs = 0;
    adatCounters.samplesPerTick = 0;
#endif


    t_local :> timeNextEdge;
    timeLastEdge = timeNextEdge;
    timeNextClockDetection = timeNextEdge + (LOCAL_CLOCK_INCREMENT / 2);
    timeNextEdge += LOCAL_CLOCK_INCREMENT;
 
#ifdef LEVEL_METER_LEDS
    t_level :> levelTime;
    levelTime+= LEVEL_UPDATE_RATE;
#endif
  
#if defined(SPDIF_RX) || defined(ADAT_RX) 
    /* Fill channel */ 
    outuint(c_dig_rx, 1);
#endif
    
    /* Initial ref clock output and get timestamp */
    p <: pinVal @ pinTime;
    pinTime += (unsigned short)(LOCAL_CLOCK_INCREMENT - (LOCAL_CLOCK_INCREMENT/2));
    p @ pinTime <: pinVal;

    while(1)
    {
        select
        {
#ifdef LEVEL_METER_LEDS
#warning Level metering enabled
            case t_level when timerafter(levelTime) :> void:
    
                levelTime += LEVEL_UPDATE_RATE;
    
                /* Copy over level data and reset */
                for(int i = 0; i< NUM_USB_CHAN_IN; i++)
                {
                    int tmp;
                    //g_inputLevelData[i] = samples_to_host_inputs[i];
                    asm("ldw %0, %1[%2]":"=r"(tmp):"r"(samples_to_host_inputs),"r"(i));
                    g_inputLevelData[i] = tmp;
                    
                    //samples_to_host_inputs[i] = 0;
                    asm("stw %0, %1[%2]"::"r"(0),"r"(samples_to_host_inputs),"r"(i));
                   
                    /* Guard against host polling slower than timer and missing peaks */
                    if(g_inputLevelData[i] > samples_to_host_inputs_buff[i])
                    {
                        samples_to_host_inputs_buff[i] = g_inputLevelData[i];
                    }
                }

                /* Call user LED refresh */
                VendorLedRefresh(g_inputLevelData);

                break;
#endif

			/* Updates to clock settings from endpoint 0 */
			case inuint_byref(c_clk_ctl, tmp):
                switch(tmp)
                {
                    case GET_SEL: 
                        chkct(c_clk_ctl, XS1_CT_END); 
                        
                        /* Send back current clock mode */
                        outuint(c_clk_ctl, clkMode);
                        outct(c_clk_ctl, XS1_CT_END);
                        
                        break;
                    
                    case SET_SEL:
                        /* Update clock mode */
                        tmp = inuint(c_clk_ctl);
                        chkct(c_clk_ctl, XS1_CT_END);
                    
                        if(tmp!=0)
                        {
                            clkMode = tmp;
                        }
#ifdef CLOCK_VALIDITY_CALL
                        switch(clkMode)
                        {
                            case CLOCK_INTERNAL:
                                VendorClockValidity(1);
                                break;
#ifdef ADAT_RX
                            case CLOCK_ADAT:
                                VendorClockValidity(clockValid[CLOCK_ADAT_INDEX]);
                                break;
#endif
#ifdef SPDIF_RX
                            case CLOCK_SPDIF:    
                                VendorClockValidity(clockValid[CLOCK_SPDIF_INDEX]);
                                break;
#endif
                        }
#endif
                        break;

                    case GET_VALID:
                        /* Clock Unit Index */
                        tmp = inuint(c_clk_ctl);
                        chkct(c_clk_ctl, XS1_CT_END);
                        outuint(c_clk_ctl, clockValid[tmp]);
                        outct(c_clk_ctl, XS1_CT_END);                        
                        break; 

                    case GET_FREQ:
                        tmp = inuint(c_clk_ctl);
                        chkct(c_clk_ctl, XS1_CT_END);
                        outuint(c_clk_ctl, clockFreq[tmp]);
                        outct(c_clk_ctl, XS1_CT_END); 
                        break;

                    case SET_SMUX:
                        smux = inuint(c_clk_ctl);
#ifdef ADAT_RX
                        adatRd = 0; /* Reset adat FIFO */
                        adatWr = 0;
                        adatSamps = 0;
#endif
                        chkct(c_clk_ctl, XS1_CT_END);
                        break;
    
                    default:
#ifdef VENDOR_AUDCORE_REQS
                            if(VendorAudCoreReqs(tmp, c_clk_ctl))
#endif
                            printstrln("ERR: Bad req in clockgen\n");
                        break;
                }
                    
			    break; 

            /* Generate local clock from timer */
            case t_local when timerafter(timeNextEdge) :> void:

                
                /* Setup next local clock edge */
                pinTime += (short) LOCAL_CLOCK_INCREMENT;
                pinVal = !pinVal;
                p @ pinTime <: pinVal;

                /* Record time of edge */
                timeLastEdge = timeNextEdge;

                /* Setup for next edge */
                timeNextClockDetection = timeNextEdge + (LOCAL_CLOCK_INCREMENT/2);
                timeNextEdge += LOCAL_CLOCK_INCREMENT;

                /* If we are in an external clock mode and this fire, then clock invalid */

#ifdef SPDIF_RX 
               // if(clkMode == CLOCK_SPDIF)
                {
                    /* We must have lost valid S/PDIF stream, reset counters, so we dont produce a double edge */
                    spdifCounters.receivedSamples = 0;
                }
#endif
#ifdef ADAT_RX
                //if(clkMode == CLOCK_ADAT)
                {
                    adatCounters.receivedSamples = 0;
                }
#endif

#ifdef CLOCK_VALIDITY_CALL
                if(clkMode == CLOCK_INTERNAL)
                {
                    /* Internal clock always valid */
                    VendorClockValidity(1);
                }
#endif
                break;


#if defined(SPDIF_RX) || defined(ADAT_RX)
            case t_external when timerafter(timeNextClockDetection) :> void:
    
                timeNextClockDetection += (LOCAL_CLOCK_INCREMENT);
#ifdef SPDIF_RX
                tmp = spdifCounters.samplesPerTick;

                /* Returns 1 if valid clock found */
                tmp = validSamples(spdifCounters, CLOCK_SPDIF_INDEX);
                setClockValidity(c_clk_int, CLOCK_SPDIF_INDEX, tmp, clkMode);
#endif
#ifdef ADAT_RX
                tmp = validSamples(adatCounters, CLOCK_ADAT_INDEX);
                setClockValidity(c_clk_int, CLOCK_ADAT_INDEX, tmp, clkMode);
#endif
                
                break;

#endif

#ifdef SPDIF_RX
            /* Receive sample from S/PDIF RX thread (steaming chan) */
            case c_spdif_rx :> tmp:

                /* Record time of sample */
				t_local :> spdifReceivedTime;

                /* Check parity and ignore if bad */
                if(badParity(tmp))
                    continue;
                
                /* Get pre-amble */
				tmp2 = tmp & 0xF;
                switch(tmp2)
                {
                    /* LEFT */
                    case FRAME_X:
                    case FRAME_Z:
                            
                        spdifLeft = tmp << 4;
                        break;

                    /* RIGHT */
                    case FRAME_Y:

                        /* Only store sample if not in overflow and stream is reasonably valid */
                        if(!spdifOverflow && clockValid[CLOCK_SPDIF_INDEX])
                        {
                            /* Store left and right sample pair to buffer */
                            spdifSamples[spdifWr] = spdifLeft;
                            spdifSamples[spdifWr+1] = tmp << 4;

                            spdifWr = (spdifWr + 2) & (MAX_SPDIF_SAMPLES - 1);

                            spdifSamps += 2;

                            /* Check for over flow */
                            if(spdifSamps > MAX_SPDIF_SAMPLES-1)
                            {
                                spdifOverflow = 1;
                            }  
                            
                            /* Check for coming out of under flow */
                            if(spdifUnderflow && (spdifSamps >= (MAX_SPDIF_SAMPLES >> 1)))
                            {
                                spdifUnderflow = 0; 
                            }
                        }
                        break;

                        default:
                            /* Bad sample, skip */
                            continue;
                            break;
                    }


                

                spdifCounters.samples += 1;

                if(clkMode == CLOCK_SPDIF && clockValid[CLOCK_SPDIF_INDEX])
                {
                    spdifCounters.receivedSamples+=1;
                       
                    /* Inspect for if we need to produce an edge */
                    if((spdifCounters.receivedSamples >=  spdifCounters.samplesPerTick))
                    {
                        /* Check edge is about right... S/PDIF may have changed freq... */
                        if(timeafter(spdifReceivedTime, (timeLastEdge + LOCAL_CLOCK_INCREMENT - LOCAL_CLOCK_MARGIN)))
                        { 
                            /* Record edge time */
                            timeLastEdge = spdifReceivedTime;
                            
                            /* Setup for next edge */  
                            timeNextEdge = spdifReceivedTime + LOCAL_CLOCK_INCREMENT + LOCAL_CLOCK_MARGIN;
                             
                            /* Toggle edge */
                            p <: pinVal @ pinTime;
                            pinTime += (short) LOCAL_CLOCK_INCREMENT;
                            pinVal = !pinVal;
                            p @ pinTime <: pinVal;

                            /* Reset counters */
                            spdifCounters.receivedSamples = 0;
                        }
                    }
                }
                break;
#endif 
#ifdef ADAT_RX
                /* receive sample from ADAT rx thread (streaming channel with CT_END) */
                case inuint_byref(c_adat_rx, tmp):
                    /* record time of sample */
                    t_local :> adatReceivedTime;

                    /* Sync is: 1 | (user_byte << 4) */
                    if(tmp&1)
                    {
                        /* user bits - start of frame */
                        adatChannel = 0;
                        continue;
                    }
                    else
                    {
                        /* audio sample */
                        adatSamplesEver++;
                        adatFrame[adatChannel] = tmp;
                            
                        adatChannel++;
                        if (adatChannel == 8)
                        {
                            /* only store left samples if not in overflow and stream is reasonably valid */
                            if (!adatOverflow && clockValid[CLOCK_ADAT_INDEX])
                            {
                                if(smux)
                                {

                                    adatSamples[adatWr + 0] = adatFrame[0];
                                    adatSamples[adatWr + 4] = adatFrame[1];
                                    adatSamples[adatWr + 1] = adatFrame[2];
                                    adatSamples[adatWr + 5] = adatFrame[3];
                                    adatSamples[adatWr + 2] = adatFrame[4];
                                    adatSamples[adatWr + 6] = adatFrame[5];
                                    adatSamples[adatWr + 3] = adatFrame[6];
                                    adatSamples[adatWr + 7] = adatFrame[7];
                                }
                                else
                                {
                                    adatSamples[adatWr + 0] = adatFrame[0];
                                    adatSamples[adatWr + 1] = adatFrame[1];
                                    adatSamples[adatWr + 2] = adatFrame[2];
                                    adatSamples[adatWr + 3] = adatFrame[3];
                                    adatSamples[adatWr + 4] = adatFrame[4];
                                    adatSamples[adatWr + 5] = adatFrame[5];
                                    adatSamples[adatWr + 6] = adatFrame[6];
                                    adatSamples[adatWr + 7] = adatFrame[7];
                                 }
                                    adatWr = (adatWr + 8) & (MAX_ADAT_SAMPLES - 1);
                                    adatSamps += 8;

                                    /* check for overflow */
                                    if (adatSamps > MAX_ADAT_SAMPLES - 1)
                                    {
                                        adatOverflow = 1;
                                    }

                                    /* check for coming out of underflow */
                                    if (adatUnderflow && (adatSamps >= (MAX_ADAT_SAMPLES >> 1)))
                                    {
                                        adatUnderflow = 0;
                                    }
                                }
                        }
                        if(adatChannel == 4 || adatChannel == 8)
                        {
                            adatCounters.samples += 1;
                    
                                if (clkMode == CLOCK_ADAT && clockValid[CLOCK_ADAT_INDEX])
                                {
                                    adatCounters.receivedSamples += 1;

                                    /* Inspect for if we need to produce an edge */
                                    if ((adatCounters.receivedSamples >= adatCounters.samplesPerTick))
                                    {
                                        /* Check edge is about right... S/PDIF may have changed freq... */
                                        if (timeafter(adatReceivedTime, (timeLastEdge + LOCAL_CLOCK_INCREMENT - LOCAL_CLOCK_MARGIN)))
                                        { 
                                            /* Record edge time */
                                            timeLastEdge = adatReceivedTime;
                                
                                            /* Setup for next edge */  
                                            timeNextEdge = adatReceivedTime + LOCAL_CLOCK_INCREMENT + LOCAL_CLOCK_MARGIN;
                                            
                                            /* Toggle edge */
                                            p <: pinVal @ pinTime;
                                            pinTime += LOCAL_CLOCK_INCREMENT;
                                            pinVal = !pinVal;
                                            p @ pinTime <: pinVal;

                                            /* Reset counters */
                                            adatCounters.receivedSamples = 0;

                                        }
                                    }
                                }
                            }
                            if (adatChannel == 8)
                              adatChannel = 0;
                        }
                    break;
#endif


#if defined(SPDIF_RX) || defined(ADAT_RX)
			/* Mixer requests data */
			case inuint_byref(c_dig_rx, tmp):
#ifdef SPDIF_RX
                    if(spdifUnderflow)
                    {
                        /* S/PDIF underflowing, send out zero samples */
                        g_digData[0] = 0;
                        g_digData[1] = 0;
                    }
                    else
                    {
                        /* Read out samples from S/PDIF buffer and send... */ 
                        tmp = spdifSamples[spdifRd];
                        tmp2 = spdifSamples[spdifRd + 1];

                        spdifRd += 2;
					    spdifRd &= (MAX_SPDIF_SAMPLES - 1);

#pragma xta endpoint "digital_out"

                        g_digData[0] = tmp;
                        g_digData[1] = tmp2;

                        spdifSamps -= 2;

                        /* spdifSamps could go to -1 */ 
                        if(spdifSamps < 0)
                        {
                            /* We're out of S/PDIF samples, mark underflow condition */
                            spdifUnderflow = 1;
                            spdifLeft = 0;
                        }

                        /* If we are in over flow condition and we have a sensible number of samples
                            * come out of overflow condition */
                        if(spdifOverflow && (spdifSamps < (MAX_SPDIF_SAMPLES>>1)))
                        {
                            spdifOverflow = 0;
                        }
                    }
		
#endif
#ifdef ADAT_RX
                if (adatUnderflow)
                {
                    /* ADAT underflowing, send out zero samples */
                    g_digData[2] = 0;
                    g_digData[3] = 0;
                    g_digData[4] = 0;
                    g_digData[5] = 0;
                    g_digData[6] = 0;
                    g_digData[7] = 0;
                    g_digData[8] = 0;
                    g_digData[9] = 0;
                }
                else
                {
                    /* TODO SMUX II mode */
                    /* read out samples from the ADAT buffer and send */
                    /* always return 8 samples */
                    if (smux) 
                    {
                        /* SMUX mode - 4 samples from fifo and 4 zero samples */
                        g_digData[2] = adatSamples[adatRd + 0];
                        g_digData[3] = adatSamples[adatRd + 1];
                        g_digData[4] = adatSamples[adatRd + 2];
                        g_digData[5] = adatSamples[adatRd + 3];
                       
                        g_digData[6] = 0;
                        g_digData[7] = 0;
                        g_digData[8] = 0;
                        g_digData[9] = 0;
                        adatRd = (adatRd + 4) & (MAX_ADAT_SAMPLES - 1);
                        adatSamps -= 4;
                    }
                    else
                    {
                        /* no SMUX mode - 8 samples from fifo */
                        g_digData[2] = adatSamples[adatRd + 0];
                        g_digData[3] = adatSamples[adatRd + 1];
                        g_digData[4] = adatSamples[adatRd + 2];
                        g_digData[5] = adatSamples[adatRd + 3];

                        g_digData[6] = adatSamples[adatRd + 4];
                        g_digData[7] = adatSamples[adatRd + 5];
                        g_digData[8] = adatSamples[adatRd + 6];
                        g_digData[9] = adatSamples[adatRd + 7];

                        adatRd = (adatRd + 8) & (MAX_ADAT_SAMPLES - 1);
                        adatSamps -= 8;
                    }

                    /* adatSamps could go to -1 */
                    if (adatSamps < 0)
                    {
                        /* we're out of ADAT samples, mark underflow condition */
                        adatUnderflow = 1;
                    }

                    /* if we are in overflow condition and have a sensible number of samples
                       come out of overflow condition */
                    if (adatOverflow && adatSamps < (MAX_ADAT_SAMPLES >> 1))
                    {
                        adatOverflow = 0;
                    }
                }
#endif
                outuint(c_dig_rx, 1);
				break;
#endif
        }

    }
}


