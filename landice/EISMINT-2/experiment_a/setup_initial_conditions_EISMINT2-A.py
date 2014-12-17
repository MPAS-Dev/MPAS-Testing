#!/usr/bin/env python
# Generate initial conditions for EISMINT-2 A land ice test case
# Test case is described in:
# Payne, A. J., Huybrechts, P., Calov, R., Fastook, J. L., Greve, R., Marshall, S. J., Marsiat, I., Ritz, C., Tarasov, L. and Thomassen, M. P. A.: Results from the EISMINT model intercomparison: the effects of thermomechanical coupling, J. Glaciol., 46(153), 227-238, 2000.

import sys, numpy
from netCDF4 import Dataset as NetCDFFile
from math import sqrt
import numpy
import shutil, glob

# Parse options
#from optparse import OptionParser
#parser = OptionParser()
#parser.add_option("-f", "--file", dest="filename", type='string', help="file to setup dome", metavar="FILE")
#options, args = parser.parse_args()

#if not options.filename:
#   options.filename = 'landice_grid.nc'
#   print 'No file specified.  Attempting to use landice_grid.nc'


# get a empty land ice grid to use from the parent directory
try:
  filename = "./eismint2A.input.nc"
  shutil.copy("../landice_grid.nc", filename)
  for file in glob.glob('../graph.info*'):
      shutil.copy(file, '.')
except:
  sys.exit("Error: problem copying ../landice_grid.nc and/or graph.info* to this directory")

# Open the file, get needed dimensions
try:
    gridfile = NetCDFFile(filename,'r+')
    nVertLevels = len(gridfile.dimensions['nVertLevels'])
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
except:
    sys.exit('Error: The grid file specified is either missing or lacking needed dimensions/variables.')

# Find center of domain
x0 = xCell[:].min() + 0.5 * (xCell[:].max() - xCell[:].min() )
y0 = yCell[:].min() + 0.5 * (yCell[:].max() - yCell[:].min() )
# Calculate distance of each cell center from dome center
r = ((xCell[:] - x0)**2 + (yCell[:] - y0)**2)**0.5

# Center the dome in the center of the cell that is closest to the center of the domain.
centerCellIndex = numpy.abs(r[:]).argmin()
# EISMINT-2 puts the center of the domain at 750,750 km instead of 0,0.
# Adjust to use that origin.
xsummit = 750000.0; ysummit = 750000.0
#print x0, y0, centerCellIndex, xCell[centerCellIndex], yCell[centerCellIndex]
xShift = -1.0 * xCell[centerCellIndex] + xsummit
yShift = -1.0 * yCell[centerCellIndex] + ysummit
xCell[:] = xCell[:] + xShift
yCell[:] = yCell[:] + yShift
xEdge[:] = xEdge[:] + xShift
yEdge[:] = yEdge[:] + yShift
xVertex[:] = xVertex[:] + xShift
yVertex[:] = yVertex[:] + yShift
# Now update origin location and distance array
x0 = 0.0
y0 = 0.0
r = ((xCell[:] - xsummit)**2 + (yCell[:] - ysummit)**2)**0.5


# Assign variable values for EISMINT-2 experiment
# Start with no ice
thickness[:] = 0.0
# zero velocity everywhere (only needed for HO solvers)
normalVelocity[:] = 0.0
# flat bed at sea level
bedTopography[:] = 0.0
# constant, arbitrary temperature, degrees C (doesn't matter since there is no ice initially)
temperature[:] = 0.0 
# Setup layerThicknessFractions
layerThicknessFractions[:] = 1.0 / nVertLevels

# ===================
# boundary conditions
# ===================
# Define values prescribed by Payne et al. 2000 paper.
rhoi = 910.0
scyr = 3600.0*24.0*365.0

# SMB field specified by EISMINT, constant in time for EISMINT-2
# It is a function of geographical position (not elevation)
Mmax = 0.5   # [m/yr] maximum accumulation rate
Sb = 10.0**-2     # gradient of accumulation rate change with horizontal distance  [m/a/km] 
Rel = 450.0  # [km]  accumulation rate 0 position
smb=numpy.minimum(Mmax, Sb * (Rel - r/1000.0)) # [m ice/yr]
SMB[:] = smb * rhoi / scyr  # in kg/m2/s

# Basal heat flux should be -4.2e-2
#G[:] = -4.2e-2  # [W/m2]

# Surface temperature
Tmin = 238.15 # minimum surface air temperature [K]
ST = 10.0**-2 # gradient of air temperature change with horizontal distance [K/km]
#Tsfc[:] = Tmin + ST * r/1000.0

gridfile.close()
print 'Successfully added initial conditions for EISMINT2, experiment A to the file: ', filename

