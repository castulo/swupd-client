#!/usr/bin/env bats

# Author: Castulo Martinez
# Email: castulo.martinez@intel.com

load "../testlib"

test_setup() {

	create_test_environment "$TEST_NAME"
	create_bundle -n test-bundle-upstream -f /file_upstream "$TEST_NAME"

	# create a couple of 3rd-party repos with bundles
	create_third_party_repo "$TEST_NAME" 10 staging repo1
	create_bundle    -n test-bundle1 -f /foo/file_1A -u repo1 "$TEST_NAME"
	create_bundle -L -n test-bundle2 -f /bar/file_2  -u repo1 "$TEST_NAME"

	create_third_party_repo "$TEST_NAME" 10 staging repo2
	create_bundle    -n test-bundle1 -f /baz/file_1B -u repo2 "$TEST_NAME"
	create_bundle -L -n test-bundle3 -f /baz/file_3  -u repo2 "$TEST_NAME"

}

@test "TPR018: List installed 3rd-party bundles" {

	# When a user list 3rd-party bundles without specifiying a repo, all
	# installed bundles from 3rd-party repos should be shown

	run sudo sh -c "$SWUPD 3rd-party bundle-list $SWUPD_OPTS"

	assert_status_is "$SWUPD_OK"
	# expected_output=$(cat <<-EOM
	# 	<expected output>
	# EOM
	# )
	# assert_is_output "$expected_output"

}

@test "TPR019: List all available 3rd-party bundles" {

	# users should be able to list all 3rd-party bundles without specifiying a repo,
	# all available bundles should be displayed

	run sudo sh -c "$SWUPD 3rd-party bundle-list --all $SWUPD_OPTS"

	assert_status_is "$SWUPD_OK"
	# expected_output=$(cat <<-EOM
	# 	<expected output>
	# EOM
	# )
	# assert_is_output "$expected_output"

}

@test "TPR020: List installed 3rd-party bundles from a specific repo" {

	# users should be able to list installed 3rd-party bundles from a specific repo

	run sudo sh -c "$SWUPD 3rd-party bundle-list --repo repo2 $SWUPD_OPTS"

	assert_status_is "$SWUPD_OK"
	# expected_output=$(cat <<-EOM
	# 	<expected output>
	# EOM
	# )
	# assert_is_output "$expected_output"

}

@test "TPR021: List all available 3rd-party bundles from a specific repo" {

	# users should be able to list all 3rd-party bundles from a specific repo

	run sudo sh -c "$SWUPD 3rd-party bundle-list --all --repo repo1 $SWUPD_OPTS"

	assert_status_is "$SWUPD_OK"
	# expected_output=$(cat <<-EOM
	# 	<expected output>
	# EOM
	# )
	# assert_is_output "$expected_output"

}
