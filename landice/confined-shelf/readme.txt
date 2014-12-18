Confined Shelf Test Case

Included files:
* namelist.input.periodic_hex is used for running periodic_hex to create a grid for the test case.  It needs to be renamed to 'namelist.input' to run periodic_hex if mesh needs to be generated.  If you downloaded a tar archive of this test case, you do not need to create the mesh and can ignore this file.

* setup_confined_shelf_initial_conditions.py
To setup the initial conditions once a landice_grid.nc has been created use:
> python setup_dome_initial_conditions.py
If you downloaded a tar archive of this test case, you do not need to generate IC and can ignore this file.  Note that this script should only be run on a newly created landice_grid.nc file - if it is run multiple times on the same file it will corrupt the values of the coordinate variables.

* namelist.landice is used for running the test case in the MPAS land ice core.  It includes most but not all options available to the model.  See the default namelist.landice.defaults file in the MPAS root directory for a list of all options available.  They are also documented in the User's Guide.

* There currently are no scripts for post-processing the output.

Instructions:
Once you symlink or copy the landice_model executable and adjust the namelist settings if desired, you can simply run the model with, e.g.:
> ./landice_model                (for a 1 processor job)
> mpirun -np 4 ./landice_model   (for a 4 processor job)

After running landice_model, the results can be visualized with Paraview or MpasDraw


All of the python scripts have usage options that can be viewed with the --help argument, but all have sensible defaults if invoked with no additional arguments.

