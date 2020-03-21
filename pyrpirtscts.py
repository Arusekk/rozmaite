#!/usr/bin/env python3

import mmap
import os
import struct

pi2_base = 0x3F000000
gpio_offset = 0x200000
gpio_base = pi2_base + gpio_offset
gpfsel1_byte3 = 4 + 2
gpio1617_mask = 0xfc

try:
    fp = open('/proc/device-tree/soc/ranges', 'rb')
except FileNotFoundError:
    pass
else:
    with fp:
        fp.seek(4)
        try:
            address, = struct.unpack('!I', fp.read(4))
        except struct.error:
            pass
        else:
            if address != 0xffffffff:
                gpio_base = address + gpio_offset

fd = os.open('/dev/mem', os.O_RDWR|os.O_SYNC)
gpio_map = mmap.mmap(fd, mmap.PAGESIZE, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, mmap.ACCESS_READ|mmap.ACCESS_WRITE, gpio_base)

gpio_map[gpfsel1_byte3] |= gpio1617_mask

gpio_map.close()
os.close(fd)
