/**
* Module:  module_usb_aud_shared
* Version: 2v1
* Build:   1137252aa759ee4479f7173a0179819799b32a18
* File:    get_adc_counts.c
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
void GetADCCounts(unsigned samFreq, int *min, int *mid, int *max)
{
	unsigned frameTime;
	frameTime = 8000;

	*min = samFreq / frameTime;
	*max = *min + 1;

	*mid = *min;

	/* Check for INT(SampFreq/8000) == SampFreq/8000 */
	if((samFreq % frameTime) == 0)
	{
		*min -= 1;
	}

}
