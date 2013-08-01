#!/bin/bash

########################################################################################
## Change the horizontal spacings, vertical levels, and cells in the x direction here ##
## To start, grids are periodic in the x direction. This may change later			  ##
########################################################################################

SPACINGS="5000 25000"
VERTLEVS="20"
NX="2"
TCNAME="internal_waves"
AMPLITUDES="3 0.2"

###############################################################
## Change reference spacing, time_step, and viscosities here ##
###############################################################
REF_TIME_STEP="300"
REF_VISC_H="10000.0"
REF_VISC_V="10000.0"
REF_SPACING="500.0"
TOTAL_TIME="17280000" # in seconds

echo "Building ${TCNAME} meshes"

CUR_DIR=`pwd`

if [ -z "$3" ]; then
	PROCS="2 4 8 16 32 64 128 256 512 1024 2048 4096"
else
	PROCS="$3"
fi

Y_EXTENT="275000"

############################################################
## Setup Default namelist keys and values to update later ##
############################################################

i=0
KEYS[$i]="config_time_integration";   VALUES[$i]="'split_explicit'"; i=$i+1;
KEYS[$i]="config_run_duration";       VALUES[$i]="'0200_00:00:00'"; i=$i+1;
KEYS[$i]="config_n_btr_subcycles";    VALUES[$i]="20"; i=$i+1;
KEYS[$i]="config_input_name";         VALUES[$i]="'grid.nc'"; i=$i+1;
KEYS[$i]="config_output_name";        VALUES[$i]="'output.nc'"; i=$i+1;
KEYS[$i]="config_restart_name";       VALUES[$i]="'restart.nc'"; i=$i+1;
KEYS[$i]="config_output_interval";    VALUES[$i]="'01_00:00:00'"; i=$i+1;
KEYS[$i]="config_do_restart";         VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_vert_grid_type";     VALUES[$i]="'zlevel'"; i=$i+1;
KEYS[$i]="config_rho0";               VALUES[$i]="1000"; i=$i+1;
KEYS[$i]="config_bottom_drag_coeff";  VALUES[$i]="1.0e-3"; i=$i+1;
KEYS[$i]="config_vert_visc_type";     VALUES[$i]="'const'"; i=$i+1;
KEYS[$i]="config_vert_diff_type";     VALUES[$i]="'const'"; i=$i+1;


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

i=1
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

