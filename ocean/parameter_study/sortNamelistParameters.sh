#!/bin/bash
REGISTRY_PATH=/path/to/src/core_ocean/Registry
NAMELIST_PATH=/path/to/default/namelist.input

cat $NAMELIST_PATH | grep "config_" | awk '{print $1}' > params
PARAMS=`cat params`

rm -f parameter_groups.py group_order.py
LASTGROUP=""

for PARAM in ${PARAMS}
do
	NLGROUP=`grep " $PARAM " ${REGISTRY_PATH} | awk '{print $3}'`

	echo 'namelist_groups["'${NLGROUP}'"].append("'${PARAM}'");' >> parameter_groups.py
	if [ "$NLGROUP" != "$LASTGROUP" ]; then
		echo 'group_order.append("'$NLGROUP'");' >> group_order.py
	fi

	LASTGROUP=$NLGROUP
done

chmod a+x parameter_groups.py
rm -f params groups.params

rm -f default_parameters.py
cat ${NAMELIST_PATH} | grep "config_" | awk '{print "default_parameters[\""$1"\"].append(\""$3"\")"}' >> default_parameters.py
chmod a+x default_parameters.py

