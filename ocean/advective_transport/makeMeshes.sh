#!/bin/bash

########################################################################################
## Change the horizontal spacings, vertical levels, and cells in the x direction here ##
## To start, grids are periodic in the x direction. This may change later             ##
########################################################################################
SPACINGS="1 2 4 8 16"
VERTLEVS="5"
TCNAME="advective_transport"

###############################################################
## Change reference spacing, time_step, and viscosities here ##
###############################################################
REF_TIME_STEP="10"
REF_VISC_H="0.0"
REF_VISC_V="0.0"
REF_SPACING="10.0"
TOTAL_TIME="7200" # in seconds

echo "Building ${TCNAME} meshes"

CUR_DIR=`pwd`

if [ -z "$3" ]; then
	PROCS="2 4 8 16 32"
else
	PROCS="$3"
fi

X_EXTENT="460"
Y_EXTENT="460"

#######################################################
## Setup Variables for different run initializations ##
#######################################################
DEFAULT_TIME_INTEGRATOR="'RK4'"
DEFAULT_SUBCYCLES="20"
ADVECTION_ROUTINES="std2 std3 std4 fct2 fct3 fct4"
TIME_STEPPERS="'rk4'"
TIME_STEPS="10"

############################################################
## Setup Default namelist keys and values to update later ##
############################################################
i=0
KEYS[$i]="config_run_duration";           VALUES[$i]="'0000_02:00:00'"; i=$i+1;
KEYS[$i]="config_input_name";             VALUES[$i]="'grid.nc'"; i=$i+1;
KEYS[$i]="config_output_name";            VALUES[$i]="'output.nc'"; i=$i+1;
KEYS[$i]="config_restart_name";           VALUES[$i]="'restart.nc'"; i=$i+1;
KEYS[$i]="config_output_interval";        VALUES[$i]="'00_02:00:00'"; i=$i+1;
KEYS[$i]="config_do_restart";             VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_vert_coord_movement";    VALUES[$i]="'uniform_stretching'"; i=$i+1;
KEYS[$i]="config_rho0";                   VALUES[$i]="1000"; i=$i+1;
KEYS[$i]="config_bottom_drag_coeff";      VALUES[$i]="1.0e-3"; i=$i+1;
KEYS[$i]="config_eos_type";               VALUES[$i]="'linear'"; i=$i+1;
KEYS[$i]="config_vert_tracer_adv_order";  VALUES[$i]="3"; i=$i+1;
KEYS[$i]="config_thickness_adv_order";    VALUES[$i]="3"; i=$i+1;
KEYS[$i]="config_use_mom_del2";	          VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_tracer_del2";	      VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_mom_del4";	          VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_tracer_del4";	      VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_const_visc_diff";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_const_visc_visc";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_rich_visc_diff";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_rich_visc_visc";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_tanh_visc_diff";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_use_tanh_visc_visc";    VALUES[$i]=".false."; i=$i+1;
KEYS[$i]="config_prescribe_velocity";     VALUES[$i]=".true."; i=$i+1;
KEYS[$i]="config_prescribe_thickness";     VALUES[$i]=".true."; i=$i+1;

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

NUM_LINES=`sed -n "/_model/,/\//p" MPAS-namelist.input.temporary | wc -l`
NUM_LINES=`echo ${NUM_LINES}-1 | bc`

sed -n "/_model/,/\//p" MPAS-namelist.input.temporary | head -n ${NUM_LINES} > namelist.top 
echo '/' >> namelist.top
echo '' >> namelist.top
sed '/_model/,/\//d' MPAS-namelist.input.temporary > namelist.bottom

cat namelist.top > MPAS-namelist.input.temporary
cat namelist.bottom >> MPAS-namelist.input.temporary

rm -f namelist.top namelist.bottom

mv MPAS-namelist.input.temporary MPAS-namelist.input.template

touch run_paths

