#!/usr/bin/python
import sys, os, glob, shutil, numpy
from subprocess import call
from collections import defaultdict

sys.path.append('/path/to/python/netcdf4/module')

from netCDF4 import *
from netCDF4 import Dataset as NetCDFFile
from pylab import *

from optparse import OptionParser

def rms(field):
	try:
		f1 = NetCDFFile('1proc.1block.nc','r')
	except:
		return float('NaN')

	try:
		f2 = NetCDFFile('2proc.2block.nc','r')
	except:
		return float('NaN')

	nCells = len(f1.dimensions['nCells'])
	nEdges = len(f1.dimensions['nEdges'])
	nVertices = len(f1.dimensions['nVertices'])
	vert_levs = len(f1.dimensions['nVertLevels'])

	times = f1.variables['xtime']
	dcedge = f1.variables['dcEdge']

	field1 = f1.variables[field][:]
	field2 = f2.variables[field][:]

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

	for t in range( time_length-1, time_length):
		diff = field1_reshaped[t,:] - field2_reshaped[t,:]
		diff = diff * diff
		rms = sum(diff)
		rms = rms/(second_dim)
		rms = math.sqrt(rms)

	return rms

namelist_groups = defaultdict(list)
explored_parameters = defaultdict(list)
default_parameters = defaultdict(list)
group_order = list()

execfile("group_order.py")
execfile("parameter_groups.py")
execfile("default_parameters.py")
execfile("explored_parameters.py")

results = open('results.out','w+')

for param in explored_parameters:
	for value in explored_parameters[param]:
		print 'EXPLORING PARAMETER: ', param, value
		filename = 'namelist.input'
		f = open(filename, 'w+')
		for i in group_order:
			added = 0
			for j in namelist_groups[i]:
				if(j == param):
					if(added == 0):
						output = '&%s\n'%(i)
						f.write(output)
						added = 1

					output = '\t%s = %s\n'%(param,value)
					f.write(output)

				elif(len(default_parameters[j]) > 0):
					if(added == 0):
						output = '&%s\n'%(i)
						f.write(output)
						added = 1

					output = '\t%s = '%(j)
					f.write(output)
					for k in default_parameters[j]:
						f.write(k)
					f.write('\n')
			if(added == 1):
				f.write('/\n')
		f.close()
		call("mpirun -n 1 ./ocean_model.exe 1> /dev/null 2> /dev/null", shell=True)
		call("mv output.0000-01-01_00.00.00.nc 1proc.1block.nc 1> /dev/null 2> /dev/null", shell=True)
		call("mpirun -n 2 ./ocean_model.exe 1> /dev/null 2> /dev/null", shell=True)
		call("mv output.0000-01-01_00.00.00.nc 2proc.2block.nc 1> /dev/null 2> /dev/null", shell=True)
		
		t_rms = rms('temperature')
		u_rms = rms('u')
		if(t_rms < 1e-12 and u_rms < 1e-12):
			output = " [PASS]\t***\t%e %e\t***\t%s = %s\n"%(u_rms, t_rms, param, value)
		else:
			output = " [FAIL]\t***\t%e %e\t***\t%s = %s\n"%(u_rms, t_rms, param, value)
		results.write(output)

		call("rm 1proc.1block.nc 1> /dev/null 2> /dev/null", shell=True)
		call("rm 2proc.2block.nc 1> /dev/null 2> /dev/null", shell=True)

results.close()

