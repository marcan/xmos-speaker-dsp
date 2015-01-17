import sys
from math import cos, sin, pi, sqrt
import struct
import usb.core
import usb.util

CHANNELS = 6
FRACTIONALBITS = 28
SET_DSP_BIQUAD = 1
SET_DSP_DELAY = 2
DSP_FILTERS = 15
FS = 96000.0

class Biquad(object):
	def __init__(self, b0, b1, b2, a0, a1, a2):
		self.b0 = b0 / a0
		self.b1 = b1 / a0
		self.b2 = b2 / a0
		self.a1 = a1 / a0
		self.a2 = a2 / a0
	@property
	def coefs(self):
		return (self.b0, self.b1, self.b2, -self.a1, -self.a2)
	def apply_gain(self, gain):
		v = 10 ** (gain / 20.0)
		self.b0 *= v
		self.b1 *= v
		self.b2 *= v
	def __str__(self):
		return 'Biquad<%.03f %.03f %.03f %.03f %.03f>' % self.coefs

class SimpleBiquad(Biquad):
	def __init__(self, f0, Q):
		self.f0 = f0
		self.Q = Q
		self.build()
		Biquad.__init__(self, self.b0, self.b1, self.b2, self.a0, self.a1, self.a2)
	@property
	def w0(self):
		return 2 * pi * self.f0 / FS
	@property
	def alpha(self):
		return sin(self.w0) / (2.0 * self.Q)
	def __str__(self):
		return '%s(f0=%.03f, Q=%.03f)' % (self.__class__.__name__, self.f0, self.Q)

class GainBiquad(SimpleBiquad):
	def __init__(self, f0, Q, gain):
		self.gain = gain
		SimpleBiquad.__init__(self, f0, Q)
	@property
	def A(self):
		return 10 ** (self.gain / 40.0)
	def __str__(self):
		return '%s(f0=%.03f, Q=%.03f, gain=%.02f)' % (self.__class__.__name__,  self.f0, self.Q, self.gain)

class LPF(SimpleBiquad):
	def build(self):
		self.b0 =  (1 - cos(self.w0))/2
		self.b1 =   1 - cos(self.w0)
		self.b2 =  (1 - cos(self.w0))/2
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class HPF(SimpleBiquad):
	def build(self):
		self.b0 =  (1 + cos(self.w0))/2
		self.b1 = -(1 + cos(self.w0))
		self.b2 =  (1 + cos(self.w0))/2
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class BPFSkirt(SimpleBiquad):
	def build(self):
		self.b0 =   sin(self.w0)/2
		self.b1 =   0
		self.b2 =  -sin(self.w0)/2
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class BPFPeak(SimpleBiquad):
	def build(self):
		self.b0 =   self.alpha
		self.b1 =   0
		self.b2 =  -self.alpha
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class notch(SimpleBiquad):
	def build(self):
		self.b0 =   1
		self.b1 =  -2*cos(self.w0)
		self.b2 =   1
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class APF(SimpleBiquad):
	def build(self):
		self.b0 =   1 - self.alpha
		self.b1 =  -2*cos(self.w0)
		self.b2 =   1 + self.alpha
		self.a0 =   1 + self.alpha
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha

class PeakingEQ(GainBiquad):
	def build(self):
		self.b0 =   1 + self.alpha*self.A
		self.b1 =  -2*cos(self.w0)
		self.b2 =   1 - self.alpha*self.A
		self.a0 =   1 + self.alpha/self.A
		self.a1 =  -2*cos(self.w0)
		self.a2 =   1 - self.alpha/self.A

class LowShelf(GainBiquad):
	def build(self):
		A = self.A
		self.b0 =    A*( (A+1) - (A-1)*cos(self.w0) + 2*sqrt(A)*self.alpha )
		self.b1 =  2*A*( (A-1) - (A+1)*cos(self.w0) )
		self.b2 =    A*( (A+1) - (A-1)*cos(self.w0) - 2*sqrt(A)*self.alpha )
		self.a0 =        (A+1) + (A-1)*cos(self.w0) + 2*sqrt(A)*self.alpha
		self.a1 =   -2*( (A-1) + (A+1)*cos(self.w0) )
		self.a2 =        (A+1) + (A-1)*cos(self.w0) - 2*sqrt(A)*self.alpha

