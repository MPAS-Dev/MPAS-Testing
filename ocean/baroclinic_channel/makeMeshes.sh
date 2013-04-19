#!/bin/bash

########################################################################################
## Change the horizontal spacings, vertical levels, and cells in the x direction here ##
## To start, grids are periodic in the x direction. This may change later             ##
########################################################################################
SPACINGS="1000 4000 10000"
VERTLEVS="20"
MIN_DEPTH="20" # If a ridge should be added, this is the number of levels of water at the center of the ridge.
TCNAME="baroclinic_channel"

###############################################################
## Change reference spacing, time_step, and viscosities here ##
###############################################################
REF_TIME_STEP="300"
REF_VISC_H="10.0"
REF_VISC_V="0.0001"
REF_SPACING="10000.0"
TOTAL_TIME="17280000" # in seconds

echo "Building ${TCNAME} meshes"

CUR_DIR=`pwd`

if [ -z "$3" ]; then
	PROCS="2 4 8 16 32"
else
	PROCS="$3"
fi

X_EXTENT="160000"
Y_EXTENT="500000"

#######################################################
## Setup Variables for different run initializations ##
#######################################################
TIME_STEPPERS["config_time_integrator"]="rk4"
TIME_STEPS["config_dt"]="40"

DEFAULT_TIME_INTEGRATOR="'split_explicit'"
DEFAULT_SUBCYCLES=20
DEFAULT_RUN_DURATION="'0010_00:00:00'"

############################################################
## Setup Default namelist keys and values to update later ##
############################################################
i=0
KEYS[$i]="config_run_duration";           VALUES[$i]="'0001_00:00:00'"; i=$i+1;
KEYS[$i]="config_input_name";             VALUES[$i]="'grid.nc'"; i=$i+1;
KEYS[$i]="config_output_name";            VALUES[$i]="'output.nc'"; i=$i+1;
KEYS[$i]="config_restart_name";           VALUES[$i]="'restart.nc'"; i=$i+1;
KEYS[$i]="config_output_interval";        VALUES[$i]="'01_00:00:00'"; i=$i+1;
KEYS[$i]="config_do_restart";             VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_vert_coord_movement";    VALUES[$i]="'uniform_stretching'"; i=$i+1;
KEYS[$i]="config_alter_ICs_for_pbcs";     VALUES[$i]="'zlevel_pbcs_off'"; i=$i+1;
KEYS[$i]="config_rho0";                   VALUES[$i]="1000"; i=$i+1;
KEYS[$i]="config_bottom_drag_coeff";      VALUES[$i]="1.0e-2"; i=$i+1;
KEYS[$i]="config_vert_visc_type";         VALUES[$i]="'const'"; i=$i+1;
KEYS[$i]="config_vert_diff_type";         VALUES[$i]="'const'"; i=$i+1;
KEYS[$i]="config_eos_type";               VALUES[$i]="'linear'"; i=$i+1;
KEYS[$i]="config_monotonic";              VALUES[$i]=".true."; i=$i+1;
KEYS[$i]="config_vert_tracer_adv_order";  VALUES[$i]="3"; i=$i+1;
KEYS[$i]="config_horiz_tracer_adv_order"; VALUES[$i]="3"; i=$i+1;

#################################################
## Build perfect hex meshes using periodic_hex ##
#################################################
cd periodic_hex

if [ -a Makefile.front ]; then
	cat Makefile.front > Makefile
	cat Makefile.end >> Makefile
else
	cp Makefile.bak Makefile
fi


make clean > /dev/null
make > /dev/null

for SPACING in $SPACINGS
do
	NAME=`echo "${SPACING}m"`
	NY=`echo "(${Y_EXTENT} / ${SPACING}) + 2" | bc`
	NX=`echo "(${X_EXTENT} / ${SPACING})" | bc`
	DC=`echo "${SPACING}.0"`

	echo "   Creating ${NAME} base mesh"

	cat namelist.input.template | sed "s/*NX/${NX}/g" | sed "s/*NY/${NY}/g" | sed "s/*DC/${DC}/g" > namelist.input
	./periodic_grid

	mv grid.nc ${TCNAME}_${NAME}.grid.nc
done

mv ${TCNAME}*.grid.nc $CUR_DIR/.
make clean > /dev/null

rm Makefile

##############################################################################
## Clear run_paths file, which will be used to submit all test cases later. ##
##############################################################################

cd $CUR_DIR

if [ -a run_paths ]; then
	rm run_paths
fi

########################################
## Setup Template Namelist input file ##
########################################
if [ -a MPAS-namelist.input.repo ]; then
	cp MPAS-namelist.input.repo MPAS-namelist.input.temporary
else
	cp MPAS-namelist.input.default MPAS-namelist.input.temporary
fi

