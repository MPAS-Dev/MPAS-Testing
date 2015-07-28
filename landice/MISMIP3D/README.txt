How to create MISMIP3D initial condition input file
------------------------------------------------------


Commands without "./" have path listed but you'll have to execute them however makes sense for your setup.

1. Build periodic_hex mesh:
MPAS-Tools/grid_gen/periodic_hex/periodic_grid

2. Add cull mask to strip off the periodic cells.
MPAS-Tools/grid_gen/periodic_hex/mark_periodic_boundaries_for_culling.py

3. Cull out periodic cells
MPAS-Tools/grid_gen/mesh_conversion_tools/MpasCellCuller.x grid.nc culled.nc

4. Create LI mesh
MPAS-Tools/grid_gen/landice_grid_tools/create_landice_grid_from_generic_MPAS_grid.py -l 10 --beta --diri -i culled.nc

5. Apply IC values for the test case
./setup_mismip3d_initial_conditions.py

You can inspect results with MpasDraw or other tool.
