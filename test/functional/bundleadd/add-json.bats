#!/usr/bin/env bats

# Author: Castulo Martinez
# Email: castulo.martinez@intel.com

load "../testlib"

test_setup() {

	create_test_environment "$TEST_NAME"
	test_files="/file1,/file2,/file3,/file4,/file5,/file6,/file7,/file8,/file9,/file10,/file11"
	create_bundle -n test-bundle -f "$test_files" "$TEST_NAME"

}

@test "ADD049: Adding a bundle using machine readable output" {

	# the --json-output flag can be used so all the output of the bundle-add
	# command is created as a JSON stream that can be read and parsed by other
	# applications interested into knowing real time status of the command
	# (for example installer so it can provide the user a status of the install process)

	run sudo sh -c "$SWUPD bundle-add --json-output $SWUPD_OPTS_PROGRESS test-bundle"

	assert_status_is 0
	expected_output1=$(cat <<-EOM
		[
		{ "type" : "start", "section" : "bundle-add" },
		{ "type" : "info", "msg" : "Loading required manifests..." },
		{ "type" : "progress", "currentStep" : 1, "totalSteps" : 8, "stepCompletion" : -1, "stepDescription" : "load_manifests" },
		{ "type" : "progress", "currentStep" : 1, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "load_manifests" },
		{ "type" : "progress", "currentStep" : 2, "totalSteps" : 8, "stepCompletion" : 0, "stepDescription" : "download_packs" },
		{ "type" : "info", "msg" : "Downloading packs for:" },
		{ "type" : "info", "msg" : " - test-bundle" },
	EOM
	)
	expected_output2=$(cat <<-EOM
		{ "type" : "progress", "currentStep" : 2, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "download_packs" },
		{ "type" : "info", "msg" : "Finishing packs extraction..." },
		{ "type" : "progress", "currentStep" : 3, "totalSteps" : 8, "stepCompletion" : -1, "stepDescription" : "extract_packs" },
		{ "type" : "progress", "currentStep" : 3, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "extract_packs" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 0, "stepDescription" : "validate_fullfiles" },
		{ "type" : "info", "msg" : "Validate downloaded files" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 6, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 12, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 18, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 25, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 31, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 37, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 43, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 50, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 56, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 62, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 68, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 75, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 81, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 87, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 93, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 4, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "validate_fullfiles" },
		{ "type" : "progress", "currentStep" : 5, "totalSteps" : 8, "stepCompletion" : 0, "stepDescription" : "download_fullfiles" },
		{ "type" : "info", "msg" : "No extra files need to be downloaded" },
		{ "type" : "progress", "currentStep" : 5, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "download_fullfiles" },
		{ "type" : "progress", "currentStep" : 6, "totalSteps" : 8, "stepCompletion" : -1, "stepDescription" : "extract_fullfiles" },
		{ "type" : "progress", "currentStep" : 6, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "extract_fullfiles" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 0, "stepDescription" : "install_files" },
		{ "type" : "info", "msg" : "Installing files..." },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 3, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 6, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 9, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 12, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 15, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 18, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 21, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 25, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 28, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 31, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 34, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 37, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 40, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 43, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 46, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 50, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 53, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 56, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 59, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 62, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 65, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 68, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 71, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 75, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 78, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 81, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 84, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 87, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 90, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 93, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 96, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 7, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "install_files" },
		{ "type" : "progress", "currentStep" : 8, "totalSteps" : 8, "stepCompletion" : -1, "stepDescription" : "run_postupdate_scripts" },
		{ "type" : "info", "msg" : "Calling post-update helper scripts" },
		{ "type" : "info", "msg" : "Successfully installed 1 bundle" },
		{ "type" : "progress", "currentStep" : 8, "totalSteps" : 8, "stepCompletion" : 100, "stepDescription" : "run_postupdate_scripts" },
		{ "type" : "end", "section" : "bundle-add", "status" : 0 }
		]
	EOM
	)
	assert_in_output "$expected_output1"
	assert_in_output "$expected_output2"

}
