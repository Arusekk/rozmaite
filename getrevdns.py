#!/usr/bin/env python3

import argparse
import re
import socket

class Zone:
    __slots__ = ["parts", "bits"]
    def __init__(self, addr, d=None):
        try:
            if d is None:
                addr, d = addr.rsplit("/", 1)
            self.bits = int(d)
            a1,a2,a3,a4 = map(int, addr.split("."))
            self.parts = a1,a2,a3,a4
        except ValueError:
            raise self.parseerror()
    @property
    def addr(self):
        return "%d.%d.%d.%d" % self.parts
    @property
    def nextaddr(self):
        parts = list(self.parts)
        parts[self.bits>>3] ^= 1<<(7&~self.bits)
        return "%d.%d.%d.%d" % tuple(parts)
    def __repr__(self):
        return "Zone%r" % ((self.addr, self.bits),)
    def __iter__(self):
        if self.bits >= 32:
            yield self.addr
            return
        yield from Zone(self.addr, self.bits+1)
        yield from Zone(self.nextaddr, self.bits+1)
    @staticmethod
    def parseerror():
        return argparse.ArgumentTypeError("must be N.N.N.N/M, N in 0-255, M in 0-32")

def scanz(z):
    for a in z:
        try:
            b, alias, alt = socket.gethostbyaddr(a)
        except: continue
        if b != a:
            print('\t'.join((a,b)))

if __name__ == "__main__":
    par = argparse.ArgumentParser()
    par.add_argument("addr", nargs="+", help="Example: 192.168.1.0/24", type=Zone)

    arg = par.parse_args()

    for aa in arg.addr:
        scanz(aa)

