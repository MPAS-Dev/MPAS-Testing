#!/bin/bash

#################################################
## Change these variables to customize the run ##
#################################################

## The repository address below shows how to change the revision number.
## Be careful with the compile set for an older version, as not all the options
## that exists now were present in older versions. Below that, is an example of 
## how to specify a username and password in the commit line.

# REPOSITORY_ADDRESS="https://svn-mpas-model.cgd.ucar.edu/trunk/mpas -r 995"
# REPOSITORY_ADDRESS="https://svn-mpas-model.cgd.ucar.edu/trunk/mpas --username user --password pass"

REPOSITORY_ADDRESS="git@github.com:MPAS-Dev/MPAS.git"
COMPILE_SET="gfortran"
MACHINE_NAME="lobo"
MACHINE_PPN="16"
ALLOTED_RUN_TIME="01:00:00"
SUBMISSION_CMD=msub
PROC_LIST="2 4 8"

########################
## Script starts here ##
########################


CUR_DIR=`pwd`

ACTION=$1
CASE=$2
VALID="no"
ACTION_VALID="no"
CASE_VALID="no"


## Remove forward slashes from case name, so the case can be tab-compeleted using the directory name
CASE=`echo $CASE | sed "s|/||g"`

## Function Definitions ###{{{

## Checkout and compile mpas.
setup_mpas () { #{{{
	rm -f .run_info
	rm -f run_paths
	rm -f .mpas_namelist.input
	touch .run_info

	## Check out mpas from repository
	echo "Checking out ${REPOSITORY_ADDRESS}"
	git clone --depth 1 $REPOSITORY_ADDRESS mpas &> /dev/null
	cd mpas

	## Compile mpas using given compile set
	echo "Compiling mpas using ${COMPILE_SET}" 
	make $COMPILE_SET CORE=ocean > /dev/null &> /dev/null
    REV=`git log -n 1 | grep "commit" | awk '{print $2}'`
	cd ..

	## Make a variable containing the make options used to build mpas
	NUM_LINES=`sed -n "/${COMPILE_SET}:/,/:/p" mpas/Makefile | tail -n +2 | wc -l`
	NUM_LINEA=`echo "${NUM_LINES}-2" | bc`
	MAKE_OPTS=`sed -n "/${COMPILE_SET}:/,/:/p" mpas/Makefile | head -n ${NUM_LINES} \
		 | grep "_PARALLEL" -v | grep "_DEBUG" -v | sed "s/FC_SERIAL/SFC/g" \
		 | sed "s/CC_SERIAL/SCC/g" | sed "s/_OPT//g" | grep "SERIAL" -v \
		 | grep "DEBUG" -v | grep "USE_PAPI" -v | tail -n +2`


	OFFSET=`grep "FILE_OFFSET = " mpas/Makefile`

	## Create the run_info file, which will be used later to identify what
	## revision the run was performed from
	echo "Compile flags:" >> .run_info
	echo "$COMPILE_SET:" >> .run_info
	sed -n "/${COMPILE_SET}:/,/:/p" mpas/Makefile | head -n ${NUM_LINES} | tail -n +2 >> .run_info
	echo "" >> .run_info
	echo "Checkout path:" >> .run_info
    echo "Commit: $REV" >> .run_info
	echo "$REPOSITORY_ADDRESS" >> .run_info
	echo "$MACHINE_NAME" >> .run_info

	## Create a header of a Makefile for use in compiling subcode with the same compiler.
	echo "${OFFSET}" > .Makefile.front
	echo "${COMPILE_SET}:" >> .Makefile.front
	echo -e "\t$MAKE_OPTS" >> .Makefile.front

	cp mpas/namelist.input.ocean .mpas_namelist.input
} #}}}

## Setup test case
setup () { #{{{
	echo "Setting up ${CASE} test case"

	## Copy makefile header to sub directories if needed
	if [ -e ${CASE}/basin_src ]; then
		cp .Makefile.front ${CASE}/basin_src/Makefile.front
	fi

	if [ -e ${CASE}/periodic_hex ]; then
		cp .Makefile.front ${CASE}/periodic_hex/Makefile.front
	fi

	cp .run_info run_info
	cp .mpas_namelist.input ${CASE}/MPAS-namelist.input.repo
	cd ${CASE}

	## Call script to setup run directories, and meshes if needed
	./makeMeshes.sh ${CUR_DIR}/mpas/ocean_model ${CUR_DIR}/run_info "$PROC_LIST"
	cd ${CUR_DIR}

	rm run_info
} #}}}