for ((i=0; i<${#KEYS[@]}; i++));
do
	cat MPAS-namelist.input.temporary | sed "s/${KEYS[$i]} .*/${KEYS[$i]} = ${VALUES[$i]}/g" > Temp
	mv Temp MPAS-namelist.input.temporary
done


mv MPAS-namelist.input.temporary MPAS-namelist.input.template

touch run_paths

#################################################################
## Generate full meshes, with initial conditions, using basin. ##
#################################################################
echo "   Checking out  basin"
svn co https://svn-mpas-model.cgd.ucar.edu/branches/ocean_projects/basin/src basin_checkout 1> /dev/null 2> /dev/null
cp basin_src/* basin_checkout/.

echo "   Building Basin"
#### REPLACE GET_INIT_CONDITIONS SUBROUTINE ####
TOTAL_LINES=`cat basin_checkout/basin.F | wc -l`
BEGIN_LINE=`grep -n -e '^subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
END_LINE=`grep -n -e '^end subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
TAIL_LINES=`echo ${TOTAL_LINES} - ${END_LINE} + 1 | bc`

head -n $BEGIN_LINE basin_checkout/basin.F > temp.F
cat basin_src/get_init_conds.F >> temp.F
tail -n $TAIL_LINES basin_checkout/basin.F >> temp.F
mv temp.F basin.F

#### REPLACE DEFINE_KMT SUBROUTINE ####
cat basin_src/define_kmt.F | sed "s/*MIN_DEPTH/${MIN_DEPTH}/g" > define_kmt.F

TOTAL_LINES=`cat basin.F | wc -l`
BEGIN_LINE=`grep -n -e '^subroutine define_kmt' basin.F | cut -d : -f 1`
END_LINE=`grep -n -e '^end subroutine define_kmt' basin.F | cut -d : -f 1`
TAIL_LINES=`echo ${TOTAL_LINES} - ${END_LINE} + 1 | bc`

head -n $BEGIN_LINE basin.F > temp.F
cat define_kmt.F >> temp.F
tail -n $TAIL_LINES basin.F >> temp.F
mv temp.F basin_checkout/basin.F
rm basin.F define_kmt.F

if [ -a map ]; then
	rm map
fi

cd basin_checkout
if [ -a Makefile.front ]; then
	cat Makefile.front > Makefile
	cat Makefile.end >> Makefile
else
	cp Makefile.bak Makefile
fi
make clean > /dev/null
make > /dev/null

cd ../
cp basin_checkout/map .


for VERTLEV in $VERTLEVS
do
	if [ -a grid.nc ]; then
		unlink grid.nc
	fi

	## Call basin, for each perfect hex mesh.
	for SPACING in $SPACINGS
	do
		NAME=`echo "${SPACING}m"`
		NY=`echo "(${Y_EXTENT} / ${SPACING}) + 2" | bc`
		NX=`echo "(${X_EXTENT} / ${SPACING})" | bc`
		DC=`echo "${SPACING}.0"`

		## Compute scaled spacing, time_step, and viscosities
		D_SPACING=`echo "scale=4; ${SPACING}/${REF_SPACING}" | bc`
		SCALED_TIME_STEP=`echo "scale=4; $D_SPACING * $REF_TIME_STEP" | bc`
		VISC_H=`echo "scale=4; ($D_SPACING^2)*${REF_VISC_H}" | bc`
		VISC_H=`echo ${REF_VISC_H}` # No Scaling in Horizontal
		VISC_V=`echo ${REF_VISC_V}` # No Scaling in Vertocal

		echo "     Converting ${NAME} mesh to have ${VERTLEV} levels"

		BASE_DIR=${NAME}_${VERTLEV}levs

		ln -s ${TCNAME}_${NAME}.grid.nc grid.nc

		mkdir -p dx
		sed "s/*VERTLEVS/${VERTLEVS}/g" BASIN-namelist.basin.template > namelist.basin
		./map > /dev/null
		rm namelist.basin

		unlink grid.nc
		
		for TIME_STEPPER in ${TIME_STEPPERS}
		do
			if [ ${TIME_STEPPER} == 'rk4' ]; then
				TIME_INTEGRATOR="'RK4'"
				SUB_CYCLES=0
			elif [ ${TIME_STEPPER:0:2} == "se" ]; then
				TIME_INTEGRATOR="'split_explicit'"
				SUB_CYCLES=${TIME_STEPPER:2}
			elif [ ${TIME_STEPPER} == 'use' ]; then
				TIME_INTEGRATOR="'unsplit_explicit'"
				SUB_CYCLES=0
			fi

			for TIME_STEP in ${TIME_STEPS}
			do

				for PROC in $PROCS
				do

					RUN_DIR=${BASE_DIR}/.batch_runs/${TIME_STEPPER}_${TIME_STEP}/${PROC}procs

					mkdir -p ${RUN_DIR}

					pmetis graph.info $PROC > /dev/null
					mv graph.info.part.$PROC ${BASE_DIR}

					ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info ${RUN_DIR}/graph.info
					ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info.part.${PROC} ${RUN_DIR}/graph.info.part.${PROC}
					ln -f -s ${CUR_DIR}/${BASE_DIR}/grid.nc ${RUN_DIR}/grid.nc
					ln -f -s ${CUR_DIR}/${BASE_DIR}/dx ${RUN_DIR}/dx

					## Copy executable to run directory
					if [ $# -ge 1  ]; then
						if [ -e ${RUN_DIR}/ocean_model.exe ]; then
							unlink ${RUN_DIR}/ocean_model.exe
						fi

						ln -s $1 ${RUN_DIR}/ocean_model.exe
					fi

					## Copy run information to run directory
					if [ $# -ge 2 ]; then
						cp $2 ${RUN_DIR}/.
					fi

					echo "${CUR_DIR}/${RUN_DIR}" >> run_paths

					## Generate new namelist.input file for test case
					STATS=`echo " $TOTAL_TIME / $TIME_STEP / 10 " | bc`
					cat MPAS-namelist.input.template  \
						| sed "s/config_time_integrator .*/config_time_integrator = ${TIME_INTEGRATOR}/g" \
						| sed "s/config_n_btr_subcycles .*/config_n_btr_subcycles = ${SUB_CYCLES}/g" \
						| sed "s/config_dt .*/config_dt = ${TIME_STEP}/g" \
						| sed "s/config_mom_del2 .*/config_mom_del2 = ${VISC_H}/g" \
						| sed "s/config_tracer_del2 .*/config_tracer_del2 = 0.0/g" \
						| sed "s/config_vert_visc .*/config_vert_visc = ${VISC_V}/g" \
						| sed "s/config_vert_diff .*/config_vert_diff = 0.0/g" \
						| sed "s/config_use_mom_del4 .*/config_use_mom_del4 = .false./g" \
						| sed "s/config_use_tracer_del4 .*/config_use_tracer_del4 = .false./g" \
						| sed "s/config_use_mom_del2 .*/config_use_mom_del2 = .true./g" \
						| sed "s/config_use_tracer_del2 .*/config_use_tracer_del2 = .false./g" \
						> ${RUN_DIR}/namelist.input
				done
			done
		done

		mv ocean.nc ${BASE_DIR}/grid.nc
		mv graph.info ${BASE_DIR}/graph.info
		cp -R dx ${BASE_DIR}/.

		## Copy executable to run directory
		if [ $# -ge 1  ]; then
			if [ -e ${BASE_DIR}/ocean_model.exe ]; then
				unlink ${BASE_DIR}/ocean_model.exe
			fi

			ln -s $1 ${BASE_DIR}/ocean_model.exe
		fi

		## Generate new namelist.input file for typical test case
		STATS=`echo " $TOTAL_TIME / $SCALED_TIME_STEP / 10 " | bc`
		cat MPAS-namelist.input.template  \
			| sed "s/config_run_duration .*/config_run_duration = ${DEFAULT_RUN_DURATION}/g" \
			| sed "s/config_time_integrator .*/config_time_integrator = ${DEFAULT_TIME_INTEGRATOR}/g" \
			| sed "s/config_n_btr_subcycles .*/config_n_btr_subcycles = ${DEFAULT_SUBCYCLES}/g" \
			| sed "s/config_dt .*/config_dt = ${SCALED_TIME_STEP}/g" \
			| sed "s/config_mom_del2 .*/config_mom_del2 = ${VISC_H}/g" \
			| sed "s/config_tracer_del2 .*/config_tracer_del2 = ${VISC_H}/g" \
			| sed "s/config_vert_visc .*/config_vert_visc = ${VISC_V}/g" \
			| sed "s/config_vert_diff .*/config_vert_diff = ${VISC_V}/g" \
			| sed "s/config_use_mom_del4 .*/config_use_mom_del4 = .false./g" \
			| sed "s/config_use_tracer_del4 .*/config_use_tracer_del4 = .false./g" \
			| sed "s/config_use_mom_del2 .*/config_use_mom_del2 = .true./g" \
			| sed "s/config_use_tracer_del2 .*/config_use_tracer_del2 = .false./g" \
			| sed "s/config_use_const_visc .*/config_use_const_visc = .true./g" \
			| sed "s/config_use_const_diff .*/config_use_const_diff = .true./g" \
			> ${BASE_DIR}/namelist.input
	done
done

rm map
rm -rf dx
rm  MPAS-namelist.input.template
rm ${TCNAME}*
rm fort.*

rm -rf basin_checkout
cd ${CUR_DIR}

