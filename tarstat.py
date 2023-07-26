#!/usr/bin/env python

import argparse
import os
import tarfile

from yt_dlp.utils import format_decimal_suffix


def humansize(s):
    return format_decimal_suffix(s, factor=1024)


def tell(self):
    return self.fileobj.tell()


tarfile._StreamProxy.tell = tell


def tell(f):
    upos = f.tell()
    # f._buffer.raw
    # cpos = f._fp.tell()
    cpos = f.fileobj.fileobj.tell()
    return cpos, upos


par = argparse.ArgumentParser()
par.add_argument('-H', '--human', action='store_const', const=humansize, default=str)
par.add_argument('-x', '--recreate', action='store_true')
par.add_argument('-b', '--block-size', type=int, default=4,
                 help="""Higher goes faster, but loses precision.
                         My timings for linux-6.0.txz:
                          1 = 13.5min
                          4 = 4min
                          16 = 1min
                          64 = 30s
                          256+ = 20s
                      """)
# par.add_argument('ifile', type=tarfile.TarFile.open)
par.add_argument('ifile', type=argparse.FileType('rb'))

arg = par.parse_args()

tar = tarfile.open(None, 'r|*', arg.ifile, arg.block_size)

cpos = upos = 0
h = arg.human
for info in tar:
    cdata, udata = tell(tar.fileobj)

    if tar.fileobj.tell() != tar.offset:
        tar.fileobj.seek(tar.offset - 1)
        tar.fileobj.read(1)

    cend, uend = tell(tar.fileobj)

    cmeta = cdata - cpos
    csize = cend - cdata

    umeta = udata - upos
    usize = uend - udata

    print(f'{h(cmeta + csize)} {h(umeta + usize)} {info.name}')
    if arg.recreate:
        if info.isdir():
            os.makedirs(info.name, exist_ok=True)
        else:
            with open(info.name, 'wb', 0) as fp:
                fp.write(b'a' * (cmeta + csize))
    upos, cpos = uend, cend
