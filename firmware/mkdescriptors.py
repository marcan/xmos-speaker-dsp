import struct

CS_INTERFACE = 0x24
HEADER = 0x01
INPUT_TERMINAL = 0x02
OUTPUT_TERMINAL = 0x03
MIXER_UNIT = 0x04
SELECTOR_UNIT = 0x05
FEATURE_UNIT = 0x06
EFFECT_UNIT = 0x07
PROCESSING_UNIT = 0x08
EXTENSION_UNIT = 0x09
CLOCK_SOURCE = 0x0a
CLOCK_SELECTOR = 0x0b
CLOCK_MULTIPLIER = 0x0c
SAMPLE_RATE_CONVERTER = 0x0d

#channels = "FL FR FC LFE BL BR"
channels = "FL FR BL BR FC LFE"
for i,c in enumerate(channels.split()):
	globals()["C_%s" % c] = 1 << i
for i,c in enumerate(channels.split()):
	globals()["%s" % c] = i + 1

CHAN_STEREO = (2, C_FL | C_FR)
CHAN_6CH = (6, C_FL | C_FR | C_FC | C_LFE | C_BL | C_BR)
MASTER = 0

RO = 0x01
RW = 0x03

USB_STREAMING = 0x0101
LINE_CONNECTOR = 0x0603

UP_DOWNMIX_PROCESS = 0x01

CLOCK_INT_FIXED = 0x01

HOME_THEATER = 0x02

string_offset = 6
strings = []
audio_descriptors = []

def mkstring(s):
	if s is None:
		return 0
	if s in strings:
		return strings.index(s) + string_offset
	else:
		strings.append(s)
		return len(strings) - 1 + string_offset

class Descriptor(object):
	def __init__(self, type):
		self.type = type

	def build(self, data):
		data = struct.pack("<B", self.type) + data
		assert len(data) < 255
		return struct.pack("<B", len(data) + 1) + data

class AudioDescriptor(Descriptor):
	_id = 1
	CONTROLS = []
	def __init__(self, subtype, id):
		if id is not None:
			self.id = id
		else:
			self.id = self.new_id()

		self.subtype = subtype
		Descriptor.__init__(self, CS_INTERFACE)
		audio_descriptors.append(self)

	@staticmethod
	def new_id():
		id = AudioDescriptor._id
		AudioDescriptor._id += 1
		return id

	def get_channels(self):
		unit = self
		while True:
			try:
				channels = unit.channels
				return channels
			except AttributeError:
				unit = unit.source

	def mk_controls(self, ctls):
		v = 0
		for c, t in list(ctls.items()):
			idx = self.CONTROLS.index(c)
			v |= t<<(idx*2)
		return v

	def build(self, data):
		return Descriptor.build(self, struct.pack("<BB", self.subtype, self.id) + data)

class InputTerminal(AudioDescriptor):
	CONTROLS = "copy_protect connector overload cluster underflow overflow".split()
	def __init__(self, name, id, ttype, clock, channels=CHAN_STEREO, controls={}, assoc=0):
		self.name, self.ttype, self.channels, self.controls, self.assoc, self.clock = (
			name, ttype, channels, controls, assoc, clock)
		AudioDescriptor.__init__(self, INPUT_TERMINAL, id)

	def build(self):
		data = struct.pack("<HBBBIBHB",
			self.ttype, self.assoc, self.clock.id,
			self.channels[0], self.channels[1], 0, 
			self.mk_controls(self.controls), mkstring(self.name))
		return AudioDescriptor.build(self, data)

class OutputTerminal(AudioDescriptor):
	CONTROLS = "copy_protect connector overload underflow overflow".split()
	def __init__(self, name, id, ttype, source, clock, controls={}, assoc=0):
		self.name, self.ttype, self.source, self.controls, self.assoc, self.clock = (
			name, ttype, source, controls, assoc, clock)
		AudioDescriptor.__init__(self, OUTPUT_TERMINAL, id)

	def build(self):
		data = struct.pack("<HBBBHB",
			self.ttype, self.assoc, self.source.id, self.clock.id,
			self.mk_controls(self.controls), mkstring(self.name))
		return AudioDescriptor.build(self, data)

class ClockSource(AudioDescriptor):
	CONTROLS = "frequency validity".split()
	def __init__(self, name, id, attr, controls={}, assoc=0):
		self.name, self.attr, self.controls, self.assoc = name, attr, controls, assoc
		AudioDescriptor.__init__(self, CLOCK_SOURCE, id)

	def build(self):
		data = struct.pack("<BBBB", self.attr,
			self.mk_controls(self.controls),
			self.assoc, mkstring(self.name))
		return AudioDescriptor.build(self, data)

