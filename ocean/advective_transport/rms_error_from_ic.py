#!/usr/bin/python
import sys, os, glob, shutil, numpy

sys.path.append('PATH_TO_NETCDF4')

from netCDF4 import *
from netCDF4 import Dataset as NetCDFFile
from pylab import *

from optparse import OptionParser

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="first input file", metavar="FILE")
parser.add_option("-v", "--var", dest="variable", help="variable to compute error with", metavar="VAR")

options, args = parser.parse_args()

if not options.filename:
	parser.error("Filename is a required input.")

if not options.variable:
	parser.error("Variable is a required input.")

f = NetCDFFile(options.filename,'r')

nCells = len(f.dimensions['nCells'])
nEdges = len(f.dimensions['nEdges'])
nVertices = len(f.dimensions['nVertices'])
vert_levs = len(f.dimensions['nVertLevels'])

times = f.variables['xtime']

field = f.variables[options.variable][:]
dim = f.variables[options.variable].dimensions[1]

time_length = times.shape[0]

field_size = size(field)

if field_size == nCells * vert_levs * time_length:
	second_dim = nCells
	area = f.variables['areaCell'][:]

elif field_size == nEdges * vert_levs * time_length:
	second_dim = nEdges
	area = f.variables['areaEdge'][:]

elif field_size == nVertices * vert_levs * time_length:
	second_dim = nVertices
	area = f.variables['areaTriangle'][:]

else:
	print "Field doesn't have the right dimensions. Quitting."
	quit()

field_reshaped = field.reshape(time_length, second_dim, vert_levs)

for t in range( 0, time_length):
	rms = 0
	for v in range(0, vert_levs):
		diff = field_reshaped[t,:,v] - field_reshaped[0,:,v]
		#diff = diff * diff * area
		diff = diff * diff
		rms = rms + sum(diff)

# 	rms = math.sqrt(rms) / (sum(area) * vert_levs)
 	rms = math.sqrt(rms) / (second_dim * vert_levs)

	print t, rms
	del rms
	del diff
