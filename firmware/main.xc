/**
 * Module:  app_usb_aud_l2
 * Version: 5v3rc0
 * Build:   ac6a4e693026146f3f2e1eb14f33e54ebc385068
 * File:	main.xc
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
 * @file	main.xc
 * @brief   XMOS L2 USB 2.0 Audio 2.0 Reference Design.  Top level.
 * @author  Ross Owen, XMOS Semiconductor Ltd 
 * @version 1.4
 */	

#include <syscall.h>
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include <xscope.h>
#include <stdio.h>

#include "xud.h"				 /* XMOS USB Device Layer defines and functions */
#include "usb.h"				 /* Defines from the USB 2.0 Specification */


#include "customdefines.h"
#include "devicedefines.h"	  /* Device specific defines */
#include "endpoint0.h"
#include "usb_buffer.h"
#include "decouple.h"

void audio(chanend c_mix_out, chanend?, chanend?);
void clockGen (streaming chanend c_spdif_rx, chanend c_adat_rx, out port p, chanend, chanend, chanend);
void mixer(chanend, chanend, chanend);
void dsp(chanend);
void dsp_router(chanend, chanend, chanend, chanend);

/* Cores */
#define CORE_USB					0
#define CORE_AUD					1
#define CORE_DSP					2

/* Core 0 */
#define PORT_USB_RST				XS1_PORT_1M
#define PORT_PLL_CLK				XS1_PORT_4E		 /* Clk Output to PLL */

/* Core 1 */
#define PORT_COD_CLK_BIT			XS1_PORT_1I		 /* Bit clock */
#define PORT_COD_CLK_LR			 XS1_PORT_1E		 /* LR clock */
#define PORT_I2C_SCL				XS1_PORT_1D
#define PORT_I2C_SDA				XS1_PORT_1C

#define PORT_COD_DAC_0			  XS1_PORT_1M
#define PORT_COD_DAC_1			  XS1_PORT_1F
#define PORT_COD_DAC_2			  XS1_PORT_1H
#define PORT_COD_DAC_3			  XS1_PORT_1N

#define PORT_COD_ADC_0			  XS1_PORT_1G
#define PORT_COD_ADC_1			  XS1_PORT_1A
#define PORT_COD_ADC_2			  XS1_PORT_1B

#define PORT_COD_CLK_MAS			XS1_PORT_1L

on stdcore[CORE_USB] : buffered in port:4 p_spdif_rx	= XS1_PORT_1K; /* K: coax, J: optical */
on stdcore[CORE_USB] : buffered in port:32 p_adat_rx	= XS1_PORT_1J; /* K: coax, J: optical */
on stdcore[CORE_USB] : out port p_usb_rst			   = PORT_USB_RST;
on stdcore[CORE_USB] : in port p_for_mclk_count		 = XS1_PORT_32A;
on stdcore[CORE_USB] : in port p_mclk_too			   = XS1_PORT_1L;
on stdcore[CORE_AUD] : out port p_pll_clk			   = PORT_PLL_CLK;
#ifdef CODEC_SLAVE 
on stdcore[CORE_AUD] : buffered out port:32 p_lrclk	 = PORT_COD_CLK_LR;
on stdcore[CORE_AUD] : buffered out port:32 p_bclk	  = PORT_COD_CLK_BIT;
#else
on stdcore[CORE_AUD] : in port p_lrclk				  = PORT_COD_CLK_LR;
on stdcore[CORE_AUD] : in port p_bclk				   = PORT_COD_CLK_BIT;
#endif
on stdcore[CORE_AUD] : port p_mclk					  = PORT_COD_CLK_MAS;
on stdcore[CORE_AUD] : out port p_aud_cfg			   = XS1_PORT_4A;
on stdcore[CORE_AUD] : port p_i2c_scl				   = PORT_I2C_SCL;	 // 2-wire configuration interface.
on stdcore[CORE_AUD] : port p_i2c_sda				   = PORT_I2C_SDA;
on stdcore[CORE_AUD] : buffered out port:32 p_spdif_tx  = XS1_PORT_1K;	  // K: coax, J: optical
on stdcore[CORE_AUD] : out port p_midi_tx			   = XS1_PORT_1O;
on stdcore[CORE_AUD] : port p_midi_rx				   = XS1_PORT_1P;
on stdcore[CORE_AUD] : buffered out port:32 p_i2s_dac[I2S_WIRES_DAC] = {PORT_COD_DAC_0, PORT_COD_DAC_1, PORT_COD_DAC_2, PORT_COD_DAC_3};
on stdcore[CORE_AUD] : buffered in port:32 p_i2s_adc[I2S_WIRES_ADC]  = {PORT_COD_ADC_0, PORT_COD_ADC_1, PORT_COD_ADC_2};

