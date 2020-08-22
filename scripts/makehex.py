#!/usr/bin/env python3
from sys import argv

binfile = argv[1]

with open(binfile, "rb") as f:
    bindata = bytearray(f.read())

# Pad data if necessary
pad_count = 4 - (len(bindata) % 4)
for _ in range(pad_count):
    bindata.append(0)

assert len(bindata) % 4 == 0

for i in range(len(bindata) // 4):
    w = bindata[4*i : 4*i+4]
    print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
