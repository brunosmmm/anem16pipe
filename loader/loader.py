#coding=utf-8

import serial, struct,array, time,sys

serialpath = '/dev/ttyACM0'
serialbaud = 115200

RESETCMD = 0x01
PRGCMD = 0x02
TERM = 0xFF

try:
    serialpath = sys.argv[1]
except:
    print "usage loader.py /path/to/serialport binfile"
    exit(1)

try:
    myfile = sys.argv[2]
    f = open(myfile,'r')
except:
    print "Error opening file!"
    exit(1)


#open serial
ser = serial.Serial(serialpath, serialbaud, timeout=1)

size = 0xFF

buf = array.array('c')

#wipe programming
buf.append(chr(PRGCMD))
buf.append(chr(size))
index = 2

while (size > 0):
    
    buf.append(chr(0x00))
    index = index + 1
    size = size - 1

buf.append(chr(TERM))

#print buf.tostring()

print "erasing..."

if ser.isOpen():
    ser.write(buf.tostring())
else:
    print "error"

#clear buffer
buf = array.array('c')
buf.append(chr(PRGCMD))

time.sleep(0.1)

#write something

#read contents
program = f.readlines()

#size
progsize = len(program)*2
buf.append(chr(progsize))

print "program has %d instr / %d bytes" % (progsize/2,progsize)

for line in program:

    byte1 = int(line,2) >> 8
    byte2 = int(line,2) & 0x00FF

    buf.append(chr(byte1))
    buf.append(chr(byte2))

buf.append(chr(TERM))

print "loading %d bytes" % (len(buf))

if ser.isOpen():
    ser.write(buf.tostring())
    ser.close()
else:
    print "error"

print "finished loading"
