#!/usr/bin/python
# A script to compare CISM model output to the Halfar analytic solution of the dome test case.
# Matt Hoffman, LANL, September 2013

import sys
import datetime
try:
    import netCDF4
except ImportError:
    print 'Unable to import netCDF4 python modules:'
    sys.exit
from optparse import OptionParser
import numpy as np
import matplotlib.pyplot as plt

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="file to test", metavar="FILE")
parser.add_option("-t", "--time", dest="t", help="which time level to use", metavar="T")

options, args = parser.parse_args()
if not options.filename:
   options.filename = 'output.nc'
   print 'No file specified.  Attempting to use output.nc'
if options.t:
   timelev = int(options.t)
else:
   timelev = -1
   print 'No time level specified.  Attempting to use final time.'

################### DEFINE FUNCTIONS ######################
# Define the function to calculate the Halfar thickness
def halfar(t,x,y, A, n, rho):
  # A   # s^{-1} Pa^{-3}
  # n   # Glen flow law exponent
  # rho # ice density kg m^{-3}

  # These constants should come from setup_dome_initial_conditions.py.
  # For now they are being hardcoded.
  R0 = 60000.0 * np.sqrt(0.125)   # initial dome radius
  H0 = 2000.0 * np.sqrt(0.125)    # initial dome thickness at center
  g = 9.1801  # gravity m/s/s
  alpha = 1.0/9.0
  beta = 1.0/18.0
  secpera = 31556926.0
  Gamma = 2.0 / (n+2.0) * A * (rho * g)**n

  #xmax = max(x)#+(x[1]-x[0])
  #ymax = max(y)#+(y[1]-y[0])
  x0 = xCell.min() + 0.5 * (xCell.max() - xCell.min() )
  y0 = yCell.min() + 0.5 * (yCell.max() - yCell.min() )


  t0 = (beta/Gamma) * (7.0/4.0)**3 * (R0**4/H0**7)  # NOTE: These constants assume n=3 - they need to be generalized to allow other n's 
  t=t+t0
  t=t/t0

  H=np.zeros(len(x))
  for i in range(len(x)):
      r = np.sqrt( (x[i] - x0)**2 + (y[i] - y0)**2)
      r=r/R0
      inside = max(0.0, 1.0 - (r / t**beta)**((n+1.0) / n))

      H[i] = H0 * inside**(n / (2.0*n+1.0)) / t**alpha
  return H

# Define a function to convert xtime character array to numeric time values using datetime objects
def xtime2numtime(xtime):
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
  return numtime

################### END OF FUNCTIONS ######################


# open supplied MPAS output file and get thickness slice needed
filein = netCDF4.Dataset(options.filename,'r')
xCell = filein.variables['xCell'][:]
yCell = filein.variables['yCell'][:]
xtime = filein.variables['xtime'][:]

thk = filein.variables['thickness'][:]
xtime = filein.variables['xtime'][:] 
numtime = xtime2numtime(xtime)

# Find out what the ice density and flowA values for this run were.
print '\nCollecting parameter values from the output file.'
flowA = filein.config_default_flowParamA
print 'Using a flowParamA value of: ' + str(flowA)
flow_n = filein.config_flowLawExponent
print 'Using a flowLawExponent value of: ' + str(flow_n)
if flow_n != 3:
        print 'Error: The Halfar script currently only supports a flow law exponent of 3.'
        sys.exit
rhoi = filein.config_ice_density
print 'Using an ice density value of: ' + str(rhoi)
print ''

# Call the halfar function
thkHalfar = halfar(numtime[timelev]-numtime[0], xCell, yCell, flowA, flow_n, rhoi)

thkDiff = thk[timelev, :] - thkHalfar

# Print some stats about the error
print 'Error statistics for cells modeled to have ice:'
print '* Maximum error is ' + str( thkDiff[ np.where( thk[timelev,:] > 0.0) ].max() )
print '* Minimum error is ' + str( thkDiff[ np.where( thk[timelev,:] > 0.0) ].min() )
print '* Mean error is ' + str( thkDiff[ np.where( thk[timelev,:] > 0.0) ].mean() )
print '* Median error is ' + str( np.median(thkDiff[ np.where( thk[timelev,:] > 0.0) ]) )

# Plot the results
fig = plt.figure(1, facecolor='w')
markersize = 30.0

fig.add_subplot(1,3,1)
plt.scatter(xCell,yCell,markersize,thk[timelev,:], marker='h', edgecolors='none')
plt.colorbar()
plt.axis('equal')
plt.title('Modeled thickness (m) \n at time ' + netCDF4.chartostring(xtime)[timelev].strip() ) 

fig.add_subplot(1,3,2)
plt.scatter(xCell,yCell,markersize,thkHalfar, marker='h', edgecolors='none')
plt.colorbar()
plt.axis('equal')
plt.title('Analytic thickness (m) \n at time ' + netCDF4.chartostring(xtime)[timelev].strip() ) 

fig.add_subplot(1,3,3)
plt.scatter(xCell,yCell,markersize,thkDiff, marker='h', edgecolors='none')
plt.colorbar()
plt.axis('equal')
plt.title('Modeled thickness - Analytic thickness \n at time ' + netCDF4.chartostring(xtime)[timelev].strip() ) 

plt.draw()
plt.show()

