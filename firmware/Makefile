XCC := xcc
XCFLAGS := -Wall -W -O2 audio.xn -Wno-switch-fallthrough -report -Wno-timing
LD := xmap
LDFLAGS :=


# Build with "V=1" to see the commands executed; be quiet otherwise.

ifeq ($(V),1)
	Q :=
else
	Q := @
endif


OBJS := main.o
OBJS += endpoint0.o DescriptorRequests.o audiorequests.o audiostream.o
OBJS += decouple.o audio.o clocking.o usb_buffer.o clockgen.o codec.o
OBJS += mixer.o fastmix.o i2c.o codec.o pll.o audioports.o get_adc_counts.o
OBJS += XUD_EpFunctions.o XUD_UIFM_Ports.o XUD_EpFuncs.o dbcalc.o dsp.o
OBJS += dsp_router.o biquad.o SpdifReceive.o

LIBS := libxud.a

.PHONY: all
all: tt



tt: $(OBJS)
	@echo "  LINK      $@"
	$(Q)$(XCC) $(XCFLAGS) -o $@ $^ $(LIBS)

%.o: %.xc *.h auto_descriptors.h Makefile audio.xn
	@echo "  COMPILE   $@"
	$(Q)$(XCC) $(XCFLAGS) -o $@ -c $<

%.o: %.c *.h auto_descriptors.h Makefile audio.xn
	@echo "  COMPILE   $@"
	$(Q)$(XCC) $(XCFLAGS) -o $@ -c $<

%.s: %.c *.h auto_descriptors.h Makefile audio.xn
	@echo "  COMPILE   $@"
	$(Q)$(XCC) $(XCFLAGS) -o $@ -S $<

%.o: %.S *.h auto_descriptors.h Makefile audio.xn
	@echo "  ASSEMBLE  $@"
	$(Q)$(XCC) $(XCFLAGS) -o $@ -c $<

auto_descriptors.h: mkdescriptors.py
	@echo "  GEN       $@"
	$(Q)python $< > $@

.version: FORCE
	$(Q)./describe.sh > .$@-tmp
	$(Q)cmp -s $@ .$@-tmp || cp .$@-tmp $@
	$(Q)rm .$@-tmp

version.c: .version
	@echo "  VERSION   $@"
	$(Q)echo "const char version[] = \"`cat $^` (`whoami`@`hostname -s`)\";" > $@

FORCE:

.PHONY: clean
clean:
	-rm -f tt $(OBJS) .version version.c auto_descriptors.h
