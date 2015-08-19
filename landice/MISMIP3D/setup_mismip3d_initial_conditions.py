#!/usr/bin/env python
# This script sets up MISMIP3D Stnd experiment.
# see http://homepages.ulb.ac.be/~fpattyn/mismip3d/Mismip3Dv12.pdf

import sys
from netCDF4 import Dataset
from math import sqrt
import numpy as np
from collections import Counter

# Parse options
from optparse import OptionParser
parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", type='string', help="file in which to setup MISMIP3D Stnd", metavar="FILE")
options, args = parser.parse_args()
if not options.filename:
   options.filename = 'landice_grid.nc'
   print 'No file specified.  Attempting to use landice_grid.nc'


# Open the file, get needed dimensions
try:
    gridfile = Dataset(options.filename,'r+')
    nCells = len(gridfile.dimensions['nCells'])
    nVertLevels = len(gridfile.dimensions['nVertLevels'])
    nVertInterfaces = nVertLevels + 1
    maxEdges = len(gridfile.dimensions['maxEdges'])
    if nVertLevels != 10:
         print 'nVerLevels in the supplied file was ', nVertLevels, '.  10 levels is a preliminary value to be used  with this test case.'
except:
    sys.exit('Error: The grid file specified is missing needed dimensions.')



# put the domain origin in the center of the center cell in the y-direction and in the 2nd row on the x-direction
# Only do this if it appears this has not already been done:
xCell = gridfile.variables['xCell'][:]
yCell = gridfile.variables['yCell'][:]
if yCell.min() > 0.0:
   print 'Shifting domain origin, because it appears that this has not yet been done.'
   unique_ys=np.array(sorted(list(set(yCell[:]))))
   targety = (unique_ys.max() - unique_ys.min()) / 2.0 + unique_ys.min()  # center of domain range
   best_y=unique_ys[ np.absolute((unique_ys - targety)) == np.min(np.absolute(unique_ys - (targety))) ][0]
   print 'Found a best y value to use of:' + str(best_y)
   
   unique_xs=np.array(sorted(list(set(xCell[:]))))
   targetx = (unique_xs.max() - unique_xs.min()) / 2.0 + unique_xs.min()  # center of domain range
   best_x=unique_xs[ np.absolute((unique_xs - targetx)) == np.min(np.absolute(unique_xs - (targetx))) ][0]
   print 'Found a best x value to use of:' + str(best_x)
   
   xShift = -1.0 * best_x
   yShift = -1.0 * best_y
   gridfile.variables['xCell'][:] = xCell + xShift
   gridfile.variables['yCell'][:] = yCell + yShift
   xCell = xCell + xShift
   yCell = yCell + yShift
   gridfile.variables['xEdge'][:] = gridfile.variables['xEdge'][:] + xShift
   gridfile.variables['yEdge'][:] = gridfile.variables['yEdge'][:] + yShift
   gridfile.variables['xVertex'][:] = gridfile.variables['xVertex'][:] + xShift
   gridfile.variables['yVertex'][:] = gridfile.variables['yVertex'][:] + yShift

#   print np.array(sorted(list(set(yCell[:]))))


# bed slope defined by b(m)=-100km-x(km)
topg = np.zeros((nCells,))
topg[np.nonzero(xCell>=0.0)]= -100.0 - xCell[np.nonzero(xCell>=0.0)]/1000.0
topg[np.nonzero(xCell<0.0)] = -100.0 + xCell[np.nonzero(xCell< 0.0)]/1000.0
gridfile.variables['bedTopography'][:] = topg[:]

# SMB
SMB = np.zeros((nCells,))
# 0.5 m/yr is the standard value.  0.3 m/yr is also tested in MISMIP3D.
# Convert from units of m/yr to kg/m2/s using appropriate ice density
SMB[:] = 0.5 *900.0/(3600.0*24.0*365.0)
# Add a 'gutter' along the eastern edge
SMB[ np.nonzero(xCell >  800000.0) ] = -100.0
SMB[ np.nonzero(xCell < -800000.0) ] = -100.0
gridfile.variables['sfcMassBal'][:] = SMB[:]

# Thickness initial condition is no ice.
thickness = np.zeros((nCells,))
thickness[:] = 600.0 # can start with nonzero thickness to get into the action faster.
thickness[ np.nonzero(np.absolute(xCell) > 800000.0) ] = 0.0
gridfile.variables['thickness'][0,:] = thickness[:]

# For now approximate boundary conditions with 0 velocity.
# This is not correct.
# west boundary should be dh/dx=ds/dx=0.
# north and south boundaries should be no slip lateral boundaries.
# Dirichlet velocity mask
kinbcmask = np.zeros((1, nCells, nVertInterfaces))
kinbcmask[:, np.nonzero(yCell == yCell.min()), : ] = 3 # south row  3=dirichlet set for y-component only
kinbcmask[:, np.nonzero(yCell == yCell.max()), : ] = 3 # north row
###kinbcmask[:, np.nonzero(xCell < 0.0), : ] = 1 # west boundary
gridfile.variables['dirichletVelocityMask'][:] = kinbcmask
# Dirichlet velocity values
gridfile.variables['uReconstructX'][:] = 0.0
gridfile.variables['uReconstructY'][:] = 0.0

# beta is not correct
gridfile.variables['beta'][:] = 1.0e7  # For the basal friction law being used, beta holds the 'C' coefficient in Pa m^-1/3 s^1/3

# constant, arbitrary temperature, K
gridfile.variables['temperature'][:] = 273.15

# Setup layerThicknessFractions
gridfile.variables['layerThicknessFractions'][:] = 1.0 / float(nVertLevels)

gridfile.close()

print 'Successfully added MISMIP3D initial conditions to: ', options.filename

