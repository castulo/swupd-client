#!/usr/bin/env bats

# Author: Castulo Martinez
# Email: castulo.martinez@intel.com

load "../testlib"

test_setup() {

	create_test_environment "$TEST_NAME"
	create_bundle -L -n test-bundle1 -f /foo/file1,/bar/file2 "$TEST_NAME"
	create_version -p "$TEST_NAME" 20 10
	update_bundle "$TEST_NAME" os-core --update /core
	update_bundle "$TEST_NAME" test-bundle1 --update /bar/file2
	sudo rm "$WEBDIR"/20/pack*

}

@test "UPD058: missing packs" {

	# <If necessary add a detailed explanation of the test here>

	run sudo sh -c "$SWUPD update $SWUPD_OPTS"

	assert_status_is "$SWUPD_OK"
	# expected_output=$(cat <<-EOM
	# 	<expected output>
	# EOM
	# )
	# assert_is_output "$expected_output"

}
