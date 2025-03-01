MISMIP3D Test Case

For Description:
http://homepages.ulb.ac.be/~fpattyn/mismip3d/
http://www.ingentaconnect.com/content/igsoc/jog/2013/00000059/00000215/art00002


How to create MISMIP3D initial condition input file
------------------------------------------------------

These commands need to be repeated for each resolution desired (each in a subdirectory).

Commands without "../" have path listed but you'll have to execute them however makes sense for your setup.

1. Build periodic_hex mesh:
MPAS-Tools/grid_gen/periodic_hex/periodic_grid

2. Add cull mask to strip off the periodic cells.
../cull_cells_for_MISMIP.py
(Note that this script takes off an extra row to make the mesh symmetric
across the E-W axis.)

3. Cull out periodic cells
MPAS-Tools/grid_gen/mesh_conversion_tools/MpasCellCuller.x grid.nc culled.nc

4. Create LI mesh
MPAS-Tools/grid_gen/landice_grid_tools/create_landice_grid_from_generic_MPAS_grid.py -l 10 --beta --diri -i culled.nc

5. Apply IC values for the test case
../setup_mismip3d_initial_conditions.py

6. Create graph.info.part files
cp culled_graph_info graph.info
gpmetis graph.info 2
gpmetis graph.info 4
...

You can inspect results with MpasDraw or other tool.