#################################################################
## Generate full meshes, with initial conditions, using basin. ##
#################################################################
echo "   Checking out  basin"
svn co https://svn-mpas-model.cgd.ucar.edu/branches/ocean_projects/basin/src basin_checkout 1> /dev/null 2> /dev/null
cp basin_src/* basin_checkout/.

echo "   Building Basin"
# SED METHOD FOR REPLACING A SUBROUTINE
sed -ne '/subroutine get_init_conditions/ {p; r basin_src/get_init_conds.F' -e ':a; n; /end subroutine get_init_conditions/ {p; b}; ba}; p' basin_checkout/basin.F > temp.F
# BASH METHOD FOR REPLACING A SUBROUTINE
TOTAL_LINES=`cat basin_checkout/basin.F | wc -l`
BEGIN_LINE=`grep -n -e '^subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
END_LINE=`grep -n -e '^end subroutine get_init_conditions' basin_checkout/basin.F | cut -d : -f 1`
TAIL_LINES=`echo ${TOTAL_LINES} - ${END_LINE} + 1 | bc`

head -n $BEGIN_LINE basin_checkout/basin.F > temp.F
cat basin_src/get_init_conds.F >> temp.F
tail -n $TAIL_LINES basin_checkout/basin.F >> temp.F
mv temp.F basin_checkout/basin.F

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

		echo "     Converting ${NAME} mesh to have ${VERTLEV} levels"

		BASE_DIR=${NAME}_${VERTLEV}levs

		ln -s ${TCNAME}_${NAME}.grid.nc grid.nc

		mkdir -p dx
		sed "s/*VERTLEVS/${VERTLEVS}/g" BASIN-namelist.basin.template > namelist.basin
		./map > /dev/null
		rm namelist.basin

		unlink grid.nc

		mkdir -p ${CUR_DIR}/${BASE_DIR}

		for TIME_STEPPER in ${TIME_STEPPERS}
		do
			if [ ${TIME_STEPPER} == "'rk4'" ]; then
				TIME_INTEGRATOR="'RK4'"
				SUB_CYCLES=20
			elif [ ${TIME_STEPPER:0:2} == "'se'" ]; then
				TIME_INTEGRATOR="'split_explicit'"
				SUB_CYCLES=${TIME_STEPPER:2}
			elif [ ${TIME_STEPPER} == "'use'" ]; then
				TIME_INTEGRATOR="'unsplit_explicit'"
				SUB_CYCLES=20
			fi

			echo "Time integrator after test: ${TIME_STEPPER} -- ${TIME_INTEGRATOR}"

			for TIME_STEP in ${TIME_STEPS}
			do

				for ADVECTION_ROUTINE in ${ADVECTION_ROUTINES}
				do

					if [ ${ADVECTION_ROUTINE:0:3} == "std" ]; then
						FCT_ON=".false."
						ADV_ORDER=${ADVECTION_ROUTINE:3}
					elif [ ${ADVECTION_ROUTINE:0:3} == "fct" ]; then
						FCT_ON=".true."
						ADV_ORDER=${ADVECTION_ROUTINE:3}
					fi

					for PROC in $PROCS
					do

						## Compute scaled spacing, time_step, and viscosities
						D_SPACING=`echo "scale=4; ${SPACING}/${REF_SPACING}" | bc`

						RUN_DIR=${CUR_DIR}/${BASE_DIR}/.batch_runs/${TIME_STEPPER}_${TIME_STEP}_${ADVECTION_ROUTINE}/${PROC}procs

						mkdir -p ${RUN_DIR}

						pmetis graph.info $PROC > /dev/null
						mv graph.info.part.$PROC ${CUR_DIR}/${BASE_DIR}/.

						ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info ${RUN_DIR}/graph.info
						ln -f -s ${CUR_DIR}/${BASE_DIR}/graph.info.part.${PROC} ${RUN_DIR}/graph.info.part.${PROC}
						ln -f -s ${CUR_DIR}/${BASE_DIR}/grid.nc ${RUN_DIR}/grid.nc

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
						cat MPAS-namelist.input.template  \
							| sed "s/config_time_integrator .*/config_time_integrator = ${TIME_INTEGRATOR}/g" \
							| sed "s/config_n_btr_subcycles .*/config_n_btr_subcycles = ${SUB_CYCLES}/g" \
							| sed "s/config_dt .*/config_dt = ${TIME_STEP}/g" \
							| sed "s/config_monotonic .*/config_monotonic = ${FCT_ON}/g" \
							| sed "s/config_horiz_tracer_adv_order .*/config_horiz_tracer_adv_order = ${ADV_ORDER}/g" \
							> ${RUN_DIR}/namelist.input
					done
				done
			done
		done

		mv ocean.nc ${CUR_DIR}/${BASE_DIR}/grid.nc
		mv graph.info ${CUR_DIR}/${BASE_DIR}/graph.info

		## Copy executable to run directory
		if [ $# -ge 1  ]; then
			if [ -e ${CUR_DIR}/${BASE_DIR}/ocean_model.exe ]; then
				unlink ${CUR_DIR}/${BASE_DIR}/ocean_model.exe
			fi

			ln -s $1 ${CUR_DIR}/${BASE_DIR}/ocean_model.exe
		fi

		## Generate new namelist.input file for test case
		cat MPAS-namelist.input.template  \
			| sed "s/config_time_integrator .*/config_time_integrator = ${DEFAULT_TIME_INTEGRATOR}/g" \
			| sed "s/config_n_btr_subcycles .*/config_n_btr_subcycles = ${DEFAULT_SUBCYCLES}/g" \
			| sed "s/config_dt .*/config_dt = ${SCALED_TIME_STEP}/g" \
			| sed "s/config_monotonic .*/config_monotonic = ${FCT_ON}/g" \
			| sed "s/config_horiz_tracer_adv_order .*/config_horiz_tracer_adv_order = ${ADV_ORDER}/g" \
			> ${CUR_DIR}/${BASE_DIR}/namelist.input

	done
done

rm map
rm -rf dx
rm  MPAS-namelist.input.template
rm ${TCNAME}*
rm fort.*

rm -rf basin_checkout
cd ${CUR_DIR}

