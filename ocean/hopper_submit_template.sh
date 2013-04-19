#!shell
#PBS -N run_name
#PBS -q regular 
#PBS -l walltime=alloted_run_time
#PBS -l mppwidth=num_procs 
cd  working_dir

aprun -n num_procs ocean_model.exe
