#!/bin/bash

RUNS=`cat run_paths`
OUTPUT_NAME=output.0000-01-01_00:00:00.nc

rm -f *.errors

for RUN in ${RUNS}
do

	RESOLUTION=${RUN%%levs/*}
	RESOLUTION=${RESOLUTION##*/}
	RESOLUTION=${RESOLUTION%m_*}
	ADVECTION_ROUTINE=${RUN##*levs/}
	ADVECTION_ROUTINE=${ADVECTION_ROUTINE%/*}
	ADVECTION_ROUTINE=${ADVECTION_ROUTINE##*_}

	ERROR=`./rms_error_from_ic.py -f ${RUN}/${OUTPUT_NAME} -v tracer1 | tail -n 1 | awk '{print $2}'`

	echo "${RESOLUTION} ${ERROR}" >> ${ADVECTION_ROUTINE}.errors
done

ERROR_FILES=`ls *.errors`

for ERROR_FILE in ${ERROR_FILES}
do
	sort -n ${ERROR_FILE} > temp
	mv temp advective_transport_${ERROR_FILE}
done
