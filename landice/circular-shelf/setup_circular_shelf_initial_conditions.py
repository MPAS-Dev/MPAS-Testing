#!/usr/bin/env python
# This script runs a "Circular Shelf Experiment".

import sys, numpy
from netCDF4 import Dataset
from math import sqrt

# Parse options
from optparse import OptionParser
parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", type='string', help="file in which to setup circular shelf", metavar="FILE")
options, args = parser.parse_args()
if not options.filename:
   options.filename = 'landice_grid.nc'
   print 'No file specified.  Attempting to use landice_grid.nc'


# Open the file, get needed dimensions
try:
    gridfile = Dataset(options.filename,'r+')
    nVertLevels = len(gridfile.dimensions['nVertLevels'])
    if nVertLevels != 10:
         print 'nVerLevels in the supplied file was ', nVertLevels, '.  Were you expecting 10?'
    # Get variables
    xCell = gridfile.variables['xCell']
    yCell = gridfile.variables['yCell']
    xEdge = gridfile.variables['xEdge']
    yEdge = gridfile.variables['yEdge']
    xVertex = gridfile.variables['xVertex']
    yVertex = gridfile.variables['yVertex']
    thickness = gridfile.variables['thickness']
    bedTopography = gridfile.variables['bedTopography']
    beta = gridfile.variables['beta']
    normalVelocity = gridfile.variables['normalVelocity']
    layerThicknessFractions = gridfile.variables['layerThicknessFractions']
    temperature = gridfile.variables['temperature']
    cellsOnCell= gridfile.variables['cellsOnCell']
    # Get b.c. variables
    SMB = gridfile.variables['sfcMassBal']
except:
    sys.exit('Error: The grid file specified is either missing or lacking needed dimensions/variables.')



# Find center of domain
x0 = xCell[:].min() + 0.5 * (xCell[:].max() - xCell[:].min() )
y0 = yCell[:].min() + 0.5 * (yCell[:].max() - yCell[:].min() )
# Calculate distance of each cell center from dome center
r = ((xCell[:] - x0)**2 + (yCell[:] - y0)**2)**0.5

# Center the dome in the center of the cell that is closest to the center of the domain.
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

# Make a circular ice mass
# Define dome dimensions - all in meters
r0 = 21000.0
thickness[:] = 0.0  # initialize to 0.0
# Calculate the dome thickness for cells within the desired radius (thickness will be NaN otherwise)
thickness_field = thickness[0,:]
thickness_field[r<r0] = 1000.0
thickness[0,:] = thickness_field

# flat bed at -2000 m everywhere with a single grounded point
bedTopography[:] = -2000.0  
bedTopography[centerCellIndex] = -880.0
#bedTopography[cellsOnCell[centerCellIndex,:]-1] = -880.0  # use this to make the grounded area 7 cells instead of 1

# beta is 0 everywhere except a high value in the grounded cell
beta[:] = 0.
beta[centerCellIndex] = 1.0e8
#beta[cellsOnCell[centerCellIndex,:]-1] = 1.0e8 # use this to make the grounded area 7 cells instead of 1

# zero velocity everywhere
normalVelocity[:] = 0.0
# constant, arbitrary temperature, degrees C
temperature[:] = 273.15 
# Setup layerThicknessFractions
layerThicknessFractions[:] = 1.0 / nVertLevels
# boundary conditions
SMB[:] = 0.0  # m/yr
# Convert from units of m/yr to kg/m2/s using an assumed ice density
SMB[:] = SMB[:] *910.0/(3600.0*24.0*365.0)

gridfile.close()

print 'Successfully added circular-shelf initial conditions to: ', options.filename