## Submit test case runs to queue
submit () { #{{{
	echo "Submitting ${CASE} test case runs"
	RUNS=`cat $CASE/run_paths`
	rm -f job_ids_$CASE cancel_jobs_$CASE.sh
	rm -f start_times_$CASE.sh
	mkdir -p $CASE/submits

	## Loop over run directories in ./${CASE}
	for RUN in $RUNS
	do
		## Get the name of the current run, and number of processors
		## from the run directory
		NAME=`echo ${RUN%/*procs}`
		NAME=`echo ${NAME##*/}`
		PROCS=`echo ${RUN##*/}`
		PROCS=`echo ${PROCS%%procs}`

		## Determine division of processors based on machine's PPN
		if [ $PROCS -lt $MACHINE_PPN ]; then
			NODES=1
			PPN=${PROCS}
		else
			NODES=`echo "$PROCS / $MACHINE_PPN" | bc`
			PPN=${MACHINE_PPN}
		fi

		## Generate submission script
		cat ${CUR_DIR}/${MACHINE_NAME}_submit_template.sh \
			| sed "s/run_name/${CASE}_${NAME}/g" \
			| sed "s/num_nodes/${NODES}/g" \
			| sed "s/procs_per_node/${PPN}/g" \
			| sed "s|working_dir|$RUN|g" \
			| sed "s/num_procs/$PROCS/g" \
			| sed "s|shell|${SHELL}|g" \
			| sed "s/alloted_run_time/${ALLOTED_RUN_TIME}/g" > $CASE/submits/$NAME.sh

		## Submit job, and retain job id for later use
		JOB_ID=`${SUBMISSION_CMD} ${CUR_DIR}/${CASE}/submits/$NAME.sh`
		JOB_ID=`echo $JOB_ID | grep [0-9]`

		## Write job id to a file
		echo $JOB_ID >> job_ids_${CASE}

		## Write start_times and cancel_jobs scripts
		echo 'echo "' "$JOB_ID" '" `showstart ' "$JOB_ID | head -n 3 | tail -n 1 | awk '{print" '$6' " }'" '`'  >> start_times_${CASE}.sh
		echo "canceljob $JOB_ID > /dev/null &> /dev/null" >> cancel_jobs_${CASE}.sh
	done

	## Finish cancel_jobs script
	echo 'echo "All jobs canceled"' >> cancel_jobs_${CASE}.sh
	echo "rm -f cancel_jobs_${CASE}.sh start_times_${CASE}.sh job_ids_${CASE}" >> cancel_jobs_${CASE}.sh

	## Make scripts executable
	chmod +x cancel_jobs_${CASE}.sh
	chmod +x start_times_${CASE}.sh
} #}}}