for AMPLITUDE in $AMPLITUDES
do
	echo "   Checking out  basin"
    git clone --no-checkout --depth 1 git@github.com:MPAS-Dev/MPAS-Tools.git basin_repo_checkout 1> /dev/null 2> /dev/null
    cd basin_repo_checkout
    git checkout origin/master -- grid_gen/basin/src
    cd ../
    ln -s basin_repo_checkout/grid_gen/basin/src basin_checkout
	cp basin_src/* basin_checkout/.

	echo "   Bulding basin ${AMPLITUDE} amplitude"
	TOTAL_LINES=`cat basin_checkout/basin.F | wc -l`
	BEGIN_LINE=`grep -n -e '^subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
	END_LINE=`grep -n -e '^end subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
	TAIL_LINES=`echo ${TOTAL_LINES} - ${END_LINE} + 1 | bc`

	cat basin_src/get_init_conds.F | sed "s/*VERTLEVS/${VERTLEV}/g" | sed "s/*AMP/${AMPLITUDE}/g" > get_init_conds.F

	head -n $BEGIN_LINE basin_checkout/basin.F > temp.F
	cat get_init_conds.F >> temp.F
	tail -n $TAIL_LINES basin_checkout/basin.F >> temp.F
	mv temp.F basin_checkout/basin.F
	rm get_init_conds.F

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
			DC=`echo "${SPACING}.0"`

			## Compute scaled spacing, time_step, and viscosities
			D_SPACING=`echo "scale=4; ${SPACING}/${REF_SPACING}" | bc`
			TIME_STEP=`echo "scale=4; $D_SPACING * $REF_TIME_STEP" | bc`
			VISC_H=`echo "scale=4; ($D_SPACING^4)*${REF_VISC_H}" | bc`
			VISC_H=`echo ${REF_VISC_H}`
			VISC_V=`echo ${REF_VISC_V}`
			STATS=`echo " $TOTAL_TIME / $TIME_STEP / 10 " | bc`

			echo "     Converting ${NAME} mesh to have ${VERTLEV} levels"

			BASE_DIR=${NAME}_${VERTLEV}levs_${AMPLITUDE}amp

			ln -s ${TCNAME}_${NAME}.grid.nc grid.nc

			mkdir -p dx
			sed "s/*VERTLEVS/${VERTLEVS}/g" BASIN-namelist.basin.template > namelist.basin
			./map > /dev/null
			rm namelist.basin

			unlink grid.nc

			mkdir -p ${BASE_DIR}

			for PROC in $PROCS
			do
				RUN_DIR=${BASE_DIR}/.batch_runs/${PROC}procs
				mkdir -p ${RUN_DIR}

				pmetis graph.info $PROC > /dev/null
				mv graph.info.part.${PROC} ${CUR_DIR}/${BASE_DIR}/.

				ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info ${RUN_DIR}/graph.info
				ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info.part.${PROC} ${RUN_DIR}/graph.info.part.${PROC}
				ln -f -s ${CUR_DIR}/${BASE_DIR}/grid.nc ${RUN_DIR}/grid.nc
				ln -f -s ${CUR_DIR}/${BASE_DIR}/.batch_runs/namelist.input ${RUN_DIR}/namelist.input

				## Copy executable to run directory
				if [ $# -ge 1 ]; then
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
			done

			## Generate new namelist.input file for test case
			cat MPAS-namelist.input.template  \
				| sed "s/config_h_mom_eddy_visc2 .*/config_h_mom_eddy_visc2 = ${VISC_H}/g" \
				| sed "s/config_h_tracer_eddy_diff2 .*/config_h_tracer_eddy_diff2 = ${VISC_H}/g" \
				| sed "s/config_vert_visc .*/config_vert_visc = ${VISC_V}/g" \
				| sed "s/config_vert_diff .*/config_vert_diff = ${VISC_V}/g" \
				| sed "s/config_dt .*/config_dt = ${TIME_STEP}/g" \
				| sed "s/config_stats_interval .*/config_stats_interval = ${STATS}/g" \
				> ${BASE_DIR}/.batch_runs/namelist.input
		done

		mv ocean.nc ${BASE_DIR}/grid.nc
		mv graph.info ${BASE_DIR}/graph.info

		## Copy executable to run directory
		if [ $# -ge 1 ]; then
			if [ -e ${BASE_DIR}/ocean_model.exe ]; then
				unlink ${BASE_DIR}/ocean_model.exe
			fi
			ln -s $1 ${BASE_DIR}/ocean_model.exe
		fi

		cat MPAS-namelist.input.template  \
			| sed "s/config_h_mom_eddy_visc2 .*/config_h_mom_eddy_visc2 = ${VISC_H}/g" \
			| sed "s/config_h_tracer_eddy_diff2 .*/config_h_tracer_eddy_diff2 = ${VISC_H}/g" \
			| sed "s/config_vert_visc .*/config_vert_visc = ${VISC_V}/g" \
			| sed "s/config_vert_diff .*/config_vert_diff = ${VISC_V}/g" \
			| sed "s/config_dt .*/config_dt = ${TIME_STEP}/g" \
			| sed "s/config_stats_interval .*/config_stats_interval = ${STATS}/g" \
			> ${BASE_DIR}/namelist.input


	done
    unlink basin_checkout
	rm -rf basin_repo_checkout
done

rm map
rm -rf dx
rm  MPAS-namelist.input.template
rm ${TCNAME}*
rm fort.*

cd ${CUR_DIR}

