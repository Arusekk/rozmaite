#!/usr/bin/env python3

import argparse
import collections
import enum
import errno
import io
import mmap
import os
import struct
import sys
import weakref
import _pyio

class fattrs(enum.IntFlag):
	(readonly, hidden, system, volume_label, subdirectory, archive, device,
	 reserved) = (1<<x for x in range(8))

struts = {s.size: s for s in (struct.Struct("<"+l) for l in "BHIQ")}
def b2int(s):
	return struts[len(s)].unpack(s)[0]
def b2str(s):
	return s.rstrip(b' ').decode('utf-8', 'surrogateescape')
def b2hex(s):
	return hexint(b2int(s))

class hexint(int):
	def __repr__(self):
		return hex(self)

class EmptyMmap(io.BytesIO):
	def __len__(self):return 0

StructField = collections.namedtuple('StructField', ['conv', 'start', 'length'])

class StructDict(dict):
	def __setitem__(self, k, v):
		if not isinstance(v, StructField):
			return super().__setitem__(k, v)
		conv = v.conv
		start, end = v.start, v.length
		end += v.start
		def wrapper(self):
			return conv(self._mmap[start:end])
		wrapper.__name__ = wrapper.__qualname__ = k
		wrapper.__doc__ = "0x%03x:+%d"%(v.start, v.length)
		super().__setitem__(k, property(wrapper))

class Struct(type):
	@classmethod
	def __prepare__(cls, name, bases):
		return StructDict()

