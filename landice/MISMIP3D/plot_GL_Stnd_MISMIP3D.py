#!/usr/bin/env python
import numpy as np
import netCDF4
import datetime
# import math
# from pylab import *
from optparse import OptionParser
import matplotlib.pyplot as plt
# from matplotlib.contour import QuadContourSet
# import time

GLbit = 256
secInYr = 3600.0 * 24.0 * 365.0  # Note: this may be slightly wrong for some calendar types!

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="file to visualize", metavar="FILE")
parser.add_option("-t", "--time", dest="time", help="time step to visualize (0 based)", metavar="TIME")
parser.add_option("-s", "--save", action="store_true", dest="saveimages", help="include this flag to save plots as files")
parser.add_option("-n", "--nodisp", action="store_true", dest="hidefigs", help="include this flag to not display plots (usually used with -s)")
# parser.add_option("-v", "--var", dest="variable", help="variable to visualize", metavar="VAR")
# parser.add_option("--max", dest="maximum", help="maximum for color bar", metavar="MAX")
# parser.add_option("--min", dest="minimum", help="minimum for color bar", metavar="MIN")

options, args = parser.parse_args()

if not options.filename:
	print "No filename provided. Using output.nc."
        options.filename = "output.nc"

if not options.time:
	print "No time provided. Using time 0."
        time_slice = 0
else:
        time_slice = int(options.time)

#if not options.variable:
#	parser.error("Variable is a required input.")

# if not options.maximum:
#      	color_max = 0.0
# else:
# 	color_max = float(options.maximum)

# if not options.minimum:
# 	color_min = 0.0
# else:
# 	color_min = float(options.minimum)

################### DEFINE FUNCTIONS ######################
def xtime2numtime(xtime):
  """Define a function to convert xtime character array to numeric time values using datetime objects"""
  # First parse the xtime character array into a string 
  xtimestr = netCDF4.chartostring(xtime) # convert from the character array to an array of strings using the netCDF4 module's function

  dt = []
  for stritem in xtimestr:
      itemarray = stritem.strip().replace('_', '-').replace(':', '-').split('-')  # Get an array of strings that are Y,M,D,h,m,s
      results = [int(i) for i in itemarray]
      if (results[0] < 1900):  # datetime has a bug where years less than 1900 are invalid on some systems
         results[0] += 1900
      dt.append( datetime.datetime(*results) ) # * notation passes in the array as arguments

  numtime = netCDF4.date2num(dt, units='seconds since '+str(dt[0]))   # use the netCDF4 module's function for converting a datetime to a time number
  numtime /= (3600.0 * 24.0 * 365.0)
  numtime -= numtime[0]  # return years from start
  return numtime

def xtimeGetYear(xtime):
  """Get an array of years from an xtime array, ignoring any partial year information"""
  # First parse the xtime character array into a string 
  xtimestr = netCDF4.chartostring(xtime) # convert from the character array to an array of strings using the netCDF4 module's function
  years = np.zeros( (len(xtimestr),) )
  for i in range(len(xtimestr)):
      years[i] = ( int(xtimestr[i].split('-')[0]) ) # Get the year part and make it an integer
  return years



# These are only needed if gridding.
# nx = 30
# ny = 35



f = netCDF4.Dataset(options.filename,'r')

xtime = f.variables['xtime'][:]
#years = xtime2numtime(xtime)
years = xtimeGetYear(xtime)
#thickness = f.variables['thickness'][time_slice,:]
#dcedge = f.variables['dcEdge'][:]
#bedTopography = f.variables['bedTopography']  # not needed
#xCell = f.variables['xCell'][:]
#yCell = f.variables['yCell'][:]
xEdge = f.variables['xEdge'][:]
yEdge = f.variables['yEdge'][:]
#angleEdge = f.variables['angleEdge'][:]
#lowerSurface = f.variables['lowerSurface'][time_slice,:]
#upperSurface = f.variables['upperSurface'][time_slice,:]
#surfaceSpeed = f.variables['surfaceSpeed'][time_slice,:]
#basalSpeed = f.variables['basalSpeed'][time_slice,:]
#floatingEdges = f.variables['floatingEdges'][time_slice,:]
edgeMask = f.variables['edgeMask']  # just get the object
#normalVelocity = f.variables['normalVelocity']
#uReconstructX = f.variables['uReconstructX']
#uReconstructX = f.variables['uReconstructX']
#uReconstructY = f.variables['uReconstructY']

vert_levs = len(f.dimensions['nVertLevels'])
nt = len(f.dimensions['Time'])

# print "nx = ", nx, " ny = ", ny
print "vert_levs = ", vert_levs, " time_length = ", nt


# print "Computing global max and min"
# junk = thickness[:,:,0]
# maxval = junk.max()
# minval = junk.min()
# 
# del junk
# 
# junk = thickness[:,:]
# global_max = junk.max()
# global_min = junk.min()


#var_slice = thickness[time_slice,:]
## var_slice = var_slice.reshape(time_length, ny, nx)
#
#
## print "Global max = ", global_max, " Global min = ", global_min
## print "Surface max = ", maxval, " Surface min = ", minval
#
#fig = plt.figure(1, facecolor='w')
#ax = fig.add_subplot(111, aspect='equal')
## C = plt.contourf(xCell, yCell, var_slice )
#plt.scatter(xCell[:], yCell[:], 80, var_slice, marker='h', edgecolors='none')
#plt.colorbar()
#plt.title('thickness at time ' + str(time_slice) )
#plt.draw()
#if options.saveimages:
#        print "Saving figures to files."
#        plt.savefig('dome_thickness.png')

fig = plt.figure(1, facecolor='w')
ax = fig.add_subplot(111)
# Calculate GL position
GLpos = np.zeros((nt,3))  # min, mean, max
for t in range(nt):
    GLind = np.nonzero( np.logical_and( ( (edgeMask[t,:] & GLbit) / GLbit == 1), (xEdge > 0.0) ) )
    #print 'Time, GL position values', years[t], xEdge[GLind]
    GLpos[t,0] = xEdge[GLind].min() / 1000.0
    GLpos[t,1] = xEdge[GLind].mean() / 1000.0
    GLpos[t,2] = xEdge[GLind].max() / 1000.0
plt.plot(years, GLpos[:,0], ':b')
plt.plot(years, GLpos[:,1], '-bo')
plt.plot(years, GLpos[:,2], ':b')
plt.xlabel('Time (yrs from start)')
plt.ylabel('GL position (km)')
plt.title('GL position over time')
plt.draw()
if options.saveimages:
        print "Saving figures to files."
        plt.savefig('GL-position.png')




if options.hidefigs:
     print "Plot display disabled with -n argument."
else:     
     plt.show()

f.close()

