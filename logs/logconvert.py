#!/usr/bin/python
#
# logconvert.py converts data from Hotnest datalogger raw file 
# Copyright (C) 2009-2010 by Dmitry Sorokin 
#
# This file is part of Beeduino Project
#
# Beeduino is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 3, or (at your option) any later version.
#
# Beeduino is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the Beeduino Project; see the file COPYING.  If not, see
# <http://www.gnu.org/licenses/>.
#

import sys
import  time
import datetime
from string import split
from optparse import OptionParser

start_str = ""
end_str = ""


op = OptionParser()

op.add_option("-f", "--file", dest="raw_fname", help="File name of a raw datalog file (without extension)")
op.add_option("-s", "--start", dest="start_str", help="Start time in form like 2010-02-20 22:45:23")
op.add_option("-e", "--end", dest="end_str", help="End time in form like 2010-02-21 11:19:06")
op.add_option("-c", "--convert", dest="convert", default=True, help="Convert to file with human readable datetime and sensors values")

options, args = op.parse_args()

if not options.raw_fname:
    op.print_help()
    sys.exit()
else:
    try:
        raw_file = open("%s.RAW" % options.raw_fname)
    except IOError:
        print "Error while opening raw log file %s.RAW" % options.raw_fname
        sys.exit()
    #TODO: add error checking
    legend_file = open("loglegend.txt")
    for l in legend_file.readlines():
        if not l[0]=="#":
            fname,_start,_end = l.split("\t")
            if fname==options.raw_fname:
                start_str = _start
                end_str = _end.rstrip()
                break

if not ((start_str and end_str) or (options.start_str and options.end_str)):
    op.print_help()
    sys.exit()
else:
    pass

tk = 0.0625

interval = 0

starttime_obj = datetime.datetime(*time.strptime(start_str, "%Y-%m-%d %H:%M:%S")[0:6])
start_sec = time.mktime(starttime_obj.timetuple())
end_sec = time.mktime(time.strptime(end_str, "%Y-%m-%d %H:%M:%S"))

host_seconds = end_sec - start_sec

if options.convert:
    out_file = open("%s.TXT" % options.raw_fname, "w")

lines = 0
t01_maxdiff = 0

for l in raw_file.readlines():
    try:
        millis,t0_s,t1_s,t2_s = split(l, ";")
        t0 = int(t0_s)
        t1 = int(t1_s)
        t2 = int(t2_s)

        if lines == 0:
            t0_min = t0_max = t0
            t1_min = t1_max = t1
            t2_min = t2_max = t2
            start_millis = end_millis = millis
        if abs(t0-t1) > t01_maxdiff: t01_maxdiff = abs(t0-t1)    
        if t0 > t0_max: t0_max = t0
        if t0 < t0_min: t0_min = t0
        if t1 > t1_max: t1_max = t1
        if t1 < t1_min: t1_min = t1
        if t2 > t2_max: t2_max = t2
        if t2 < t2_min: t2_min = t2
        lines = lines + 1
        end_millis = millis
        sec_from_start = (int(end_millis) - int(start_millis))/1000
        if options.convert:
            interval = datetime.timedelta(seconds=sec_from_start)
            timestamp_obj = starttime_obj + interval
            timestamp = timestamp_obj.strftime("%Y-%m-%d %H:%M:%S")
            out_line = "%s;%4.2f;%4.2f;%4.2f\n" % (timestamp,t0*tk,t1*tk,t2*tk)
            out_file.write(out_line)
    except ValueError:
        pass        

try:
    raw_file.close()
    out_file.close()
except:
    pass

print "Host time seconds: ", int(host_seconds)

millis = int(end_millis) - int(start_millis)
beeduino_seconds = millis/1000

print "Beeduino time seconds: ", beeduino_seconds

diff = host_seconds - beeduino_seconds

print "Diff: ", int(diff)

print "t0_min: %4.2f(%4.2fC), t0_max: %4.2f(%4.2fC)" % (t0_min,t0_min*tk,t0_max,t0_max*tk)
print "t1_min: %4.2f(%4.2fC), t1_max: %4.2f(%4.2fC)" % (t1_min,t1_min*tk,t1_max,t1_max*tk)
print "t2_min: %4.2f(%4.2fC), t2_max: %4.2f(%4.2fC)" % (t2_min,t2_min*tk,t2_max,t2_max*tk)
print "Max t0-t1 diff: ", t01_maxdiff
print "Total lines: ", lines	
    
        
    
