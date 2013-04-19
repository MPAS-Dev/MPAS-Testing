#!/usr/bin/python
import sys, os, glob, shutil, numpy

sys.path.append('/home/douglasj/softwares/python/lib/python2.7/site-packages')

from netCDF4 import *
from netCDF4 import Dataset as NetCDFFile
from pylab import *

from optparse import OptionParser

parser = OptionParser()
parser.add_option("-1", "--file1", dest="filename1", help="first input file", metavar="FILE")
parser.add_option("-2", "--file2", dest="filename2", help="second input file", metavar="FILE")
parser.add_option("-v", "--var", dest="variable", help="variable to compute error with", metavar="VAR")

options, args = parser.parse_args()

if not options.filename1:
	parser.error("Two filenames are required inputs.")

if not options.filename2:
	parser.error("Two filenames are required inputs.")

if not options.variable:
	parser.error("Variable is a required input.")

f1 = NetCDFFile(options.filename1,'r')
f2 = NetCDFFile(options.filename2,'r')

nCells = len(f1.dimensions['nCells'])
nEdges = len(f1.dimensions['nEdges'])
nVertices = len(f1.dimensions['nVertices'])
vert_levs = len(f1.dimensions['nVertLevels'])

times = f1.variables['xtime']
dcedge = f1.variables['dcEdge']

field1 = f1.variables[options.variable][:]
field2 = f2.variables[options.variable][:]

junk = dcedge[:]
resolution = junk.max()

del dcedge
del junk

time_length = times.shape[0]

field_size = size(field1)

if field_size == nCells * vert_levs * time_length:
	second_dim = nCells * vert_levs

elif field_size == nEdges * vert_levs * time_length:
	second_dim = nEdges * vert_levs

elif field_size == nVertices * vert_levs * time_length:
	second_dim = nVertices * vert_levs

else:
	print "Field doesn't have the right dimensions. Quitting."
	quit()

field1_reshaped = field1.reshape(time_length, second_dim)
field2_reshaped = field2.reshape(time_length, second_dim)

for t in range( 0, time_length):
	diff = field1_reshaped[t,:] - field2_reshaped[t,:]
	diff = diff * diff
	rms = sum(diff)
	rms = rms/(second_dim)
	rms = math.sqrt(rms)

	print t, rms
	del rms
	del diff