class FeatureUnit(AudioDescriptor):
	CONTROLS = "mute volume bass mid treble eq agc delay bassboost loudness gain pad phase underflow overflow".split()
	def __init__(self, name, id, source, controls={}):
		self.name, self.source, self.controls = (
			name, source, controls)
		AudioDescriptor.__init__(self, FEATURE_UNIT, id)

	def build(self):
		ch_cnt = self.get_channels()[0]
		data = struct.pack("<B", self.source.id)
		for i in range(ch_cnt + 1):
			data += struct.pack("<I", self.mk_controls(self.controls.get(i, {})))
		data += struct.pack("<B", mkstring(self.name))
		return AudioDescriptor.build(self, data)

class UpDownMixUnit(AudioDescriptor):
	CONTROLS = "enable mode cluster underflow overflow".split()
	def __init__(self, name, id, source, channels=CHAN_STEREO, controls={}, modes=[]):
		self.name, self.source, self.channels, self.controls, self.modes = (
			name, source, channels, controls, modes)
		AudioDescriptor.__init__(self, PROCESSING_UNIT, id)

	def build(self):
		ch_cnt = self.get_channels()[0]
		data = struct.pack("<HBBBIBHBB", UP_DOWNMIX_PROCESS, 1,
			self.source.id, self.channels[0], self.channels[1], 0,
			self.mk_controls(self.controls), mkstring(self.name), len(self.modes))
		for i in self.modes:
			data += struct.pack("<I", i[1])
		return AudioDescriptor.build(self, data)

