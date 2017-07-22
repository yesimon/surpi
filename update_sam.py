#!/usr/bin/env python
#
#	update_sam.py
#       this script reannotates the SAM file based on the better hit identified in "compare_sam.py"
#
#	Chiu Laboratory
#	University of California, San Francisco
#
# Copyright (C) 2014 Charles Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

import sys
import os

def logHeader():
	import os.path, sys, time
	return "%s\t%s\t" % (time.strftime("%a %b %d %H:%M:%S %Z %Y"), os.path.basename(sys.argv[0]))

usage = "update_sam.py <annotated SAM file> <outputFile>"
if len(sys.argv) != 3:
	print usage
	sys.exit(0)

SAMfile1 = sys.argv[1]
outputFile1 = sys.argv[2]

file1 = open(SAMfile1, "r")
outputFile = open(outputFile1, "w")

line1 = file1.readline()

while line1 != '':
	data1 = line1.split("\t")
	if (data1[0][0]!="@"):
		header = data1[0].split("|")
		if (len(header)>=2): # these is a hit in header
			dvalue=header[1]
			taxids=header[2].split(",")
			edit_distance=int(data1[12].split(":")[2])

			data1[2] = "taxids|" + ",".join(taxids) + "|"
			data1[0] = header[0] 
			if (edit_distance >= 0): # then there is already a hit in the SAM entry
				data1[13] = "NM:i:" + str(dvalue)
			else:
				data1[12] = data1[12] + "\t" + "NM:i:" + str(dvalue)
			outputFile.write("\t".join(data1))
		else:
			outputFile.write(line1)
	else:
		outputFile.write(line1)
	line1 = file1.readline()

file1.close()
outputFile.close()

print "%sRestored file %s in SAM format and copied to %s" % (logHeader(), SAMfile1, outputFile1)
