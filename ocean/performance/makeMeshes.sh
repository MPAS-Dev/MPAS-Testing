#!/bin/bash

#############################################################
## Configure performance run using the following variables ##
#############################################################
MESH_LIST="015km_40levs 030km_40levs 060km_40levs 120km_40levs"
MESH_DIR="domains_lobo"

## If processor list is passed in, use it. Otherwise use the default.
if [ -z "$3" ]; then
	PROC_LIST="24 48 96 192 384 768 1536 3072"
else
	PROC_LIST="$3"
fi

##############################################
## Don't edit below this unless you need to ##
##############################################

CUR_DIR=`pwd`
rm -f run_paths

for MESH in $MESH_LIST
do
	echo "Setting up performance runs with ${MESH} mesh"

	for PROC in $PROC_LIST
	do
		## Setup run directory
		RUN_DIR=${CUR_DIR}/${MESH}/${PROC}procs
		mkdir -p $RUN_DIR

		cd ${RUN_DIR}

		cp -d ${CUR_DIR}/$MESH_DIR/$MESH/*.nc .
		cp -d ${CUR_DIR}/$MESH_DIR/$MESH/graph.info .
		cp -d ${CUR_DIR}/$MESH_DIR/$MESH/namelist* .
		cp -d $2 $RUN_DIR/.

		if [ -e ${RUN_DIR}/ocean_model.exe ]; then
			unlink ${RUN_DIR}/ocean_model.exe
		fi
		ln -s ${OCEAN_MODEL_EXECUTABLE} ${RUN_DIR}/ocean_model.exe

		## Copy executable to run directory
		if [ $# -ge 1  ]; then
			if [ -e ocean_model.exe ]; then
				unlink ocean_model.exe
			fi

			ln -s $1 ocean_model.exe
		fi

		## Copy run information to run directory
		if [ $# -ge 2 ]; then
			cp $2 .
		fi

		pmetis graph.info ${PROC} > /dev/null

		cd ${CUR_DIR}

		echo ${RUN_DIR} >> ${CUR_DIR}/run_paths
	done
done