class HighShelf(GainBiquad):
	def build(self):
		A = self.A
		self.b0 =    A*( (A+1) + (A-1)*cos(self.w0) + 2*sqrt(A)*self.alpha )
		self.b1 = -2*A*( (A-1) + (A+1)*cos(self.w0) )
		self.b2 =    A*( (A+1) + (A-1)*cos(self.w0) - 2*sqrt(A)*self.alpha )
		self.a0 =        (A+1) - (A-1)*cos(self.w0) + 2*sqrt(A)*self.alpha
		self.a1 =    2*( (A-1) - (A+1)*cos(self.w0) )
		self.a2 =        (A+1) - (A-1)*cos(self.w0) - 2*sqrt(A)*self.alpha

class LowShelfS(LowShelf):
	def __init__(self, f0, S, gain):
		self.gain = gain
		Q = 1.0/sqrt((self.A + 1.0/self.A)*(1.0/S - 1.0) + 2.0)
		LowShelf.__init__(self, f0, Q, gain)

class HighShelfS(HighShelf):
	def __init__(self, f0, S, gain):
		self.gain = gain
		Q = 1.0/sqrt((self.A + 1.0/self.A)*(1.0/S - 1.0) + 2.0)
		HighShelf.__init__(self, f0, Q, gain)

class AudioInterface(object):
	def __init__(self):
		self.dev = usb.core.find(idVendor=0x20b1, idProduct=0x0004)
		if self.dev is None:
			raise Exception('Device not found')

	def set_biquad(self, channel, index, biquad):
		params = [int(i*(1<<FRACTIONALBITS)+0.5) for i in biquad.coefs]
		data = struct.pack('<5i', *params)
		assert 0 <= channel < 6
		assert 0 <= index < DSP_FILTERS
		index = (channel << 8) | index
		self.dev.ctrl_transfer(0x40, SET_DSP_BIQUAD, 0, index, data)

	def reset(self):
		for channel in range(CHANNELS):
			self.reset_channel(channel)

	def reset_channel(self, channel):
		unity = Biquad(1,0,0,1,0,0)
		for idx in range(DSP_FILTERS):
			self.set_biquad(channel, idx, unity)

	def set_delay(self, channel, delay):
		assert 0 <= channel < 6
		delay = int(FS / 1000.0 * delay + 0.5)
		self.dev.ctrl_transfer(0x40, SET_DSP_DELAY, delay, channel)

class FilterFile(object):
	def __init__(self, filename):
		self.load(filename)
	def load(self, filename):
		fd = open(filename)
		lines = iter(fd)
		if lines.next() != 'Filter Settings file\n':
			raise Exception('Invalid format')
		self.biquads = []
		for line in lines:
			if not line.startswith('Filter '):
				continue
			line = line.replace('\n','').split()
			if line[2] != 'ON':
				continue
			ftype = line[3]
			if ftype == 'PK':
				f0 = float(line[5].replace(',',''))
				gain = float(line[8])
				Q = float(line[11])
				self.biquads.append(PeakingEQ(f0, Q, gain))
			elif ftype == 'HP':
				f0 = float(line[5].replace(',',''))
				self.biquads.append(HPF(f0, 0.7071))
			elif ftype == 'LP':
				f0 = float(line[5].replace(',',''))
				self.biquads.append(LPF(f0, 0.7071))
			elif ftype == 'HS':
				f0 = float(line[5].replace(',',''))
				gain = float(line[8])
				self.biquads.append(HighShelfS(f0, 1.0, gain))
			elif ftype == 'LS':
				f0 = float(line[5].replace(',',''))
				gain = float(line[8])
				self.biquads.append(LowShelfS(f0, 1.0, gain))
			elif ftype == 'None':
				continue
			else:
				raise Exception('Invalid filter type %s' % ftype)

if __name__ == '__main__':
	cmd = sys.argv[1]
	dev = AudioInterface()
	if cmd == 'load':
		channel = int(sys.argv[2])
		data = FilterFile(sys.argv[3])
		if len(sys.argv) > 4:
			gain = float(sys.argv[4])
			data.biquads[-1].apply_gain(gain)
		dev.reset_channel(channel)
		for i,biquad in enumerate(data.biquads):
			print '%d: %s' % (i, biquad)
			dev.set_biquad(channel, i, biquad)
	elif cmd == 'reset':
		if len(sys.argv) > 2:
			dev.reset_channel(int(sys.argv[2]))
		else:
			dev.reset()
	elif cmd == 'set':
		channel = int(sys.argv[2])
		idx = int(sys.argv[3])
		args = map(float, sys.argv[4:])
		dev.set_biquad(channel, idx, Biquad(*args))
	elif cmd == 'delay':
		channel = int(sys.argv[2])
		delay = float(sys.argv[3])
		dev.set_delay(channel, delay)
	else:
		print "Unknown command"