class BPB(metaclass=Struct):
	def __init__(self, fat, offset=0):
		self._mmap = mmap_wrapper(fat.fp.fileno(), 512, prot=mmap.PROT_READ, offset=offset)

	oem_name = StructField(b2str, 0x3, 8)

	# DOS 2.0

	bytes_per_sector = StructField(b2int, 0xb, 2)
	sectors_per_cluster = StructField(b2int, 0xd, 1)
	reserved_sectors = StructField(b2int, 0xe, 2)
	fats = StructField(b2int, 0x10, 1)
	legacy_maxroots = StructField(b2int, 0x11, 2)

	@property
	def total_sectors(self):
		"0x013:+2"
		return b2int(self._mmap[0x13:0x15]) or b2int(self._mmap[0x20:0x24]) or \
		       b2int(self._mmap[0x52:0x5a])

	medium_type = StructField(b2hex, 0x15, 1)

	@property
	def sectors_per_fat(self):
		"0x016:+2"
		return b2int(self._mmap[0x16:0x18]) or b2int(self._mmap[0x24:0x28])

	# DOS 3.0
	chs_sectors = StructField(b2int, 0x18, 2)
	chs_heads = StructField(b2int, 0x1a, 2)
	hidden_sectors = StructField(b2int, 0x1c, 2)

	# DOS 3.2
	total_sectors_w_hidden = StructField(b2int, 0x1e, 2)

	# FAT

	f32_version = StructField(b2int, 0x2a, 2)

	@property
	def root_dir_clust(self):
		"0x02c:+4"
		return b2int(self._mmap[0x2c:0x30]) if self.is_fat32 else 2 + (-FATDir.entrysize*self.legacy_maxroots)//(self.bytes_per_cluster or 512)

	f32_fsi_sector = StructField(b2int, 0x30, 2)
	f32_cpy_sector = StructField(b2int, 0x32, 2)
	f32_various = StructField(b2str, 0x34, 12)

	@property
	def _moving(self):
		return self._mmap[0x40 if self.is_fat32 else 0x24:][:26]

	def phys_dl(self):
		"0x040:+1"
		return hexint(b2int(self._moving[0x0:0x1]))

	@property
	def ext_boot_sig(self):
		"0x042:+1"
		return hexint(b2int(self._moving[0x2:0x3]))

	@property
	def volume_id(self):
		"0x043:+4"
		return hexint(b2int(self._moving[0x3:0x7]))

	@property
	def volume_label(self):
		"0x047:+11"
		return b2str(self._moving[0x7:0x12])

	@property
	def fs_type(self):
		"0x052:+8"
		return b2str(self._moving[0x12:0x1a])

	boot_magic = StructField(b2hex, 0x1fe, 2)

	# helpers

	@property
	def bytes_per_cluster(self):
		return self.bytes_per_sector*self.sectors_per_cluster

	@property
	def valid_fat(self):
		return self.ext_boot_sig == 0x29 and self.boot_magic == 0xaa55

	@property
	def is_fat12(self):
		return self.total_clusters < FAT12.damaged&~0xf and self.legacy_maxroots != 0

	@property
	def is_fat16(self):
		return (FAT12.damaged&~0xf <= self.total_clusters or self.fs_type
		        == 'FAT16') and self.total_clusters < FAT16.damaged&~0xf \
		       and self.legacy_maxroots != 0

	@property
	def is_fat32(self):
		return FAT16.damaged&~0xf <= self.total_clusters or self.legacy_maxroots == 0

	@property
	def total_clusters(self):
		return self.total_sectors // (self.sectors_per_cluster or 1)

	@property
	def datareg_start_sectors(self):
		return self.reserved_sectors + self.fats * self.sectors_per_fat + -((-FATDir.entrysize*self.legacy_maxroots)//(self.bytes_per_sector or 512))

	@property
	def datareg_start(self):
		return hexint(self.bytes_per_sector * self.datareg_start_sectors)

class mmap_wrapper_v(mmap.mmap, _pyio.BufferedIOBase):
	pass

class mmap_wrapper(mmap_wrapper_v):
	def __new__(cls, fileno, length, *a, offset=0, **kw):
		slip = offset & (mmap.PAGESIZE-1)
		if slip == 0:
			return mmap_wrapper_v(fileno, length, *a, offset=offset, **kw)
		m = mmap.mmap.__new__(cls, fileno, length+slip, *a, offset=offset&-mmap.PAGESIZE, **kw)
		m._slip = slip
		m.seek(0)
		return m

	def __len__(self):
		return super().__len__() - self._slip

	def __getitem__(self, i):
		if isinstance(i, slice):
			a, b, c = i.indices(len(self))
			i = slice(a + self._slip, b + self._slip, c)
		else:
			i += self._slip
		return super().__getitem__(i)

	def tell(self):
		return super().tell() - self._slip

	def seek(self, pos, whence=0):
		if whence == 0:
			pos += self._slip
		if (whence == 2 and pos < -len(self)) or (whence == 1 and pos + self.tell() < 0):
			pos -= self._slip
		return super().seek(pos, whence)

class FSI(metaclass=Struct):
	def __init__(self, fat):
		sect_num = fat.bpb.f32_fsi_sector
		sect_size = fat.bpb.bytes_per_sector
		self._mmap = mmap_wrapper(fat.fp.fileno(), sect_size, prot=mmap.PROT_READ, offset=sect_num*sect_size)

	fsi_sig = StructField(b2str, 0x0, 4)
	fsi_sig2 = StructField(b2str, 0x1e4, 4)
	free_clusters = StructField(b2int, 0x1e8, 4)
	latest_cluster = StructField(b2int, 0x1ec, 4)
	boot_magic = StructField(b2hex, 0x1fc, 4)

	@property
	def valid_fsi(self):
		return self.fsi_sig == "RRaA" and self.fsi_sig2 == "rrAa" and self.boot_magic == 0xaa550000

class FAT:
	damaged = 0xffffff7
	def __init__(self, fat, idx):
		bps = fat.bpb.bytes_per_sector
		spf = fat.bpb.sectors_per_fat
		self._mmap = mmap_wrapper(fat.fp.fileno(), bps * spf, prot=mmap.PROT_READ, offset=bps * (fat.bpb.reserved_sectors + idx*spf))
		self._bpb = fat.bpb
		self._fp = fat.fp
		self._part = weakref.ref(fat)

	def mmap_chain(self, start, recover=False):
		lastw = start
		w = -1
		ite = self.get_chain(start, True)
		if recover and self.get_next(start) == 0:
			ite = range(start+1, start+recover)
			print(ite[:])
		for w in ite:
			if w-lastw != 1 or ((self._bpb.datareg_start+self._bpb.bytes_per_cluster*(w-2)) & (mmap.PAGESIZE - 1)) == 0:
				yield mmap_wrapper(self._fp.fileno(), self._bpb.bytes_per_cluster*(lastw-start+1), prot=mmap.PROT_READ, offset=self._bpb.datareg_start+self._bpb.bytes_per_cluster*(start-2))
				start = w
			lastw = w
		if self.get_next(start) != 0 or recover:
			yield mmap_wrapper(self._fp.fileno(), self._bpb.bytes_per_cluster*(lastw-start+1), prot=mmap.PROT_READ, offset=self._bpb.datareg_start+self._bpb.bytes_per_cluster*(start-2))

	@property
	def medium_type(self):
		"0x000:+1"
		return hexint(self.get_next(0) & 0xff)

	@property
	def valid_fat(self):
		return (self.medium_type == self._bpb.medium_type
		        and self.get_next(0) & ~0xff == self.damaged & ~0xff
		        and self.get_next(1) > self.damaged)

	def get_chain(self, start, skip_first=False):
		if self.get_next(start) == 0:
			return
		if not skip_first:
			yield start
		while True:
			nxt = self.get_next(start)
			if nxt >= self.damaged & ~0xf:
				break
			yield nxt
			start = nxt

	def get_next(self, i):
		if i <= 0 and i == self._bpb.root_dir_clust:
			return self.damaged
		f = self.damaged.bit_length()+4>>3
		assert f&-f == f, self.damaged
		try:
			return b2int(self._mmap[f*i:f*i+f])
		except KeyError:
			print("Problem with i=%#x" % (i,))
			raise

	def dump0(self):
		print("DUMP0")
		for i in range(len(self._mmap)//(self.damaged.bit_length()>>3)):
			j = self.get_next(i)
			if j:
				print(i, j)

	def dump(self):
		print("DUMP")
		s = set()
		sta = 0
		fes = {fe for *_, fe, _ in self._part().rootdir.scandir(recover=True)}
		for i in range(len(self._mmap)//(self.damaged.bit_length()>>3)):
			if i in s:
				continue
			indi = False
			if self.get_next(i) != 0 and i not in fes:
				print("CHAIN \x1b[35m%#x\x1b[m"%i)
			if self.get_next(i) == 0:
				te = FATFile(self._part(), i, 512, recover=True).read().strip(b'\0')
				if te and te != b'\xf6'*512:
					print("\x1b[31m%#x\x1b[m"%i, te)
			for c in self.get_chain(i):
				if not indi:
					indi = True
					print("CHAIN")
				cs = "%#x"%c
				if FATFile(self._part(), c, 512, recover=True).read().strip(b'\0'):
					cs = '\x1b[32m' + cs + '\x1b[m'
				print(cs, end=" ")
				if c in s:
					print("-> *")
					break
				s.add(c)
			if indi:
				print("")

class FAT12(FAT):
	damaged = 0xff7
	def get_next(self, i):
		if i <= 0 and i == self._bpb.root_dir_clust:
			return self.damaged
		start = 3*(i>>1)
		try:
			x = b2int(self._mmap[start:start+3]+b'\0')
		except KeyError:
			print("Problem with i=%#x" % (i,))
			raise
		#print("%d -> %d"%(i, (x >> ((i&1)*12)) & 0xfff))
		return (x >> ((i&1)*12)) & 0xfff

class FAT16(FAT):
	damaged = 0xfff7

class FATFile(io.RawIOBase):
	def __init__(self, fat, idx, size=0, name="", recover=False):
		self._fat = fat.fats[0]
		self._bpb = fat.bpb
		self._start = idx
		self._size = size
		self.name = name
		self._reset(recover=recover)

	def _reset(self, recover=False):
		self._chain = self._fat.mmap_chain(self._start, recover=recover and (-((-self._size)//self._bpb.bytes_per_cluster) or recover))
		try:
			self._mmap = next(self._chain)
		except StopIteration:
			self._mmap = EmptyMmap()
			raise
		self._midx = 0

	def advance_mmap(self):
		le = len(self._mmap) // self._bpb.bytes_per_cluster
		try:
			self._mmap = next(self._chain)
		except StopIteration:
			return False
		self._midx += le
		return True

	def scandir(self, *a, **k):
		raise IOError(errno.ENOTDIR, os.strerror(errno.ENOTDIR), self.name)

	path_r = scandir

	def path(self, p, **k):
		ret = self.path_r(p, **k)
		if ret is None:
			raise IOError(errno.ENOENT, os.strerror(errno.ENOENT), self.name+'/'+p)
		return ret

	def read(self, *a):
		if a:
			return super().read(*a)
		return super().read(self._size)

	def readinto(self, b):
		if not isinstance(b, memoryview):
			b = memoryview(b)
		b = b.cast('B')

		here = self.tell()
		n = self._mmap.readinto(b)
		if n == len(b):
			#print("read(%d @ %d) -> ==%d" %(len(b), here, n))
			return n
		if self._mmap.tell() == len(self._mmap):
			if self.advance_mmap():
				#print("read(%d @ %d) -> %d+" %(len(b), here, n))
				n += self.readinto(b[n:])
		#print("read(%d @ %d) -> %d" %(len(b), here, n))
		return n

	def readable(self):
		return True

	def seek(self, pos, whence=0):
		if whence == 1:
			pos += self._mmap.tell() + self._bpb.bytes_per_cluster*self._midx
		elif whence == 2:
			pos += self._size
		if pos < 0:
			midx = off = 0
		else:
			midx, off = divmod(pos, self._bpb.bytes_per_cluster)
		if midx < self._midx:
			self._reset()
		while midx >= self._midx + len(self._mmap) // self._bpb.bytes_per_cluster:
			if not self.advance_mmap():
				self._mmap.seek(0, 2)
				return self.tell()
		self._mmap.seek(off + (midx - self._midx) * self._bpb.bytes_per_cluster)
		return self.tell()

	def tell(self):
		return self._midx * self._bpb.bytes_per_cluster + self._mmap.tell()

class fatdate(int):
	# TODO: constructing
	def __repr__(self):
		return "%d-%02d-%02d" % (1980+((self&0xfe00)>>9), (self&0x01e0)>>5, self&0x001f)

class fattime(int):
	# TODO: constructing
	def __repr__(self):
		s = "%02d:%02d:%02d" % ((self&0xf800)>>11, (self&0x07e0)>>5, ((self&0x001f)<<1)+(self&0xff0000)//100)
		if self > 0xffff:
			s += ".%02d" % (((self&0xff0000)>>16)%100)
		return s

class FATDir(FATFile):
	entrysize = 32
	def __init__(self, fat, idx, size=0, name="", recover=False):
		super().__init__(fat, idx, size, name=name, recover=recover)
		self._part = weakref.ref(fat)

	def scandir(self, lfns=True, hidden=True, recover=False):
		"""scandir() -> generator

		WARNING: do not create several generators simultaneously!
		The previously created ones get reset!
		"""
		self.seek(0)
		lfn = {}
		while True:
			x = self.read(self.entrysize)
			if not x:
				break

			sq = x[0]
			deleted = False
			if sq == 0x05:
				x = b'\xe5' + x[1:]
			elif sq == 0xe5:
				if not recover:
					continue
				deleted = True
				x = b'\x05' + x[1:]
			elif sq == 0x00:
				if not recover:
					break
				deleted = True

			if not any(x):
				continue

			name = b2str(x[:0x8])
			ext = b2str(x[0x8:0xb])

			attrs = fattrs(b2int(x[0xb:0xc]))

			# deleted first char (or user attrs)
			help1 = b2int(x[0xc:0xd])
			if lfns:
				if help1 & 0x8:
					name = name.lower()
				if help1 & 0x10:
					ext = ext.lower()

			# fine time (or deleted first char)
			help2 = b2int(x[0xd:0xe])

			# also password hash
			ctime = fattime(b2int(x[0xe:0x10]) )# + (help2 << 16))

			# also record size
			cdate = fatdate(b2int(x[0x10:0x12]))

			# also owner ID
			adate = fatdate(b2int(x[0x12:0x14]))

			# also access rights mask
			feh = hexint(b2int(x[0x14:0x16]))

			mtime = fattime(b2int(x[0x16:0x18]))
			mdate = fatdate(b2int(x[0x18:0x1a]))

			fe = b2int(x[-6:-4]) + (feh << 16)
			size = b2int(x[-4:])

			if lfns:
				if attrs == 0xF and help1 == 0 and fe & 0xffff == 0: # VFAT LFN
					name_chunk = x[0x1:0xb]+x[0xe:0x1a]+x[-4:]
					if deleted:
						if help2 not in lfn:
							lfn[help2] = []
						lfn[help2].insert(0, name_chunk)
					else:
						if sq & 0x40: # beginning of the entry
							if help2 in lfn:
								print("Conflicting LFNs? %r" % (lfn[help2]), file=sys.stderr)
							lfn[help2] = [b'']*(sq&0x1f)
						lfn[help2][(sq & 0x1f)-1] = name_chunk
					continue

				firstls = {sq}
				if deleted:
					gener = (b''.join(x).decode('utf16').strip().upper()
					            .split('\0', 1)[0].encode('ascii', 'ignore')
					            .decode('ascii').rsplit('.', 1)
					            for x in lfn.values())
					firstls = {ord(y[0][0]) for y in gener if y[1]==ext or len(ext) != 3}
					if 0x20 <= help1 <= 0x60 or 0x7a < help1 < 0x7f:
						firstls.add(help1)
					print("Possible first letters: %r"%(firstls,), file=sys.stderr)
					if not firstls:
						firstls = {ord('_')}
				for firstl in firstls:
					# SOURCE: https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system#VFAT
					cksum = 0
					for c in (firstl,) + tuple(x[1:0xb]):
						cksum = (((cksum&1)<<7) + (cksum>>1) + c)&0xff
					if cksum in lfn: break

				if cksum in lfn:
					xx = lfn.pop(cksum)
					name, *junk = b''.join(xx).decode('utf16').split('\0', 1)
					if len(junk) == 1 and junk[0].strip('\uffff'):
						print("Non-standard lfn stuff: %r" % (xx,))
					if not name:
						print("Corrupted lfn! %r" % (xx,), file=sys.stderr)
					
					if name[-1] == '.' or '.' not in name:
						ext = ''
					else:
						name, ext = name.rsplit('.', 1)

			if not hidden and attrs & fattrs.hidden:
				continue

			yield name, ext, attrs, (ctime, cdate, adate, mtime, mdate), fe, size
		if lfn:
			print("Unused lfn records: %r" % (lfn,))

	def path_r(self, p, lfns=True, recover=False):
		try:
			px = int(p)
		except ValueError: pass
		else:
			return FATFile(self._part(), px, 0, name=p, recover=recover)

		p = p.lstrip("/")
		if not p: return self
		p = p.split("/", 1)
		if len(p) == 1:
			p, = p
			fin = None
		else:
			p, fin = p

		for name, ext, fl, modif, fe, size in self.scandir(lfns=lfns, recover=recover): # NOTE: resetting other
			name += ("." + ext if ext else "")
			if name[recover:] == p[recover:]:
				cl = FATFile
				if fl & fattrs.subdirectory:
					cl = FATDir
				fe = cl(self._part(), fe, size, name=self.name+'/'+p, recover=recover)
				if fin is not None:
					return fe.path_r(fin)
				return fe

	def listdir(self, **k):
		return [name + ("." + ext if ext else "") for name, ext, *_ in self.scandir(**k)]


class FATPART:
	def __init__(self, fp):
		self.fp = fp
		self.bpb = BPB(self)
		self.fsi = None
		self.cpy = None
		self.fats = []
		self.tree = None
		self.bpb_bak = BPB(self, 512*6)
		if not self.bpb_bak._mmap[:].strip(b'\0'):
			self.bpb_bak = None

		self.load_parts()

	def load_parts(self):
		if self.bpb.valid_fat or self.bpb.legacy_maxroots != 0:
			if self.bpb.is_fat32:
				self.fsi = FSI(self)
				self.bpb_bak = BPB(self, self.bpb.bytes_per_sector * self.bpb.f32_cpy_sector)
			for i in range(self.bpb.fats):
				self.fats.append((FAT if self.bpb.is_fat32 else FAT16 if self.bpb.is_fat16 else FAT12)(self, i))
			self.rootdir = FATDir(self, self.bpb.root_dir_clust)
		elif self.bpb_bak.valid_fat:
			print("Backup BPB seems valid")

def print_properties(obj):
	L = []
	for k, v in obj.__class__.__dict__.items():
		if not k.startswith("_") and isinstance(v, property):
			L.append("{:10}{:20}: {!r}".format(str(v.__doc__), k, getattr(obj, k)))
	print("\n".join(sorted(L)))

def print_bpb(fat, **k):
	print("BPB copy...", end=" ")
	if fat.bpb_bak and fat.bpb._mmap[:] != fat.bpb_bak._mmap[:]:
		print("differs:")
		print_properties(fat.bpb_bak)
		print("\nOriginal BPB:")
	elif fat.bpb_bak:
		print("OK")
	else:
		print("Absent")
	print_properties(fat.bpb)

def print_fsi(fat, **k):
	print_properties(fat.fsi)

def get_fat(fat, **k):
	for fa in fat.fats:
		fa.dump()

def cat(fat, pth="", lfns=True, recover=False, **k):
	f = fat.rootdir.path(pth, lfns=lfns, recover=recover)
	if f._size:
		sys.stdout.buffer.write(f.read())
	elif f._start or f is fat.rootdir:
		print("The file looks empty. But its cluster is nonzero.", file=sys.stderr)
		sys.stdout.buffer.write(f.read(-1))

def ls(fat, pth="", hidden=False, lfns=True, recover=False):
	direc = fat.rootdir.path(pth)
	for name, ext, fl, modif, fe, size in direc.scandir(hidden=hidden, lfns=lfns, recover=recover):
		print("{!r:16}|{:8}|{:3}|{!r}|{:08x}|{:d}".format(fl, repr(name.encode('utf-8', 'surrogateescape')), repr(ext.encode('utf-8', 'surrogateescape')), modif, fe, size))

acts = {"print_bpb": print_bpb, "print_fsi": print_fsi, "cat": cat, "ls": ls, "get_fat": get_fat}

def main():
	par = argparse.ArgumentParser()
	par.add_argument("--no-lfns", dest="lfns", action="store_false")
	par.add_argument("--hidden", dest="hidden", action="store_true")
	par.add_argument("--recover", action="store_true")
	par.add_argument("action", choices=acts.keys())
	par.add_argument("partition", type=argparse.FileType('rb'))
	par.add_argument("path", nargs="?")
	arg = par.parse_args()

	act = acts[arg.action]
	with arg.partition as fp:
		a = arg.path and (arg.path,) or ()
		act(FATPART(fp), *a,
		    lfns=arg.lfns, recover=arg.recover, hidden=arg.hidden)

if __name__ == "__main__":
	main()
