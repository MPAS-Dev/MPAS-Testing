Dome Test Case


namelist.input.periodic_hex is used for running periodic_hex to create a grid for the dome test case.
namelist.input.land_ice is used for actually running dome test case in the MPAS land ice core.


These namelist files need to be moved/renamed as necessary to execute the various steps outlined in the Quick Start Guide.

Eventually a script may be created to automate the various steps.

To setup the initial conditions once a landice_grid.nc has been created use:
> python setup_dome_initial_conditions.py

After running landice_model, the results can be visualized with two scripts.
1. visualize_dome.py: Plots up some general output views.
2. halfar.py: Compares the model results to the Halfar analytic solution.

All of the python scripts have usage options that can be viewed with the --help argument, but all have sensible defaults if invoked with no additional arguments.