class MixerUnit(AudioDescriptor):
	CONTROLS = "cluster underflow overflow".split()
	def __init__(self, name, id, sources, channels=CHAN_STEREO, controls={}):
		self.name, self.sources, self.channels, self.controls = (
			name, sources, channels, controls)
		AudioDescriptor.__init__(self, MIXER_UNIT, id)

	def build(self):
		in_ch = sum(i.get_channels()[0] for i in self.sources)
		data = struct.pack("<B", len(self.sources))
		for i in self.sources:
			data += struct.pack("<B", i.id)
		data += struct.pack("<BIB", self.channels[0], self.channels[1], 0)
		data += b"\x00" * ((in_ch * self.channels[0] + 7) // 8)
		data += struct.pack("<BB", self.mk_controls(self.controls), mkstring(self.name))
		return AudioDescriptor.build(self, data)

class SelectorUnit(AudioDescriptor):
	CONTROLS = "selector".split()
	def __init__(self, name, id, sources, controls = {}):
		self.name, self.sources, self.controls = name, sources, controls
		self.channels = self.sources[0].get_channels()
		for i in self.sources:
			assert self.channels == i.get_channels()
		AudioDescriptor.__init__(self, SELECTOR_UNIT, id)

	def build(self):
		data = struct.pack("<B", len(self.sources))
		for i in self.sources:
			data += struct.pack("<B", i.id)
		data += struct.pack("<BB", self.mk_controls(self.controls), mkstring(self.name))
		return AudioDescriptor.build(self, data)

class Header(Descriptor):
	def __init__(self, adc, category, children):
		self.adc, self.category, self.children = adc, category, children
		self.total_len = sum(len(i.build()) for i in self.children) + 9
		Descriptor.__init__(self, CS_INTERFACE)

	def build(self):
		data = struct.pack("<BHBHB", HEADER, self.adc, self.category, self.total_len, 0)
		return Descriptor.build(self, data)

def vol_mute(*channels):
	return dict((i,{"volume": RW, "mute": RW}) for i in channels)

def vol(*channels):
	return dict((i,{"volume": RW}) for i in channels)

clock = ClockSource(None, None, CLOCK_INT_FIXED, {"frequency": RW, "validity": RO})
usb_in = InputTerminal("PCM", None, USB_STREAMING, clock, CHAN_6CH)
pcm_vol = FeatureUnit("PCM", None, usb_in, vol_mute(MASTER))
hp_downmix = UpDownMixUnit(None, None, pcm_vol, CHAN_STEREO, modes=[CHAN_STEREO])

aux_cap = []
aux_hp = []
aux_play = []

for aux in (1, 2, 3):
	id = aux << 5
	input = InputTerminal("Aux %d" % aux, id, LINE_CONNECTOR, clock)
	id += 1
	mode_norm = MixerUnit("Stereo", id, [input], CHAN_STEREO)
	mode_bal = MixerUnit("Balanced", id+1, [input], CHAN_STEREO)
	mode_clfe = MixerUnit("CLFE", id+2, [input], CHAN_STEREO)
	id += 3
	mode_sel = SelectorUnit("Aux %d Mode" % aux, id, [mode_norm, mode_bal, mode_clfe], {"selector": RW})
	id += 1
	play_vol = FeatureUnit("Aux %d Master" % aux, id, mode_sel, vol_mute(FL,FR))
	aux_hp.append(play_vol)
	id += 1
	cap_vol = FeatureUnit("Aux %d Capture" % aux, id, mode_sel, vol(FL,FR))
	id += 1
	cap_mix = MixerUnit("Aux %d Capture" % aux, id, [cap_vol], CHAN_STEREO)
	aux_cap.append(cap_mix)
	id += 1
	upmix = UpDownMixUnit(None, id, play_vol, CHAN_6CH, modes=[CHAN_6CH])
	id += 1
	mix_vol = FeatureUnit("Aux %d" % aux, id, upmix, vol_mute(FL, FR, BL, BR, FC, LFE))
	id += 1
	rot_0 = MixerUnit("0", id, [mix_vol], CHAN_6CH)
	rot_90 = MixerUnit("90", id+1, [mix_vol], CHAN_6CH)
	rot_180 = MixerUnit("180", id+2, [mix_vol], CHAN_6CH)
	rot_270 = MixerUnit("270", id+3, [mix_vol], CHAN_6CH)
	id += 4
	rot_sel = SelectorUnit("Aux %d Rotation" % aux, id, [rot_0, rot_90, rot_180, rot_270], {"selector": RW})
	id += 1
	aux_play.append(rot_sel)

spkr_mix = MixerUnit(None, None, [pcm_vol] + aux_play, CHAN_6CH)
spkr_master = FeatureUnit("Master", None, spkr_mix, vol_mute(MASTER))

hp_mix = MixerUnit(None, None, [hp_downmix] + aux_hp, CHAN_STEREO)
hp_vol = FeatureUnit("Headphones", None, hp_mix, vol_mute(FL,FR))
hp_out = OutputTerminal("Headphones", None, LINE_CONNECTOR, hp_vol, clock)

spkr_vol = FeatureUnit("Speakers", None, spkr_master, vol_mute(FL,FR,BL,BR,FC,LFE))
spkr_out = OutputTerminal("Speakers", None, LINE_CONNECTOR, spkr_vol, clock)

cap_mix = MixerUnit("Mix", None, aux_cap, CHAN_STEREO)
cap_sel = SelectorUnit("Capture Source", None, aux_cap + [cap_mix], {"selector": RW})
usb_out = OutputTerminal("Capture", None, USB_STREAMING, cap_sel, clock)

header = Header(0x200, HOME_THEATER, audio_descriptors)

print("#define AC_TLEN 0x%04x" % header.total_len)
print("#define AC_DESCRIPTORS \\")
for i in [header] + audio_descriptors:
	if isinstance(i, AudioDescriptor) and i.name is not None:
		print("\t/* %s: %s */ \\" % (i.__class__.__name__, i.name))
	else:
		print("\t/* %s */ \\" % (i.__class__.__name__))
	print("\t%s, \\" % ", ".join("0x%02x"%c for c in i.build()))
print()
print("#define AC_STRINGS \\")
for i, j in enumerate(strings):
	print("\t/* %02x */ \"%s\", \\" % (i+string_offset, j))
print()
print("#define ID_CLKSRC 0x%02x" % clock.id)
print("#define ID_USB_IN 0x%02x" % usb_in.id)
print("#define ID_PCM_VOL 0x%02x" % pcm_vol.id)

print("#define ID_HP_VOL 0x%02x" % hp_vol.id)
print("#define ID_HP_OUT 0x%02x" % hp_out.id)

print("#define ID_SPKR_MASTER 0x%02x" % spkr_master.id)
print("#define ID_SPKR_VOL 0x%02x" % spkr_vol.id)
print("#define ID_SPKR_OUT 0x%02x" % spkr_out.id)

print("#define ID_CAP_SEL 0x%02x" % cap_sel.id)
print("#define ID_USB_OUT 0x%02x" % usb_out.id)

print("#define ID_AUX_IT 0x%02x" % (input.id & 0x1f))
print("#define ID_AUX_MODE_SEL 0x%02x" % (mode_sel.id & 0x1f))
print("#define ID_AUX_CAP_VOL 0x%02x" % (cap_vol.id & 0x1f))
print("#define ID_AUX_PLAY_VOL 0x%02x" % (play_vol.id & 0x1f))
print("#define ID_AUX_MIX_VOL 0x%02x" % (mix_vol.id & 0x1f))
print("#define ID_AUX_ROT_SEL 0x%02x" % (rot_sel.id & 0x1f))

