#!/usr/bin/env bats

# Author: Castulo Martinez
# Email: castulo.martinez@intel.com

load "../testlib"

test_setup() {

	create_test_environment -r "$TEST_NAME" 10 1
	versionurl_hash=$(sudo "$SWUPD" hashdump --quiet "$TARGETDIR"/usr/share/defaults/swupd/versionurl)
	sudo cp "$TARGETDIR"/usr/share/defaults/swupd/versionurl "$WEBDIR"/10/files/"$versionurl_hash"
	versionurl="$WEBDIR"/10/files/"$versionurl_hash"
	contenturl_hash=$(sudo "$SWUPD" hashdump --quiet "$TARGETDIR"/usr/share/defaults/swupd/contenturl)
	sudo cp "$TARGETDIR"/usr/share/defaults/swupd/contenturl "$WEBDIR"/10/files/"$contenturl_hash"
	contenturl="$WEBDIR"/10/files/"$contenturl_hash"
	create_bundle -L -n os-core-update -f /usr/share/defaults/swupd/versionurl:"$versionurl",/usr/share/defaults/swupd/contenturl:"$contenturl" "$TEST_NAME"
	create_bundle -L -n test-bundle1 -f /foo/file_1,/bar/file_2 "$TEST_NAME"
	create_version "$TEST_NAME" 20 10 1
	update_bundle -p "$TEST_NAME" test-bundle1 --update /foo/file_1
	update_bundle -p "$TEST_NAME" test-bundle1 --delete /bar/file_2
	update_bundle "$TEST_NAME" test-bundle1 --add /baz/bat/file_3

}

test_teardown() {

	# return the files to mutable state
	if [ -e "$TARGETDIR"/usr/untracked_file ]; then
		sudo chattr -i "$TARGETDIR"/usr/untracked_file
	fi
	if [ -e "$TARGETDIR"/baz ]; then
		sudo chattr -i "$TARGETDIR"/baz
	fi

}

@test "API057: repair (nothing to repair)" {

	run sudo sh -c "$SWUPD repair $SWUPD_OPTS --picky --quiet"

	assert_status_is "$SWUPD_OK"
	assert_output_is_empty

}

@test "API058: repair" {

	# add things to be repaired
	set_current_version "$TEST_NAME" 20
	sudo touch "$TARGETDIR"/usr/untracked_file

	run sudo sh -c "$SWUPD repair $SWUPD_OPTS --picky --quiet"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		$PATH_PREFIX/baz
		$PATH_PREFIX/baz/bat
		$PATH_PREFIX/baz/bat/file_3
		$PATH_PREFIX/foo/file_1
		$PATH_PREFIX/usr/lib/os-release
		$PATH_PREFIX/bar/file_2
		$PATH_PREFIX/usr/untracked_file
	EOM
	)
	assert_is_output --identical "$expected_output"

}

@test "API059: repair (failure to repair)" {

	# force some repairs in the target system
	set_current_version "$TEST_NAME" 20
	sudo touch "$TARGETDIR"/usr/untracked_file

	# force failures while repairing
	sudo touch "$TARGETDIR"/baz
	sudo chattr +i "$TARGETDIR"/usr/untracked_file
	sudo chattr +i "$TARGETDIR"/baz

	run sudo sh -c "$SWUPD repair $SWUPD_OPTS --picky --quiet"

	assert_status_is_not "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Error: Target exists but is not a directory: $PATH_PREFIX/baz
		$PATH_PREFIX/baz/bat
		Error: Target has different file type but could not be removed: $PATH_PREFIX/baz
		Error: Target directory does not exist and could not be created: $PATH_PREFIX/baz/bat
		$PATH_PREFIX/baz/bat/file_3
		Error: Target has different file type but could not be removed: $PATH_PREFIX/baz
		$PATH_PREFIX/baz
		$PATH_PREFIX/foo/file_1
		$PATH_PREFIX/usr/lib/os-release
		$PATH_PREFIX/usr/untracked_file
	EOM
	)
	assert_is_output "$expected_output"

}
#WEIGHT=17