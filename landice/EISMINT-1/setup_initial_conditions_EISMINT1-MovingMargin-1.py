#!/usr/bin/python
# Generate initial conditions for EISMINT-1 moving margin land ice test case

import sys, numpy
from netCDF4 import Dataset as NetCDFFile
from math import sqrt
import numpy

# Parse options
from optparse import OptionParser
parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", type='string', help="file to setup dome", metavar="FILE")
options, args = parser.parse_args()

if not options.filename:
   options.filename = 'landice_grid.nc'
   print 'No file specified.  Attempting to use landice_grid.nc'


# Open the file, get needed dimensions
try:
    gridfile = NetCDFFile(options.filename,'r+')
    nVertLevels = len(gridfile.dimensions['nVertLevels'])
    # Get variables
    xCell = gridfile.variables['xCell'][:]
    yCell = gridfile.variables['yCell'][:]
    thickness = gridfile.variables['thickness'][:]
    bedTopography = gridfile.variables['bedTopography'][:]
    normalVelocity = gridfile.variables['normalVelocity'][:]
    layerThicknessFractions = gridfile.variables['layerThicknessFractions'][:]
    temperature = gridfile.variables['temperature'][:]
    # Get b.c. variables
    SMB = gridfile.variables['sfcMassBal'][:]
except:
    sys.exit('Error: The grid file specified is either missing or lacking needed dimensions/variables.')


# Assign variable values for EISMINT-1 experiment
# Start with no ice
thickness[:] = 0.0
# zero velocity everywhere (only needed for HO solvers)
normalVelocity[:] = 0.0
# flat bed at sea level
bedTopography[:] = 0.0
# constant, arbitrary temperature, degrees C
temperature[:] = 0.0 
# Setup layerThicknessFractions
layerThicknessFractions[:] = 1.0 / nVertLevels

# boundary conditions
# SMB field specified by EISMINT, constant in time for EISMINT-1
x0 = xCell.min() + 0.5 * (xCell.max() - xCell.min() )
y0 = yCell.min() + 0.5 * (yCell.max() - yCell.min() )
# Calculate distance of each cell center from domain center
d = ((xCell - x0)**2 + (yCell - y0)**2)**0.5
# Define function for SMB
Rel = 450000.0  # m
s = 10.0**-2     # given in units of m/a/km, 
s = s * 910.0 / 1000.0 / (3600.0*24.0*365.0)  # converted to kg/m2/s/m using ice density of 910.0
SMB[:] = numpy.minimum(0.5 * 900.0 / (3600.0*24.0*365.0),   s * (Rel - d) )

# Basal heat flux should be -42.e-3 once it is added.
# Surface temperature should be 270 K - 0.01 H when it is added.

# Reassign the modified numpy array values back into netCDF variable objects 
gridfile.variables['thickness'][:] = thickness
gridfile.variables['normalVelocity'][:] = normalVelocity
gridfile.variables['bedTopography'][:] = bedTopography
gridfile.variables['temperature'][:] = temperature
gridfile.variables['layerThicknessFractions'][:] = layerThicknessFractions
gridfile.variables['sfcMassBal'][:] = SMB

gridfile.close()
print 'Successfully added initial conditions for EISMINT1-Moving Margin, experiment 1 to the file: ', options.filename