## Postprocess test case
postprocess () { #{{{
	echo "Processing ${CASE} test case data"
	rm -f timing_results_${CASE}.txt timing_results2_${CASE}.txt 
	rm -f timing_results3_${CASE}.txt

	echo "procs = [ " > timing_results3_front
	echo "WCtime = [ ..." > timing_results3_back

	RUNS=`cat ${CASE}/run_paths`

	## Loop over run directories in ./${CASE}
	for RUN in $RUNS
	do

		## Get name, processor counts, and grid spacing from directory name
		NAME=`echo ${RUN%/*procs}`
		NAME=`echo ${NAME##*/}`
		SPACING=`echo ${NAME%m*}`
		PROCS=`echo ${RUN##*/}`
		PROCS=`echo ${PROCS%%procs}`

		## Get final kinetic energy, total run time, and run duration
		## from run directory
		KE=`cat ${RUN}/stats_max.txt | tail -n 1 | awk '{print $7}'`
		TIME=`grep "total time" ${RUN}/log.0000.out | awk '{print $4}' | head -n 1`
		DURATION=`grep "config_run_duration" ${RUN}/namelist.input`

		## Determine spacing in kilometers
		KM=`expr match "$SPACING" 'k'`

		if [ $KM == 0 ]; then
			KM=`echo "scale=4; ${SPACING%k} / 1000" | bc`
		else
			KM=`echo ${SPACING%k}`
		fi

		## Build portions of timing_results file
		## Written separately so paste will format properly
		echo "${NAME}_${PROCS}procs" >> first
		echo "${DURATION}" >> second
		echo "Final KE: ${KE}" >> third
		echo "Total time: ${TIME}" >> fourth

		## Write timing_results2 file
		echo "${KM}" ${PROCS} ${TIME} >> timing_results2_${CASE}.txt

		## Build portions of timing_results3 file
		echo "${PROCS}  " >> timing_results3_front
		echo " ${TIME} ; ... % ${NAME}-${PROCS}procs" >> timing_results3_back
	done

	## Finish timing_results files, and clean up
	echo "]" >> timing_results3_front
	echo "     ]/86400.;" >> timing_results3_back

	paste first second third fourth > timing_results_${CASE}.txt

	cat timing_results3_front > timing_results3_${CASE}.txt
	cat timing_results3_back >> timing_results3_${CASE}.txt

	rm -f first second third fourth timing_results3_front timing_results3_back

	cd ${CASE}
	if [ -e getErrors.sh ]; then
		echo "Computing Errors"
		./getErrors.sh > /dev/null
	fi
	cd ${CUR_DIR}
	mv ${CASE}/*.errors .
} #}}}

## Clean up mpas directory
clean_mpas () { #{{{
	echo "Cleaning MPAS"
	rm -rf mpas
	rm -f .run_info .Makefile.front
	rm -f .mpas_namelist.input
} #}}}

## Clean up test case directory
clean () { #{{{
	echo "Cleaning ${CASE} test case"
	cd ${CASE}
	rm -rf *m_*levs* submits
	rm -f run_paths
	rm -f MPAS-namelist.input.repo
	cd ${CUR_DIR}

	rm -f *${CASE}.sh
	rm -f ${CASE}*.errors
	rm -f timing_results*_${CASE}.txt
	rm -f job_ids_${CASE}
} #}}}

#}}}

MPAS_BUILD_RUN="no"
## Check to see if mpas has already been built, if not set it up
if [ ! -e mpas/ocean_model -a $ACTION != "clean" ]; then
	if [ $# -ge 3 ]; then
		echo ""
		echo "Overriding COMPILE_SET with $3"
		echo ""
		COMPILE_SET=$3
	fi
	echo "MPAS is not setup properly yet. Setting up MPAS first."
	setup_mpas

	if [ ! -e mpas/ocean_model ]; then
		echo ""
		echo "MPAS was not successfully built. Please ensure your compiler set is correct."
		echo "${COMPILE_SET} was used this time."
		echo ""
	fi
	MPAS_BUILD_RUN="yes"
fi

## Check to see if pmetis is in path, as it is supposed to be. If not exit
which pmetis 1> /dev/null 2> err
PMETIS_CHECK=`grep "no pmetis in" err`
rm err

if [ -n "${PMETIS_CHECK}" ]; then
	echo ""
	echo "pmetis is not found."
	echo "pmetis must be in your path."
	echo "exiting."
	echo ""
	exit
fi

## Verify a valid action and case are passed into script. If not print usage statement, and exit
if [ $# -ge 2 ]; then
	if [ $1 == "setup" -o $1 == "submit" -o $1 == "postprocess" -o "clean" ]; then
		ACTION_VALID="yes"
	fi

	if [ -e $2 ]; then 
		CASE_VALID="yes"
	fi

	if [ $ACTION_VALID == "yes" ]; then
		if [ $CASE_VALID == "yes" ]; then
			VALID="yes"
		fi
	fi

	## If case is mpas and action is setup, exit
	if [ $CASE == "mpas" -a $ACTION == "setup" -a $MPAS_BUILD_RUN == "no" ]; then
		echo ""
		echo "MPAS was previous setup. Nothing to do."
		echo "To check the parameters of the build, view .run_info"
		echo ""
		exit
	elif [ $CASE == "mpas" -a $ACTION == "setup" -a $MPAS_BUILD_RUN == "yes" ]; then
		exit
	fi

	## If case is mpas, action has to be clean, or setup
	if [ $CASE == "mpas" -a $ACTION != "clean" ]; then
		echo "A case of mpas can only have action of clean or setup"
		echo ""
		VALID="no"
	fi

	## If case is mpas, action has to be clean, or setup
	if [ $CASE == "mpas" -a $ACTION == "clean" ]; then
		VALID="yes"
	fi
fi

## Print usage statement
if [ $VALID == "no" ]; then
	echo "Invalid usage."
	echo "./oceanTestCases.sh [action] [case] [compile_set]"
	echo ""
	echo "[action] = setup submit postprocess clean"
	echo ""
	echo "[case] = lock_exchange baroclinic_channel"
	echo "[case] = mpas (only for actions = setup or clean)"
	echo ""
	echo "[compile_set] = a valid compile set for MPAS' Makefile"
	echo "[compile_set] is only used when MPAS has not been setup previously"
	echo ""
	echo ""
	echo "Example use:"
	echo "svn update"
	echo "oceanTestCases.sh clean mpas"
	echo "oceanTestCases.sh clean [case]"
	echo "oceanTestCases.sh setup mpas [compile_set]"
	echo "oceanTestCases.sh setup [case]"
	echo ""
	exit
fi

## Handle different actions
if [ $ACTION == "setup" ]; then
	setup
elif [ $ACTION == "submit" ]; then
	submit

elif [ $ACTION == "postprocess" ]; then
	postprocess
elif [ $ACTION == "clean" ]; then
	rm -f run_paths job_ids

	if [ $CASE == "mpas" ]; then
		clean_mpas
	else
		clean
	fi
fi


