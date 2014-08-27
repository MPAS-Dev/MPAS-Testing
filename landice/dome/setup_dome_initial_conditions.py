#!/usr/bin/python
# Generate initial conditions for dome land ice test case

import sys, numpy
try:
  from Scientific.IO.NetCDF import NetCDFFile
  netCDF_module = 'Scientific.IO.NetCDF'
except ImportError:
  try:
    from netCDF4 import Dataset as NetCDFFile
    netCDF_module = 'netCDF4'
  except ImportError:
      print 'Unable to import any of the following python modules:'
      print '  Scientific.IO.NetCDF \n  netcdf4 '
      print 'One of them must be installed.'
      raise ImportError('No netCDF module found')
from math import sqrt

# Parse options
from optparse import OptionParser
parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", type='string', help="file to setup dome", metavar="FILE")
parser.add_option("-d", "--dome", dest="dometype", type='choice', choices=('halfar', 'cism'), help="type of dome to setup: 'halfar' or 'cism'", metavar="TYPE")
options, args = parser.parse_args()
if options.dometype:
   if options.dometype == 'cism' or options.dometype == 'halfar':
      print 'Setting up the dome type: ' + options.dometype
   else:
      print "Error: Invalid dome type specified.  Valid types are 'halfar' or 'cism'."
      sys.exit
else:
   options.dometype='halfar'
   print 'No dome type specified.  Setting up the Halfar dome by default.'
if not options.filename:
   options.filename = 'landice_grid.nc'
   print 'No file specified.  Attempting to use landice_grid.nc'


# Open the file, get needed dimensions
try:
    gridfile = NetCDFFile(options.filename,'r+')
    if (netCDF_module == 'Scientific.IO.NetCDF'):
         nVertLevels = gridfile.dimensions['nVertLevels']
    else:
         nVertLevels = len(gridfile.dimensions['nVertLevels'])
    if nVertLevels != 9:
         print 'nVerLevels in the supplied file was ', nVertLevels, '.  Were you expecting 9?'
    # Get variables
    xCell = gridfile.variables['xCell']
    yCell = gridfile.variables['yCell']
    xEdge = gridfile.variables['xEdge']
    yEdge = gridfile.variables['yEdge']
    xVertex = gridfile.variables['xVertex']
    yVertex = gridfile.variables['yVertex']
    thickness = gridfile.variables['thickness']
    bedTopography = gridfile.variables['bedTopography']
    normalVelocity = gridfile.variables['normalVelocity']
    layerThicknessFractions = gridfile.variables['layerThicknessFractions']
    temperature = gridfile.variables['temperature']
    # Get b.c. variables
    SMB = gridfile.variables['sfcMassBal']
    # These legacy fields are currently not included in the new MPAS   MH 9/19/13 
    #beta = gridfile.variables['betaTimeSeries'][:]
    #SMB = gridfile.variables['sfcMassBalTimeSeries'][:]
    #Tsfc = gridfile.variables['sfcAirTempTimeSeries'][:]
    #G = gridfile.variables['basalHeatFluxTimeSeries'][:]
    #BMB = gridfile.variables['marineBasalMassBalTimeSeries'][:]
except:
    sys.exit('Error: The grid file specified is either missing or lacking needed dimensions/variables.')



# Find center of domain
x0 = xCell[:].min() + 0.5 * (xCell[:].max() - xCell[:].min() )
y0 = yCell[:].min() + 0.5 * (yCell[:].max() - yCell[:].min() )
# Calculate distance of each cell center from dome center
r = ((xCell[:] - x0)**2 + (yCell[:] - y0)**2)**0.5

# Center the dome in the center of the cell that is closest to the center of the domain.
#   NOTE: for some meshes, maybe we don't want to do this - could add command-line argument controlling this later.
putOriginOnACell = True
if putOriginOnACell:
   centerCellIndex = numpy.abs(r[:]).argmin()
   #print x0, y0, centerCellIndex, xCell[centerCellIndex], yCell[centerCellIndex]
   xShift = -1.0 * xCell[centerCellIndex]
   yShift = -1.0 * yCell[centerCellIndex]
   xCell[:] = xCell[:] + xShift
   yCell[:] = yCell[:] + yShift
   xEdge[:] = xEdge[:] + xShift
   yEdge[:] = yEdge[:] + yShift
   xVertex[:] = xVertex[:] + xShift
   yVertex[:] = yVertex[:] + yShift
   # Now update origin location and distance array
   x0 = 0.0
   y0 = 0.0
   r = ((xCell[:] - x0)**2 + (yCell[:] - y0)**2)**0.5

# Assign variable values for dome
# Define dome dimensions - all in meters
r0 = 60000.0 * sqrt(0.125)
h0 = 2000.0 * sqrt(0.125)
# Set default value for non-dome cells
thickness[:] = 0.0
# Calculate the dome thickness for cells within the desired radius (thickness will be NaN otherwise)
thickness_field = thickness[0,:]
if options.dometype == 'cism':
   thickness_field[r<r0] = h0 * (1.0 - (r[r<r0] / r0)**2)**0.5
else:
   # halfar dome
   thickness_field[r<r0] = h0 * (1.0 - (r[r<r0] / r0)**(4.0/3.0))**(3.0/7.0)
thickness[0,:] = thickness_field   

# zero velocity everywhere
normalVelocity[:] = 0.0
# flat bed at sea level
bedTopography[:] = 0.0
# constant, arbitrary temperature, degrees C
temperature[:] = 273.15 
# Setup layerThicknessFractions
layerThicknessFractions[:] = 1.0 / nVertLevels

# boundary conditions
# Sample values to use, or comment these out for them to be 0.
SMB[:] = 0.0
#beta[:] = 50000.
#SMB[:] = 2.0/1000.0 * (thickness[:] + bedTopography[:]) - 1.0  # units: m/yr, lapse rate of 1 m/yr with 0 at 500 m
# Convert from units of m/yr to kg/m2/s using an assumed ice density
SMB[:] = SMB[:] *910.0/(3600.0*24.0*365.0)

#Tsfc[:,0] = -5.0/1000.0 * (thickness[0,:] + bedTopography[0,:]) # lapse rate of 5 deg / km
#G = 0.01
#BMB[:] = -20.0  # units: m/yr


gridfile.close()

print 'Successfully added dome initial conditions to: ', options.filename

