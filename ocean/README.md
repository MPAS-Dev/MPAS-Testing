Ocean Test Cases
================
Author: Doug Jacobsen

This directory is intended to allow some-what automated testing of mpas, using a set of test cases.


Provided in this directory are:
----------------------------------------------------------------------------------
	Test cases - in sub-directories
	Template Submit scripts - for each machine type
	A Control script - for automated handling of the test cases.

Each of these will be described below.


Test cases:
----------------------------------------------------------------------------------
	Within each default sub-directory there is a script, called makeMeshes.sh.
	This script is intended to set up all of the run directories, and generate
	any meshes that require generation. There is also a getErrors.sh script
	which can be used to compute the errors from a test case.

	The existing directories can be used as a template for setting up new test cases.

	To add a new test case, currently one would have to create a makeMeshes.sh script 
	that takes as input three arguments.
		1) the full path to the mpas exeuctable
		2) the full path to the run.info file
		3) a list of processor numbers in quotes
	This script then generates a directory structure with all the files required for 
	mpas to run. And writes a new file called run_paths which contains the full paths
	to each of the run directories. It creates a directory for each combination of
	mesh and processor number.

	Typical run directories are built in each test case directory, to be used in a 
	stand-alone fashion.

	Batch runs are placed under this "typical use case" directory, within the .batch_runs
	directory.


Template submit scripts:
----------------------------------------------------------------------------------
	These files have the following naming scheme:
		machinename_submit_template.sh
	The existing templates can be used to help generate templates for different machines.
	They are used in the driver script for submitting jobs to a queue.


Control script:
----------------------------------------------------------------------------------
	This script is named:
		oceanTestCases.sh

	Before using it, several variables need to be set up in the scripts preamble.
	Two variables with need to be set up are:
		REPOSITORY_ADDRESS
		COMPILE_SET
	but there are other variables that can be configured for use in clusters.

	It's usage is as follows:
		`./oceanTestCases.sh [action] [test_case] [compile_set]`
	
	Action can be any of the following:
		`setup`
		`submit`
		`postprocess`
		`clean`
	
	Case can be any sub-directory. This script assumes it was set up properly (as the existing test_cases are).
	The only exception is that case can also be mpas. A case of mpas can only be used when the action is clean.

	Compile_Set can be any valid compile set in MPAS' Makefile. It is only used if MPAS needs to be setup.

	The actions are described below:
		`setup:`
			This is meant to create and initialize all of the run directories for a given
			test case. This is done by running the makeMeshes.sh script in the test case directory.

			This should be called for a case before the other options can really do anything
			for that case.

			On first call this script checks out mpas, using a given repository address, and compiles it
			using a given compiler set.
		`submit:`
			This action submits all of the jobs to the queue using the machinename_submit_template.sh script
			as a template for generating all of the submit scripts.

			It also generates three files, cancel_jobs_[case].sh, start_times_[case].sh, and job_ids_[case].
			Which can be used to cancel all of the jobs, check the time until the jobs start, and see all of the
			job ids, respectively.
		`postprocess:`
			Currently this action generates three files which are used to evaluate the runs.
			timing_results_[case].txt
			timing_results2_[case].txt
			timing_results3_[case].txt

			If a getErrors.sh script is present in the test case directory, it is run to compute errors.
			The names of the error files are different for each test case, but they should end with .erorrs
			to allow the clean action to remove them from the test case directory.
		`clean:`
			This action cleans the [case] directory as if it was cleanly checked out.

	As an example, one can use the following usage to setup, perform, and process the lock_exchange test_case.
		`./oceanTestCases.sh setup lock_exchange`
		`./oceanTestCases.sh submit lock_exchange`
		`./oceanTestCases.sh postprocess lock_exchange`
	Then, to clean the test cases directory after you are finish you can use
	 	`./oceanTestCases.sh clean lock_exchange`

	Case can be entered using tab completion of a directory name (including the /). The / will be stripped from the case name,
	so it will not cause any issues.

