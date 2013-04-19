#!shell
#MSUB -N run_name
#MSUB -l walltime=alloted_run_time
#MSUB -l nodes=num_nodes:ppn=procs_per_node
#MSUB -d working_dir

mpirun -np num_procs ./ocean_model.exe