/* Clock blocks */
on stdcore[CORE_USB] : clock	clk_adat_rx			 = XS1_CLKBLK_1;
on stdcore[CORE_USB] : clock	clk_spi				 = XS1_CLKBLK_2;
on stdcore[CORE_USB] : clock	clk					 = XS1_CLKBLK_3;	 /* USB clock */
on stdcore[CORE_USB] : clock	clk_spd_rx			  = XS1_CLKBLK_4;
on stdcore[CORE_USB] : clock	clk_master_too		  = XS1_CLKBLK_5;	 /* Master clock on USB core */

on stdcore[CORE_AUD] : clock	clk_audio_mclk		  = XS1_CLKBLK_1;	 /* Master clock */
on stdcore[CORE_AUD] : clock	clk_audio_bclk		  = XS1_CLKBLK_2;	 /* Bit clock */
on stdcore[CORE_AUD] : clock	clk_midi				= XS1_CLKBLK_3;
on stdcore[CORE_AUD] : clock	clk_mst_spd			 = XS1_CLKBLK_4;

on stdcore[CORE_AUD] : out port p_led				   = XS1_PORT_8B;
on stdcore[CORE_AUD] : out port p_gpio				  = XS1_PORT_4F;

/* Endpoint type tables for XUD */
XUD_EpType epTypeTableOut[NUM_EP_OUT] = { XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, 
											XUD_EPTYPE_ISO};

XUD_EpType epTypeTableIn[NUM_EP_IN] = { XUD_EPTYPE_CTL | XUD_STATUS_ENABLE,
											XUD_EPTYPE_ISO,
											XUD_EPTYPE_ISO,
											XUD_EPTYPE_BUL};

void InitMixers(chanend c_mix_ctl);

int main()
{
	chan c_sof;
	
	chan c_xud_out[NUM_EP_OUT];			  /* Endpoint channels for XUD */
	chan c_xud_in[NUM_EP_IN];
	
	chan c_aud_ctl;
	chan c_mix_ctl;
	chan c_clk_ctl;

#ifdef MIXER	
	chan c_mix_out;
#endif

	chan c_dig_rx;
	chan c_del_out;
	chan c_dsp_out;
#ifdef DEBUG_LEDS
	chan c_led;
#endif
	streaming chan c_spdif_rx;
	chan c_adat_rx;  // CT_END after each sample
	chan c_clk_int;
	chan c_dsp;
	chan c_dsp_ctl;

	par
	{
		/* Core 0 */
		/* USB Interface */
		on stdcore[0] :
		{
#ifdef DEBUG
			xscope_register(0);
			xscope_config_io(XSCOPE_IO_BASIC);
#endif
			puts("Hello, world from mgr!");
			XUD_Manager(c_xud_out, NUM_EP_OUT, c_xud_in, NUM_EP_IN,
				c_sof, epTypeTableOut, epTypeTableIn, p_usb_rst, clk, 1, XUD_SPEED_HS, null);
		}
	
		/* Endpoint 0 */
		on stdcore[0] :
		{
			puts("Hello, world from ep0!");
			InitMixers(c_mix_ctl);
			Endpoint0( c_xud_out[0], c_xud_in[0], c_aud_ctl, c_mix_ctl, c_clk_ctl, c_dsp_ctl);
		}

		/* Buffer / EP Man */
		on stdcore[0] :
		{
			set_thread_fast_mode_on();
			configure_clock_src(clk_master_too, p_mclk_too);
			set_port_clock(p_for_mclk_count, clk_master_too);
			start_clock(clk_master_too);

			puts("Hello, world from buffer!");
			buffer(c_xud_out[1], c_xud_in[2], c_xud_in[1],
				c_xud_in[3],
				c_sof,  c_aud_ctl,
				p_for_mclk_count);
		}

		on stdcore[0] :
		{
			unsigned int i;
			puts("Hello, world from decouple!");
			decouple(c_mix_out, c_clk_int, c_led);
		}
/*
		on stdcore[1] :
		{
			unsigned int i;
			while(1) {
				
				c_led :> i;
				p_led <: i;
			}
		}
*/
		/* Core 1 */
		on stdcore[1] :
		{
			puts("Hello, world from mixer!");
			mixer(c_mix_out, c_dsp_out, c_mix_ctl);
		}

		/* Audio I/O (pars additional S/PDIF TX thread) */
		on stdcore[1] :
		{
			puts("Hello, world from AudioIO!");
			audio(c_del_out, c_dig_rx, null) ;
		}

		on stdcore[1] :
		{
			puts("Hello, world from clockGen!");
			clockGen(c_spdif_rx, c_adat_rx, p_pll_clk, c_dig_rx, c_clk_ctl, c_clk_int);
		}

		on stdcore[1] :
		{
			puts("Hello, world from DSP Router!");
			dsp_router(c_dsp_out, c_del_out, c_dsp, c_dsp_ctl);
		}
		on stdcore[2] :
		{
			puts("Hello, world from DSP!");
			dsp(c_dsp);
		}
	}

	return 0;
}
