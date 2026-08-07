#!/bin/bash
while [ 1 ]; do
	i2cset -f -y 3 0x70 0x20 0x1 b
	sleep 10
done
