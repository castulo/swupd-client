#!bin/bash

FUNC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILENAME=$(basename "$BATS_TEST_FILENAME")
TEST_NAME=${TEST_FILENAME%.bats}
THEME_DIRNAME="$BATS_TEST_DIRNAME"

export TEST_NAME
export THEME_DIRNAME
export FUNC_DIR
export SWUPD_DIR="$FUNC_DIR/../.."
export SWUPD="$SWUPD_DIR/swupd"

# Error codes
export EBUNDLE_MISMATCH=2  # at least one local bundle mismatches from MoM
export EBUNDLE_REMOVE=3  # cannot delete local bundle filename
export EMOM_NOTFOUND=4  # MoM cannot be loaded into memory (this could imply network issue)
export ETYPE_CHANGED_FILE_RM=5  # do_staging() couldn't delete a file which must be deleted
export EDIR_OVERWRITE=6  # do_staging() couldn't overwrite a directory
export EDOTFILE_WRITE=7  # do_staging() couldn't create a dotfile
export ERECURSE_MANIFEST=8  # error while recursing a manifest
export ELOCK_FILE=9  # cannot get the lock
export ECURL_INIT=11  # cannot initialize curl agent
export EINIT_GLOBALS=12  # cannot initialize globals
export EBUNDLE_NOT_TRACKED=13  # bundle is not tracked on the system
export EMANIFEST_LOAD=14  # cannot load manifest into memory
export EINVALID_OPTION=15  # invalid command option
export ENOSWUPDSERVER=16  # no net connection to swupd server
export EFULLDOWNLOAD=17  # full_download problem
export ENET404=404  # download 404'd
export EBUNDLE_INSTALL=18  # Cannot install bundles
export EREQUIRED_DIRS=19  # Cannot create required dirs
export ECURRENT_VERSION=20  # Cannot determine current OS version
export ESIGNATURE=21  # Cannot initialize signature verification
export EBADTIME=22  # System time is bad
export EDOWNLOADPACKS=23  # Pack download failed
export EBADCERT=24  # unable to verify server SSL certificate

# global constant
export zero_hash="0000000000000000000000000000000000000000000000000000000000000000"

generate_random_content() { 

	local bottom_range=${1:-5}
	local top_range=${2:-100}
	local range=$((top_range - bottom_range + 1))
	local number_of_lines=$((RANDOM%range+$bottom_range))
	< /dev/urandom tr -dc 'a-zA-Z0-9-_!@#$%^&*()_+{}|:<>?=' | fold -w 100 | head -n $number_of_lines

}

generate_random_name() { 

	local prefix=${1:-test-}
	local uuid
	
	# generate random 8 character alphanumeric string (lowercase only)
	uuid=$(< /dev/urandom tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
	echo "$prefix$uuid"

}

print_stack() {

	echo "An error occurred"
	echo "Function stack (most recent on top):"
	for func in ${FUNCNAME[*]}; do
		if [ "$func" != "print_stack" ] && [ "$func" != "terminate" ]; then
			echo -e "\\t$func"
		fi
	done

}

terminate() {

	# since the library could be sourced and run from an interactive shell
	# not only from a script, we cannot use exit in interactive shells since it
	# would terminate the shell, so we are using parameter expansion with a fake
	# parameter "param" to force an error when running interactive shells
	local msg=$1
	local param
	case "$-" in
		*i*)	print_stack
				: "${param:?"$msg, exiting..."}" ;;
		*)		print_stack
				echo "$msg, exiting..."
				exit 1;;
	esac

}

validate_path() { 

	local path=$1
	if [ -z "$path" ] || [ ! -d "$path" ]; then
		terminate "Please provide a valid path"
	fi

}

validate_item() { 

	local vfile=$1
	if [ -z "$vfile" ] || [ ! -e "$vfile" ]; then
		terminate "Please provide a valid file"
	fi

}

validate_param() {

	local param=$1
	if [ -z "$param" ]; then
		terminate "Mandatory parameter missing"
	fi

}

# Writes to a file that is owned by root
# Parameters:
# - "-a": if set, the text will be appeneded to the file,
#         otherwise will be overwritten
# - FILE: the path to the file to write to
# - STREAM: the content to be written
write_to_protected_file() {

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    write_to_protected_file [-a] <file> <stream>

			Options:
			    -a    If used the text will be appended to the file, otherwise it will be overwritten
			EOM
		return
	fi
	local arg
	[ "$1" = "-a" ] && { arg=-a ; shift ; }
	local file=${1?Missing output file in write_to_protected_file}
	shift
	printf "$@" | sudo tee $arg "$file" >/dev/null

}

# Exports environment variables that are dependent on the test environment
# Parameters:
# - ENV_NAME: the name of the test environment
set_env_variables() {

	local env_name=$1
	local path
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    set_env_variables <environment_name>
			EOM
		return
	fi
	validate_path "$env_name"
	path=$(dirname "$(realpath "$env_name")")

	export SWUPD_OPTS="-S $path/$env_name/state -p $path/$env_name/target-dir -F staging -u file://$path/$env_name/web-dir -C $FUNC_DIR/Swupd_Root.pem -I"
	export SWUPD_OPTS_NO_CERT="-S $path/$env_name/state -p $path/$env_name/target-dir -F staging -u file://$path/$env_name/web-dir"
	export SWUPD_OPTS_MIRROR="-p $path/$env_name/target-dir"
	export SWUPD_OPTS_NO_FMT="-S $path/$env_name/state -p $path/$env_name/target-dir -u file://$path/$env_name/web-dir -C $FUNC_DIR/Swupd_Root.pem -I"
	export TEST_DIRNAME="$path"/"$env_name"
	export WEBDIR="$env_name"/web-dir
	export TARGETDIR="$env_name"/target-dir
	export STATEDIR="$env_name"/state

}

# Creates a directory with a hashed name in the specified path, if a directory
# already exists it returns the name
# Parameters:
# - PATH: the path where the directory will be created 
create_dir() { 
	
	local path=$1
	local hashed_name
	local directory

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_dir <path>
			EOM
		return
	fi
	validate_path "$path"
	
	# most directories have the same hash, so we only need one directory
	# in the files directory, if there is already one just return the path/name
	directory=$(find "$path"/* -type d 2> /dev/null)
	if [ ! "$directory" ]; then
		sudo mkdir "$path"/testdir
		hashed_name=$(sudo "$SWUPD" hashdump "$path"/testdir 2> /dev/null)
		sudo mv "$path"/testdir "$path"/"$hashed_name"
		# since tar is all we use, create a tar for the new dir
		create_tar "$path"/"$hashed_name"
		directory="$path"/"$hashed_name"
	fi
	echo "$directory"

}

# Generates a file with a hashed name in the specified path
# Parameters:
# - PATH: the path where the file will be created    
create_file() {
 
	local path=$1
	local hashed_name

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_file <path>
			EOM
		return
	fi
	validate_path "$path"

	generate_random_content | sudo tee "$path/testfile" > /dev/null
	hashed_name=$(sudo "$SWUPD" hashdump "$path"/testfile 2> /dev/null)
	sudo mv "$path"/testfile "$path"/"$hashed_name"
	# since tar is all we use, create a tar for the new file
	create_tar "$path"/"$hashed_name"
	echo "$path/$hashed_name"

}

# Creates a symbolic link with a hashed name to the specified file in the specified path.
# If no existing file is specified to point to, a new file will be created and pointed to
# by the link.
# If a file is provided but doesn't exist, then a dangling file will be created
# Parameters:
# - PATH: the path where the symbolic link will be created
# - FILE: the path to the file to point to
create_link() { 

	local path=$1
	local pfile=$2
	local hashed_name

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_link <path> [file_to_point_to]
			EOM
		return
	fi
	validate_path "$path"
	
	# if no file is specified, create one
	if [ -z "$pfile" ]; then
		pfile=$(create_file "$path")
	fi
	sudo ln -rs "$pfile" "$path"/testlink
	hashed_name=$(sudo "$SWUPD" hashdump "$path"/testlink 2> /dev/null)
	sudo mv "$path"/testlink "$path"/"$hashed_name"
	create_tar --skip-validation "$path"/"$hashed_name"
	echo "$path/$hashed_name"

}

# Creates a tar for the specified item in the same location
# Parameters:
# - --skip-validation: if this flag is set (as first parameter) the other parameter
#                      is not validated, so use this option carefully
# - ITEM: the relative path to the item (file, directory, link, manifest)
create_tar() {

	local path
	local item_name
	local skip_param_validation=false
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_tar [--skip-validation] <item>

			Options:
			    --skip-validation    If set, the function parameters will not be validated
			EOM
		return
	fi
	[ "$1" = "--skip-validation" ] && { skip_param_validation=true ; shift ; }
	local item=$1

	if [ "$skip_param_validation" = false ]; then
		validate_item "$item"
	fi

	path=$(dirname "$(realpath "$item")")
	item_name=$(basename "$item")
	# if the item is a directory exclude its content when taring
	if [ -d "$item" ]; then
		sudo tar -C "$path" -cf "$path"/"$item_name".tar --exclude="$item_name"/* "$item_name"
	else
		sudo tar -C "$path" -cf "$path"/"$item_name".tar "$item_name"
	fi

}

# Creates an empty manifest in the specified path
# Parameters:
# - PATH: the path where the manifest will be created
# - BUNDLE_NAME: the name of the bundle which this manifest will be for
create_manifest() {

	local path=$1
	local name=$2
	local version

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_manifest <path> <bundle_name>
			EOM
		return
	fi
	validate_path "$path"
	validate_param "$name"

	version=$(basename "$path")
	{
		printf 'MANIFEST\t1\n'
		printf 'version:\t%s\n' "$version"
		printf 'previous:\t0\n'
		printf 'filecount:\t0\n'
		printf 'timestamp:\t%s\n' "$(date +"%s")"
		printf 'contentsize:\t0\n'
		printf '\n'
	} | sudo tee "$path"/Manifest."$name" > /dev/null
	echo "$path/Manifest.$name"
	
}

# Re-creates a manifest's tar, updates the hashes in the MoM and signs it
# Parameters:
# - MANIFEST: the manifest file to have its tar re-created
retar_manifest() {

	local manifest=$1
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    retar_manifest <manifest>
			EOM
		return
	fi
	validate_item "$manifest"

	sudo rm -f "$manifest".tar
	create_tar "$manifest"
	# if the modified manifest is the MoM, sign it again
	if [ "$(basename "$manifest")" = Manifest.MoM ]; then
		sudo rm -f "$manifest".sig
		sign_manifest "$manifest"
	else
		# update hashes in MoM, re-creates tar and re-signs MoM
		update_hashes_in_mom "$(dirname "$manifest")"/Manifest.MoM
	fi

}

# Adds the specified item to an existing bundle manifest
# Parameters:
# - --skip-validation: if this flag is set (as first parameter) the other parameters
#                      are not validated, so use this option carefully
# - -p: if the p (partial) flag is set the function skips updating the hashes
#       in the MoM, this is useful if more changes are to be done in order to
#       reduce time
# - MANIFEST: the relative path to the manifest file
# - ITEM: the relative path to the item (file, directory, symlink) to be added
# - PATH_IN_FS: the absolute path of the item in the target system when installed
add_to_manifest() { 

	local item_type
	local item_size
	local name
	local version
	local filecount
	local contentsize
	local linked_file
	local boot_type="."
	local file_path
	local skip_param_validation=false
	[ "$1" = "--skip-validation" ] && { skip_param_validation=true ; shift ; }
	local partial=false
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	local manifest=$1
	local item=$2
	local item_path=$3

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    add_to_manifest [--skip-validation] <manifest> <item> <item_path_in_fs>

			Options:
			    --skip-validation    If set, the validation of parameters will be skipped
			    -p                   If set (partial), the item will be added to the manifest, but the
			                         manifest's tar won't be re-created. If the manifest being updated
			                         is the MoM, it won't be re-signed either. This is useful if more
			                         updates are to be done in the manifest to avoid extra processing

			    NOTE: if both options --skip-validation and -p are to be used, they must be specified in
			          that order or one option will be ignored.
			EOM
		return
	fi

	if [ "$skip_param_validation" = false ]; then
		validate_item "$manifest"
		validate_item "$item"
		validate_param "$item_path"
	fi

	item_size=$(stat -c "%s" "$item")
	name=$(basename "$item")
	version=$(basename "$(dirname "$manifest")")
	# add to filecount
	filecount=$(awk '/filecount/ { print $2}' "$manifest")
	filecount=$((filecount + 1))
	sudo sed -i "s/filecount:.*/filecount:\\t$filecount/" "$manifest"
	# add to contentsize 
	contentsize=$(awk '/contentsize/ { print $2}' "$manifest")
	contentsize=$((contentsize + item_size))
	# get the item type
	if [ "$(basename "$manifest")" = Manifest.MoM ]; then
		item_type=M
		# MoM has a contentsize of 0, so don't increase this for MoM
		contentsize=0
		# files, directories and links are stored already hashed, but since
		# manifests are not stored hashed, we need to calculate the hash
		# of the manifest before adding it to the MoM
		name=$(sudo "$SWUPD" hashdump "$item" 2> /dev/null)
	elif [ -L "$item" ]; then
		item_type=L
		# when adding a link to a bundle, we need to make sure we add
		# its associated file too, unless it is a dangling link
		linked_file=$(readlink "$item")
		if [ -e "$(dirname "$item")"/"$linked_file" ]; then
			if [ ! "$(sudo cat "$manifest" | grep "$linked_file")" ]; then
				file_path="$(dirname "$item_path")"
				if [ "$file_path" = "/" ]; then
					file_path=""
				fi
				add_to_manifest -p "$manifest" "$(dirname "$item")"/"$linked_file" "$file_path"/"$(generate_random_name test-file-)"
			fi
		fi
	elif [ -f "$item" ]; then
		item_type=F
	elif [ -d "$item" ]; then
		item_type=D
	fi
	# if the file is in the /usr/lib/{kernel, modules} dir then it is a boot file
	if [ "$(dirname "$item_path")" = "/usr/lib/kernel" ] || [ "$(dirname "$item_path")" = "/usr/lib/modules/" ]; then
		boot_type="b"
	fi
	sudo sed -i "s/contentsize:.*/contentsize:\\t$contentsize/" "$manifest"
	# add to manifest content
	write_to_protected_file -a "$manifest" "$item_type.$boot_type.\\t$name\\t$version\\t$item_path\\n"
	# If a manifest tar already exists for that manifest, renew the manifest tar unless specified otherwise
	if [ "$partial" = false ]; then
		retar_manifest "$manifest"
	fi

}

# Adds the specified bundle dependency to an existing bundle manifest
# Parameters:
# - -p: if the p (partial) flag is set the function skips updating the hashes
#       in the MoM, and re-creating the tar, this is useful if more changes are
#       to be done in order to reduce time
# - MANIFEST: the relative path to the manifest file
# - DEPENDENCY: the name of the bundle to be included as a dependency
add_dependency_to_manifest() {

	local partial=false
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	local manifest=$1
	local dependency=$2
	local path
	local manifest_name
	local version
	local pre_version
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    add_dependency_to_manifest <manifest> <dependency>

			Options:
			    -p    If set (partial), the dependency will be added to the manifest,
			          but the manifest's tar won't be re-created, nor the hash in the
			          MoM will be updated either. This is useful if more updates are
			          to be done in the manifest to avoid extra processing
			EOM
		return
	fi
	validate_item "$manifest"
	validate_param "$dependency"

	path=$(dirname "$(dirname "$manifest")")
	version=$(basename "$(dirname "$manifest")")
	manifest_name=$(basename "$manifest")

	# if the provided manifest does not exist in the current version, it means
	# we need to copy it from a previous version.
	# this could happen for example if a manifest is created in one version (e.g. 10),
	# but the dependency should be added in a different, future version (e.g. 20)
	if [ ! -e "$path"/"$version"/"$manifest_name" ]; then
		pre_version="$version"
		while [ "$pre_version" -gt 0 ] && [ ! -e "$path"/"$pre_version"/"$manifest_name" ]; do
				pre_version=$(awk '/previous/ { print $2 }' "$path"/"$pre_version"/Manifest.MoM)
		done
		sudo cp "$path"/"$pre_version"/"$manifest_name" "$path"/"$version"/"$manifest_name"
		update_manifest -p "$manifest" version "$version"
		update_manifest -p "$manifest" previous "$pre_version"
	fi
	update_manifest -p "$manifest" timestamp "$(date +"%s")"
	sudo sed -i "/contentsize:.*/a includes:\\t$dependency" "$manifest"
	# If a manifest tar already exists for that manifest, renew the manifest tar
	# unless specified otherwise
	if [ "$partial" = false ]; then
		retar_manifest "$manifest"
	fi

}

# Removes the specified item from an existing bundle manifest
# Parameters:
# - -p: if the p (partial) flag is set the function skips updating the hashes
#       in the MoM, and re-creating the tar, this is useful if more changes are
#       to be done in order to reduce time
# - MANIFEST: the relative path to the manifest file
# - ITEM: either the hash or filename of the item to be removed
remove_from_manifest() { 

	local partial=false
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	local manifest=$1
	local item=$2
	local filecount
	local contentsize
	local item_size
	local item_hash
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    remove_from_manifest <manifest> <item>

			Options:
			    -p    If set (partial), the item will be removed from the manifest,
			          but the manifest's tar won't be re-created, nor the hash in
			          the MoM will be updated either. This is useful if more updates
			          are to be done in the manifest to avoid extra processing
			EOM
		return
	fi
	validate_item "$manifest"
	validate_param "$item"

	# replace every / with \/ in item (if any)
	item="${item////\\/}"
	# decrease filecount and contentsize
	filecount=$(awk '/filecount/ { print $2}' "$manifest")
	filecount=$((filecount - 1))
	update_manifest -p "$manifest" filecount "$filecount"
	if [ "$(basename "$manifest")" != Manifest.MoM ]; then
		contentsize=$(awk '/contentsize/ { print $2}' "$manifest")
		item_hash=$(get_hash_from_manifest "$manifest" "$item")
		item_size=$(stat -c "%s" "$(dirname "$manifest")"/files/"$item_hash")
		contentsize=$((contentsize - item_size))
		update_manifest -p "$manifest" contentsize "$contentsize"
	fi
	# remove the lines that match from the manifest
	sudo sed -i "/\\t$item$/d" "$manifest"
	sudo sed -i "/\\t$item\\t/d" "$manifest"
	# If a manifest tar already exists for that manifest, renew the manifest tar
	# unless specified otherwise
	if [ "$partial" = false ]; then
		retar_manifest "$manifest"
	fi

}

# Updates fields in an existing manifest
# Parameters:
# - -p: if the p (partial) flag is set the function skips updating the hashes
#       in the MoM, this is useful if more changes are to be done in order to
#       reduce time
# - MANIFEST: the relative path to the manifest file
# - KEY: the thing to be updated
# - HASH/NAME: the file name or hash of the record to be updated (if applicable)
# - VALUE: the value to be used for updating the record
update_manifest() {

	local partial=false
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	local manifest=$1
	local key=$2
	local var=$3
	local value=$4
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    update_manifest [-p] <manifest> <format | version | previous | filecount | timestamp | contentsize> <new_value>
			    update_manifest [-p] <manifest> <file-status | file-hash | file-version | file-name> <file_hash or file_name> <new_value>

			Options:
			    -p    if the p flag is set (partial), the function skips updating the MoM's hashes, creating
			          a tar for the MoM and signing it. It also skips creating the tar for the modified manifest,
			          this is useful if more updates are to be done in the manifest to avoid extra processing
			EOM
		return
	fi
	validate_item "$manifest"
	validate_param "$key"
	validate_param "$var"

	var="${var////\\/}"
	value="${value////\\/}"

	case "$key" in
	format)
		sudo sed -i "s/MANIFEST.*/MANIFEST\\t$var/" "$manifest"
		;;
	version | previous | filecount | timestamp | contentsize)
		sudo sed -i "s/$key.*/$key:\\t$var/" "$manifest"
		;;
	file-status)
		validate_param "$value"
		sudo sed -i "/\\t$var$/s/....\(\\t.*\\t.*\\t.*$\)/$value\1/g" "$manifest"
		sudo sed -i "/\\t$var\\t/s/....\(\\t.*\\t.*\\t.*$\)/$value\1/g" "$manifest"
		;;
	file-hash)
		validate_param "$value"
		sudo sed -i "/\\t$var$/s/\(....\\t\).*\(\\t.*\\t\)/\1$value\2/g" "$manifest"
		sudo sed -i "/\\t$var\\t/s/\(....\\t\).*\(\\t.*\\t\)/\1$value\2/g" "$manifest"
		;;
	file-version)
		validate_param "$value"
		sudo sed -i "/\\t$var$/s/\(....\\t.*\\t\).*\(\\t\)/\1$value\2/g" "$manifest"
		sudo sed -i "/\\t$var\\t/s/\(....\\t.*\\t\).*\(\\t\)/\1$value\2/g" "$manifest"
		;;
	file-name)
		validate_param "$value"
		sudo sed -i "/\\t$var$/s/\(....\\t.*\\t.*\\t\).*/\1$value/g" "$manifest"
		sudo sed -i "/\\t$var\\t/s/\(....\\t.*\\t.*\\t\).*/\1$value/g" "$manifest"
		;;
	*)
		terminate "Please select a valid key for updating the manifest"
		;;
	esac
	# update bundle tars and MoM (unless specified otherwise)
	if [ "$partial" = false ]; then
		retar_manifest "$manifest"
	fi

}

# Recalculate the hashes of the elements in the specified MoM and updates it
# if there are changes in hashes.
# Parameters:
# - MANIFEST: the path to the MoM to be updated
update_hashes_in_mom() {

	local manifest=$1
	local path
	local bundles
	local bundle
	local bundle_old_hash
	local bundle_new_hash
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    update_hashes_in_mom <manifest>
			EOM
		return
	fi
	validate_item "$manifest"
	path=$(dirname "$manifest")

	IFS=$'\n'
	if [ "$(basename "$manifest")" = Manifest.MoM ]; then
		bundles=("$(sudo cat "$manifest" | grep -x "M\.\.\..*" | awk '{ print $4 }')")
		for bundle in ${bundles[*]}; do
			# if the hash of the manifest changed, update it
			bundle_old_hash=$(get_hash_from_manifest "$manifest" "$bundle")
			bundle_new_hash=$(sudo "$SWUPD" hashdump "$path"/Manifest."$bundle" 2> /dev/null)
			if [ "$bundle_old_hash" != "$bundle_new_hash" ] && [ "$bundle_new_hash" != "$zero_hash" ]; then
				# replace old hash with new hash
				sudo sed -i "/\\t$bundle_old_hash\\t/s/\(....\\t\).*\(\\t.*\\t\)/\1$bundle_new_hash\2/g" "$manifest"
				# replace old version with new version
				sudo sed -i "/\\t$bundle_new_hash\\t/s/\(....\\t.*\\t\).*\(\\t\)/\1$(basename "$path")\2/g" "$manifest"
			fi
		done
		# re-order items on the manifest so they are in the correct order based on version
		sudo sort -t$'\t' -k3 -s -h -o "$manifest" "$manifest"
		# since the MoM has changed, sign it again and update its tar
		retar_manifest "$manifest"
	else
		echo "The provided manifest is not the MoM"
		return 1
	fi
	unset IFS

}

# Signs a manifest with a PEM key and generates the signed manifest in the same location
# Parameters:
# - MANIFEST: the path to the manifest to be signed
sign_manifest() {

	local manifest=$1

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    sign_manifest <manifest>
			EOM
		return
	fi
	validate_item "$manifest"

	sudo openssl smime -sign -binary -in "$manifest" \
    -signer "$FUNC_DIR"/Swupd_Root.pem \
    -inkey "$FUNC_DIR"/private.pem \
    -outform DER -out "$(dirname "$manifest")"/Manifest.MoM.sig
}

# Retrieves the hash value of a file or directory in a manifest
# Parameters:
# - MANIFEST: the manifest in which it will be looked at
# - ITEM: the dir or file to look for in the manifest
get_hash_from_manifest() {

	local manifest=$1
	local item=$2
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    get_hash_from_manifest <manifest> <name_in_fs>
			EOM
		return
	fi
	validate_item "$manifest"
	validate_param "$item"

	hash=$(sudo cat "$manifest" | grep $'\t'"$item"$ | awk '{ print $2 }')
	echo "$hash"

}

# Sets the current version of the target system to the desired version
# Parameters:
# - ENVIRONMENT_NAME: the name of the test environmnt to act upon
# - NEW_VERSION: the version for the target to be set to
set_current_version() {

	local env_name=$1
	local new_version=$2

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		echo "$(cat <<-EOM
			Usage:
			    set_current_version <environment_name> <new_version>
			EOM
		)"
		return
	fi
	validate_path "$env_name"

	sudo sed -i "s/VERSION_ID=.*/VERSION_ID=$new_version/" "$env_name"/target-dir/usr/lib/os-release

}

# Sets the latest version on the "server" to the desired version
# Parameters:
# - ENVIRONMENT_NAME: the name of the test environmnt to act upon
# - NEW_VERSION: the version for the target to be set to
set_latest_version() {

	local env_name=$1
	local new_version=$2

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    set_latest_version <environment_name> <new_version>
			EOM
		return
	fi
	validate_path "$env_name"

	write_to_protected_file "$env_name"/web-dir/version/formatstaging/latest "$new_version"

}

# Creates a new version of the server side content
# Parameters:
# - -p: if the p flag is set (partial), the function skips creating the MoM's
#       tar and signing it, this is useful if more changes are to be done in the
#       version in order to avoid extra processing
# - -r: if the r flag is set (release), the version is created with hashed os-release
#       and format files that can be used for creating updates
# - ENVIRONMENT_NAME: the name of the test environment
# - VERSION: the version of the server side content
# - FROM_VERSION: the previous version, if nothing is selected defaults to 0
# - FORMAT: the format to use for the version
create_version() {

	local partial=false
	local release_files=false
	# since this function is called with every test environment, some times multiple
	# times, use simple parsing of arguments instead of using getopts to keep light weight
	# with the caveat that arguments need to be provided in a specific order
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	[ "$1" = "-r" ] && { release_files=true ; shift ; }
	local env_name=$1
	local version=$2
	local from_version=${3:-0}
	local format=${4:-staging}
	local mom
	local hashed_name
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_version [-p] [-r] <environment_name> <new_version> [from_version] [format]

			Options:
			    -p    if the p flag is set (partial), the function skips creating the MoM's
			          tar and signing it, this is useful if more changes are to be done in the
			          new version in order to avoid extra processing
			    -r    if the r flag is set (release), the version is created with hashed os-release
			          and format files that can be used for creating updates

			Note: if both options -p and -r are to be used, they must be specified in that order or
			      one option will be ignored.
			EOM
		return
	fi
	validate_item "$env_name"
	validate_param "$version"

	# if the requested version already exists do nothing
	if [ -d "$env_name"/web-dir/"$version" ]; then
		echo "the requested version $version already exists"
		return
	fi

	sudo mkdir -p "$env_name"/web-dir/"$version"/{files,delta}
	sudo mkdir -p "$env_name"/web-dir/version/format"$format"
	write_to_protected_file "$env_name"/web-dir/version/format"$format"/latest "$version"
	if [ "$format" = staging ]; then
		format=1
	fi
	write_to_protected_file "$env_name"/web-dir/"$version"/format "$format"
	# create a new os-release file per version
	{
		printf 'NAME="Clear Linux Software for Intel Architecture"\n'
		printf 'VERSION=1\n'
		printf 'ID=clear-linux-os\n'
		printf 'VERSION_ID=%s\n' "$version"
		printf 'PRETTY_NAME="Clear Linux Software for Intel Architecture"\n'
		printf 'ANSI_COLOR="1;35"\n'
		printf 'HOME_URL="https://clearlinux.org"\n'
		printf 'SUPPORT_URL="https://clearlinux.org"\n'
		printf 'BUG_REPORT_URL="https://bugs.clearlinux.org/jira"\n'
	} | sudo tee "$env_name"/web-dir/"$version"/os-release > /dev/null
	# copy hashed versions of os-release and format to the files directory
	if [ "$release_files" = true ]; then
		hashed_name=$(sudo "$SWUPD" hashdump "$env_name"/web-dir/"$version"/os-release 2> /dev/null)
		sudo cp "$env_name"/web-dir/"$version"/os-release "$env_name"/web-dir/"$version"/files/"$hashed_name"
		create_tar "$env_name"/web-dir/"$version"/files/"$hashed_name"
		OS_RELEASE="$env_name"/web-dir/"$version"/files/"$hashed_name"
		export OS_RELEASE
		hashed_name=$(sudo "$SWUPD" hashdump "$env_name"/web-dir/"$version"/format 2> /dev/null)
		sudo cp "$env_name"/web-dir/"$version"/format "$env_name"/web-dir/"$version"/files/"$hashed_name"
		create_tar "$env_name"/web-dir/"$version"/files/"$hashed_name"
		FORMAT="$env_name"/web-dir/"$version"/files/"$hashed_name"
		export FORMAT
	fi
	# if the previous version is 0 then create a new MoM, otherwise copy the MoM
	# from the previous version
	if [ "$from_version" = 0 ]; then
		mom=$(create_manifest "$env_name"/web-dir/"$version" MoM)
		if [ "$partial" = false ]; then
			create_tar "$mom"
			sign_manifest "$mom"
		fi
	else
		sudo cp "$env_name"/web-dir/"$from_version"/Manifest.MoM "$env_name"/web-dir/"$version"
		mom="$env_name"/web-dir/"$version"/Manifest.MoM
		# update MoM info and create the tars
		update_manifest -p "$mom" format "$format"
		update_manifest -p "$mom" version "$version"
		update_manifest -p "$mom" previous "$from_version"
		update_manifest -p "$mom" timestamp "$(date +"%s")"
		if [ "$partial" = false ]; then
			create_tar "$mom"
			sign_manifest "$mom"
		fi
	fi

}

# Creates a test environment with the basic directory structure needed to
# validate the swupd client
# Parameters:
# - -e: if this option is set the test environment is created empty (withouth bundle os-core)
# - -r: if this option is set the test environment is created with a more complete version of
#       the os-core bundle that includes release files, it is useful for some tests like update tests
# - ENVIRONMENT_NAME: the name of the test environment, this should be typically the test name
# - VERSION: the version to use for the test environment, if not specified the default is 10
# - FORMAT: the format number to use initially in the environment
create_test_environment() { 

	local empty=false
	local release_files=false
	[ "$1" = "-e" ] && { empty=true ; shift ; }
	[ "$1" = "-r" ] && { release_files=true ; shift ; }
	local env_name=$1 
	local version=${2:-10}
	local format=${3:-staging}
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    create_test_environment [-e|-r] <environment_name> [initial_version] [format]

			Options:
			    -e    If set, the test environment is created empty, otherwise it will have
			          bundle os-core in the web-dir and installed by default.
			    -r    If set, the test environment is created with a more complete version of
			          the os-core bundle, a version that includes the os-release and format
			          files, so it is more useful for some tests, like update tests.

			Note: options -e and -r are mutually exclusive, so you can only use one at a time.
			EOM
		return
	fi
	validate_param "$env_name"
	
	# create all the files and directories needed
	# web-dir files & dirs
	sudo mkdir -p "$env_name"
	if [ "$release_files" = true ]; then
		create_version -p -r "$env_name" "$version" "0" "$format"
	else
		create_version -p "$env_name" "$version" "0" "$format"
	fi

	# target-dir files & dirs
	sudo mkdir -p "$env_name"/target-dir/usr/lib
	sudo cp "$env_name"/web-dir/"$version"/os-release "$env_name"/target-dir/usr/lib/os-release
	sudo mkdir -p "$env_name"/target-dir/usr/share/clear/bundles
	sudo mkdir -p "$env_name"/target-dir/usr/share/defaults/swupd
	sudo cp "$env_name"/web-dir/"$version"/format "$env_name"/target-dir/usr/share/defaults/swupd/format
	sudo mkdir -p "$env_name"/target-dir/etc

	# state files & dirs
	sudo mkdir -p "$env_name"/state/{staged,download,delta,telemetry}
	sudo chmod -R 0700 "$env_name"/state

	# export environment variables that are dependent of the test env
	set_env_variables "$env_name"

	# every environment needs to have at least the os-core bundle so this should be
	# added by default to every test environment unless specified otherwise
	if [ "$empty" = false ]; then
		if [ "$release_files" = true ]; then
			create_bundle -L -n os-core -v "$version" -f /core,/usr/lib/os-release:"$OS_RELEASE",/usr/share/defaults/swupd/format:"$FORMAT" "$env_name"
		else
			create_bundle -L -n os-core -v "$version" -f /core "$env_name"
		fi
	else
		create_tar "$env_name"/web-dir/"$version"/Manifest.MoM
		sign_manifest "$env_name"/web-dir/"$version"/Manifest.MoM
	fi

}

# Destroys a test environment
# Parameters:
# - ENVIRONMENT_NAME: the name of the test environment to be deleted
destroy_test_environment() { 

	local env_name=$1

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    destroy_test_environment <environment_name>
			EOM
		return
	fi
	validate_path "$env_name"

	# since the action to be performed is very destructive, at least
	# make sure the directory does look like a test environment
	for var in "state" "target-dir" "web-dir"; do
		if [ ! -d "$env_name/$var" ]; then
			echo "The name provided doesn't seem to be a valid test environment"
			return 1
		fi
	done
	sudo rm -rf "$env_name"

}

# Creates a bundle in the test environment. The bundle can contain files, directories or symlinks.
create_bundle() { 

	cb_usage() { 
		cat <<-EOM
		Usage:
		    create_bundle [-L] [-n] <bundle_name> [-v] <version> [-d] <list of dirs> [-f] <list of files> [-l] <list of links> ENV_NAME

		Options:
		    -L    When the flag is selected the bundle will be 'installed' in the target-dir, otherwise it will only be created in web-dir
		    -n    The name of the bundle to be created, if not specified a name will be autogenerated
		    -v    The version for the bundle, if non selected version 10 will be used
		    -d    Comma-separated list of directories to be included in the bundle
		    -f    Comma-separated list of files to be created and included in the bundle
		    -l    Comma-separated list of symlinks to be created and included in the bundle
		    -b    Comma-separated list of dangling (broken) symlinks to be created and included in the bundle

		Notes:
		    - if no option is selected, a minimal bundle will be created with only one directory
		    - for every symlink created a related file will be created and added to the bundle as well (except for dangling links)
		    - if the '-f' or '-l' options are used, and the directories where the files live don't exist,
		      they will be automatically created and added to the bundle for each file
		    - if instead of creating a new file you want to reuse an existing one, you can do this by adding ':' followed by the
		      path to the file, for example '-f /usr/bin/test-1:my_environment/web-dir/10/files/\$file_hash'

		Example of usage:

		    The following command will create a bundle named 'test-bundle', which will include three directories,
		    four files, and one symlink (they will be added to the bundle's manifest), all these resources will also
		    be tarred. The manifest will be added to the MoM.

		    create_bundle -n test-bundle -f /usr/bin/test-1,/usr/bin/test-2,/etc/systemd/test-3 -l /etc/test-link my_test_env

		EOM
	}

	add_dirs() {

		if [[ "$val" != "/"* ]]; then
			val=/"$val"
		fi
		# if the directories the file is don't exist, add them to the bundle,
		# do not add all the directories of the tracking file /usr/share/clear/bundles,
		# this file is added in every bundle by default, it would add too much overhead
		# for most tests
		fdir=$(dirname "${val%:*}")
		if [ ! "$(sudo cat "$manifest" | grep -x "D\\.\\.\\..*$fdir")" ] && [ "$fdir" != "/usr/share/clear/bundles" ] \
		&& [ "$fdir" != "/" ]; then
			bundle_dir=$(create_dir "$files_path")
			add_to_manifest -p "$manifest" "$bundle_dir" "$fdir"
			# add each one of the directories of the path if they are not in the manifest already
			while [ "$(dirname "$fdir")" != "/" ]; do
				fdir=$(dirname "$fdir")
				if [ ! "$(sudo cat "$manifest" | grep -x "D\\.\\.\\..*$fdir")" ]; then
					add_to_manifest -p "$manifest" "$bundle_dir" "$fdir"
				fi
			done
		fi

	}

	local OPTIND
	local opt
	local dir_list
	local file_list
	local link_list
	local dangling_link_list
	local version
	local bundle_name
	local env_name
	local files_path
	local version_path
	local manifest
	local local_bundle=false

	# If no parameters are received show help
	if [ $# -eq 0 ]; then
		create_bundle -h
		return
	fi
	set -f  # turn off globbing
	while getopts :v:d:f:l:b:n:L opt; do
		case "$opt" in
			d)	IFS=, read -r -a dir_list <<< "$OPTARG"  ;;
			f)	IFS=, read -r -a file_list <<< "$OPTARG" ;;
			l)	IFS=, read -r -a link_list <<< "$OPTARG" ;;
			b)	IFS=, read -r -a dangling_link_list <<< "$OPTARG" ;;
			n)	bundle_name="$OPTARG" ;;
			v)	version="$OPTARG" ;;
			L)	local_bundle=true ;;
			*)	cb_usage
				return ;;
		esac
	done
	set +f  # turn globbing back on
	env_name=${@:$OPTIND:1}

	# set default values
	bundle_name=${bundle_name:-$(generate_random_name test-bundle-)}
	# if no version was provided create the bundle in the earliest version by default
	version=${version:-$(ls "$env_name"/web-dir | grep -E '^[0-9]+$' | sort -rn | head -n1)}
	# all bundles should include their own tracking file, so append it to the
	# list of files to be created in the bundle
	file_list+=(/usr/share/clear/bundles/"$bundle_name")
	
	# get useful paths
	validate_path "$env_name"
	version_path="$env_name"/web-dir/"$version"
	files_path="$version_path"/files
	target_path="$env_name"/target-dir

	# 1) create the initial manifest
	manifest=$(create_manifest "$version_path" "$bundle_name")
	if [ "$DEBUG" == true ]; then
		echo "Manifest -> $manifest"
	fi
	# update format in the manifest
	update_manifest -p "$manifest" format "$(cat "$version_path"/format)"
	
	# 2) Create one directory for the bundle and add it the requested
	# times to the manifest.
	# Every bundle has to have at least one directory,
	# hashes in directories vary depending on owner and permissions,
	# so one directory hash can be reused many times
	bundle_dir=$(create_dir "$files_path")
	if [ "$DEBUG" == true ]; then
		echo "Directory -> $bundle_dir"
	fi
	# Create a zero pack for the bundle and add the directory to it
	sudo tar -C "$files_path" -rf "$version_path"/pack-"$bundle_name"-from-0.tar --transform "s,^,staged/," "$(basename "$bundle_dir")"
	for val in "${dir_list[@]}"; do
		add_dirs
		if [ "$val" != "/" ]; then
			add_to_manifest -p "$manifest" "$bundle_dir" "$val"
			if [ "$local_bundle" = true ]; then
				sudo mkdir -p "$target_path$val"
			fi
		fi
	done
	
	# 3) Create the requested file(s)
	for val in "${file_list[@]}"; do
		add_dirs
		# if the user wants to use an existing file, use it, else create a new one
		if [[ "$val" = *":"* ]]; then
			bundle_file="${val#*:}"
			val="${val%:*}"
			validate_item "$bundle_file"
		else
			bundle_file=$(create_file "$files_path")
		fi
		if [ "$DEBUG" == true ]; then
			echo "file -> $bundle_file"
		fi
		add_to_manifest -p "$manifest" "$bundle_file" "$val"
		# Add the file to the zero pack of the bundle
		sudo tar -C "$files_path" -rf "$version_path"/pack-"$bundle_name"-from-0.tar --transform "s,^,staged/," "$(basename "$bundle_file")"
		# if the local_bundle flag is set, copy the files to the target-dir as if the
		# bundle had been locally installed
		if [ "$local_bundle" = true ]; then
			sudo mkdir -p "$target_path$(dirname "$val")"
			sudo cp "$bundle_file" "$target_path$val"
		fi 
	done
	
	# 4) Create the requested link(s) in the bundle
	for val in "${link_list[@]}"; do
		if [[ "$val" != "/"* ]]; then
			val=/"$val"
		fi
		# if the directory the link is doesn't exist,
		# add it to the bundle (except if the directory is "/")
		fdir=$(dirname "$val")
		if [ "$fdir" != "/" ]; then
			if [ ! "$(sudo cat "$manifest" | grep -x "D\\.\\.\\..*$fdir")" ]; then
				bundle_dir=$(create_dir "$files_path")
				add_to_manifest -p "$manifest" "$bundle_dir" "$fdir"
			fi
		fi
		bundle_link=$(create_link "$files_path")
		sudo tar -C "$files_path" -rf "$version_path"/pack-"$bundle_name"-from-0.tar --transform "s,^,staged/," "$(basename "$bundle_link")"
		add_to_manifest "$manifest" "$bundle_link" "$val"
		# Add the file pointed by the link to the zero pack of the bundle
		pfile=$(basename "$(readlink -f "$bundle_link")")
		sudo tar -C "$files_path" -rf "$version_path"/pack-"$bundle_name"-from-0.tar --transform "s,^,staged/," "$(basename "$pfile")"
		if [ "$DEBUG" == true ]; then
			echo "link -> $bundle_link"
			echo "file pointed to -> $(readlink -f "$bundle_link")"
		fi
		if [ "$local_bundle" = true ]; then
			sudo mkdir -p "$target_path$(dirname "$val")"
			# if local_bundle is enabled copy the link to target-dir but also
			# copy the file it points to
			pfile_path=$(awk "/$(basename $pfile)/"'{ print $4 }' "$manifest")
			sudo cp "$files_path"/"$pfile" "$target_path$pfile_path"
			sudo ln -rs "$target_path$pfile_path" "$target_path$val"
		fi
	done
	
	# 5) Create the requested dangling link(s) in the bundle
	for val in "${dangling_link_list[@]}"; do
		if [[ "$val" != "/"* ]]; then
			val=/"$val"
		fi
		# if the directory the link is doesn't exist,
		# add it to the bundle (except if the directory is "/")
		fdir=$(dirname "$val")
		if [ "$fdir" != "/" ]; then
			if [ ! "$(sudo cat "$manifest" | grep -x "D\\.\\.\\..*$fdir")" ]; then
				bundle_dir=$(create_dir "$files_path")
				add_to_manifest -p "$manifest" "$bundle_dir" "$fdir"
			fi
		fi
		# Create a link passing a file that does not exits
		bundle_link=$(create_link "$files_path" "$files_path"/"$(generate_random_name does_not_exist-)")
		sudo tar -C "$files_path" -rf "$version_path"/pack-"$bundle_name"-from-0.tar --transform "s,^,staged/," "$(basename "$bundle_link")"
		add_to_manifest --skip-validation "$manifest" "$bundle_link" "$val"
		# Add the file pointed by the link to the zero pack of the bundle
		if [ "$DEBUG" == true ]; then
			echo "dangling link -> $bundle_link"
		fi
		if [ "$local_bundle" = true ]; then
			sudo mkdir -p "$target_path$(dirname "$val")"
			# if local_bundle is enabled since we cannot copy a bad link create a new one
			# in the appropriate location in target-dir with the corrent name
			sudo ln -s "$(generate_random_name /does_not_exist-)" "$target_path$val"
		fi
	done

	# 6) Add the bundle to the MoM (do not use -p option so the MoM's tar is created and signed)
	add_to_manifest "$version_path"/Manifest.MoM "$manifest" "$bundle_name"

	# 7) Create/renew manifest tars
	sudo rm -f "$manifest".tar
	create_tar "$manifest"

	# 8) Create the subscription to the bundle if the local_bundle flag is enabled
	if [ "$local_bundle" = true ]; then
		sudo touch "$target_path"/usr/share/clear/bundles/"$bundle_name"
	fi

}

# Removes a bundle from the target-dir and/or the web-dir
# Parameters
# - -L: if this option is set the bundle is removed from the target-dir only,
#       otherwise it is removed from target-dir and web-dir
# - BUNDLE_MANIFEST: the manifest of the bundle to be removed
remove_bundle() {

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    remove_bundle [-L] <bundle_manifest>

			Options:
			    -L   If set, the bundle will be removed from the target-dir only,
			         otherwise it is removed from both target-dir and web-dir
			EOM
		return
	fi
	local remove_local=false
	[ "$1" = "-L" ] && { remove_local=true ; shift ; }
	local bundle_manifest=$1
	local target_path
	local version_path
	local bundle_name
	local file_names
	local dir_names
	local manifest_file

	# if the bundle's manifest is not found just return
	if [ ! -e "$bundle_manifest" ]; then
		echo "$(basename "$bundle_manifest") not found, maybe the bundle was already removed"
		return
	fi

	target_path=$(dirname "$bundle_manifest" | cut -d "/" -f1)/target-dir
	version_path=$(dirname "$bundle_manifest")
	manifest_file=$(basename "$bundle_manifest")
	bundle_name=${manifest_file#Manifest.}

	# remove all files that are in the manifest from target-dir first
	file_names=($(awk '/^[FL]...\t/ { print $4 }' "$bundle_manifest"))
	for fname in ${file_names[@]}; do
		sudo rm -f "$target_path$fname"
	done
	# now remove all directories in the manifest (only if empty else they
	# may be used by another bundle)
	dir_names=($(awk '/^D...\t/ { print $4 }' "$bundle_manifest"))
	for dname in ${dir_names[@]}; do
		sudo rmdir --ignore-fail-on-non-empty "$target_path$dname" 2> /dev/null
	done
	if [ "$remove_local" = false ]; then
		# there is no need to remove the files and tars from web-dir/<ver>/files
		# as long as we remove the manifest from the bundle from all versions
		# where it shows up and from the MoM, the files may be used by another bundle
		sudo rm -f "$version_path"/"$manifest_file"
		sudo rm -f "$version_path"/"$manifest_file".tar
		# remove packs
		sudo rm "$version_path"/pack-"$bundle_name"-from-*.tar
		# finally remove it from the MoM
		remove_from_manifest "$version_path"/Manifest.MoM "$bundle_name"
	fi

}

# Installs a bundle in target-dir
# Parameters:
# - BUNDLE_MANIFEST: the manifest of the bundle to be installed

install_bundle() {

	local bundle_manifest=$1
	local target_path
	local file_names
	local dir_names
	local link_names
	local fhash
	local lhash
	local fdir
	local manifest_file
	local bundle_name

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    install_bundle <bundle_manifest>
			EOM
		return
	fi
	validate_item "$bundle_manifest"
	target_path=$(dirname "$bundle_manifest" | cut -d "/" -f1)/target-dir
	files_path=$(dirname "$bundle_manifest")/files
	manifest_file=$(basename "$bundle_manifest")
	bundle_name=${manifest_file#Manifest.}

	# make sure the bundle is not already installed
	if [ -e "$target_path"/usr/share/clear/bundles/"$bundle_name" ]; then
		return
	fi

	# iterate through the manifest and copy all the files in its
	# correct place, start with directories
	dir_names=($(awk '/^D...\t/ { print $4 }' "$bundle_manifest"))
	for dname in ${dir_names[@]}; do
		sudo mkdir -p "$target_path$dname"
	done
	# now files
	file_names=($(awk '/^F...\t/ { print $4 }' "$bundle_manifest"))
	for fname in ${file_names[@]}; do
		fhash=$(get_hash_from_manifest "$bundle_manifest" "$fname")
		sudo cp "$files_path"/"$fhash" "$target_path$fname"
	done
	# finally links
	link_names=($(awk '/^L...\t/ { print $4 }' "$bundle_manifest"))
	for lname in ${link_names[@]}; do
		lhash=$(get_hash_from_manifest "$bundle_manifest" "$lname")
		fhash=$(readlink "$files_path"/"$lhash")
		# is the original link dangling?
		if [[ $fhash = *"does_not_exist"* ]]; then
			sudo ln -s "$fhash" "$target_path$lname"
		else
			fname=$(awk "/$fhash/ "'{ print $4 }' "$bundle_manifest")
			sudo ln -s $(basename "$fname") "$target_path$lname"
		fi
	done

}

# Updates one file or directory from a bundle, the update will be created in whatever version
# is the latest one (from web-dir/formatstaging/latest)
# Parameters:
# - -p: if the p (partial) flag is set the function skips updating the hashes
#       in the MoM, and re-creating the bundle's tar, this is useful if more changes are to be done
#       in order to reduce time
# - ENVIRONMENT_NAME: the name of the test environment
# - BUNDLE_NAME: the name of the bundle to be updated
# - OPTION: the kind of update to be performed { --add, --add-dir, --delete, --ghost, --rename, --rename-legacy, --update }
# - FILE_NAME: file or directory of the bundle to add or update
# - NEW_NAME: when --rename is chosen this parameter receives the new name to assign
update_bundle() {

	local partial=false
	[ "$1" = "-p" ] && { partial=true ; shift ; }
	local env_name=$1
	local bundle=$2
	local option=$3
	local fname=$4
	local new_name=$5
	local version
	local version_path
	local oldversion
	local oldversion_path
	local bundle_manifest
	local fdir
	local new_dir
	local new_file
	local contentsize
	local fsize
	local fhash
	local fname
	local new_fhash
	local new_fsize
	local new_fname
	local delta_name
	local format
	local files
	local bundle_file

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    update_bundle [-p] <environment_name> <bundle_name> --add <file_name>[:<path_to_existing_file>]
			    update_bundle [-p] <environment_name> <bundle_name> --add-dir <directory_name>
			    update_bundle [-p] <environment_name> <bundle_name> --delete <file_name>
			    update_bundle [-p] <environment_name> <bundle_name> --ghost <file_name>
			    update_bundle [-p] <environment_name> <bundle_name> --update <file_name>
			    update_bundle [-p] <environment_name> <bundle_name> --rename[-legacy] <file_name> <new_name>
			    update_bundle [-p] <environment_name> <bundle_name> --header-only

			Options:
			    -p    If set (partial), the bundle will be updated, but the manifest's tar won't
			          be re-created nor the hash will be updated in the MoM. Use this flag when more
			          updates or changes will be done to the bundle to save time.
			EOM
		return
	fi

	if [ "$option" = "--header-only" ]; then
		fname="dummy"
	fi
	validate_path "$env_name"
	validate_param "$bundle"
	validate_param "$option"
	validate_param "$fname"

	# make sure fname starts with a slash
	if [[ "$fname" != "/"* ]]; then
		fname=/"$fname"
	fi
	# the version where the update will be created is the latest version
	version="$(ls "$env_name"/web-dir | grep -E '^[0-9]+$' | sort -rn | head -n1)"
	version_path="$env_name"/web-dir/"$version"
	format=$(cat "$version_path"/format)
	# find the previous version of this bundle manifest
	oldversion="$version"
	while [ "$oldversion" -gt 0 ] && [ ! -e "$env_name"/web-dir/"$oldversion"/Manifest."$bundle" ]; do
		oldversion=$(awk '/previous/ { print $2 }' "$env_name"/web-dir/"$oldversion"/Manifest.MoM)
	done
	if [ "$oldversion" = "$version" ]; then
		# if old version and new version are the same it means this bundle has already
		# been modified in this version, so look for the real old version
		oldversion=$(awk '/previous/ { print $2}' "$env_name"/web-dir/"$oldversion"/Manifest."$bundle")
	fi
	oldversion_path="$env_name"/web-dir/"$oldversion"
	bundle_manifest="$version_path"/Manifest."$bundle"
	# since we are going to be making updates to the bundle, copy its manifest
	# from the old version directory to the new one (if not copied already)
	if [ ! -e "$bundle_manifest" ]; then
		sudo cp "$oldversion_path"/Manifest."$bundle" "$bundle_manifest"
	fi
	update_manifest -p "$bundle_manifest" format "$format"
	update_manifest -p "$bundle_manifest" version "$version"
	update_manifest -p "$bundle_manifest" previous "$oldversion"
	# copy also the bundle's zero pack, untar it the files directory in the new version
	# and create a tar per file (full files)
	if [ ! -e "$version_path"/pack-"$bundle"-from-0.tar ]; then
		sudo cp "$oldversion_path"/pack-"$bundle"-from-0.tar "$version_path"/
		sudo tar -xf "$version_path"/pack-"$bundle"-from-0.tar --strip-components 1 --directory "$version_path"/files
		files=("$(ls -I "*.tar" "$version_path"/files)")
		for bundle_file in ${files[*]}; do
			if [ ! -e "$version_path"/files/"$bundle_file".tar ]; then
				create_tar "$version_path"/files/"$bundle_file"
			fi
		done
	fi
	contentsize=$(awk '/contentsize/ { print $2 }' "$bundle_manifest")

	# these actions apply to all operations except when adding a new file or updating the header only
	if [ "$option" != "--add" ] && [ "$option" != "--add-dir" ] && [ "$option" != "--add-file" ] && [ "$option" != "--header-only" ]; then
		fhash=$(get_hash_from_manifest "$bundle_manifest" "$fname")
		fsize=$(stat -c "%s" "$oldversion_path"/files/"$fhash")
		# update the version of the file to be updated in the manifest
		update_manifest -p "$bundle_manifest" file-version "$fname" "$version"
	fi

	case "$option" in
	--add | --add-file)
		# if the directories the file is don't exist, add them to the bundle
		fdir=$(dirname "${fname%:*}")
		if [ ! "$(sudo cat "$bundle_manifest" | grep -x "D\\.\\.\\..*$fdir")" ] && [ "$fdir" != "/" ]; then
			new_dir=$(create_dir "$version_path"/files)
			add_to_manifest -p "$bundle_manifest" "$new_dir" "$fdir"
			# add each one of the directories of the path if they are not in the manifest already
			while [ "$(dirname "$fdir")" != "/" ]; do
				fdir=$(dirname "$fdir")
				if [ ! "$(sudo cat "$bundle_manifest" | grep -x "D\\.\\.\\..*$fdir")" ]; then
					add_to_manifest -p "$bundle_manifest" "$new_dir" "$fdir"
				fi
			done
			# Add the dir to the delta-pack
			add_to_pack "$bundle" "$new_dir" "$oldversion"
		fi
		# if the user wants to use an existing file, use it, else create a new one
		if [[ "$fname" = *":"* ]]; then
			new_file="${fname#*:}"
			validate_item "$new_file"
			sudo rsync -aq "$new_file" "$version_path"/files/"$(basename "$new_file")"
			sudo rsync -aq "$new_file".tar "$version_path"/files/"$(basename "$new_file")".tar
			new_file="$version_path"/files/"$(basename "$new_file")"
			fname="${fname%:*}"
		else
			new_file=$(create_file "$version_path"/files)
		fi
		add_to_manifest -p "$bundle_manifest" "$new_file" "$fname"
		# contentsize is automatically added by the add_to_manifest function so
		# all we need is to get the updated value for now
		contentsize=$(awk '/contentsize/ { print $2 }' "$bundle_manifest")
		# Add the file to the zero pack of the bundle
		add_to_pack "$bundle" "$new_file"
		# Add the file also to the delta-pack
		add_to_pack "$bundle" "$new_file" "$oldversion"
		;;
	--add-dir)
		# if the directories the file is don't exist, add them to the bundle
		fdir="$fname"
		if [ ! "$(sudo cat "$bundle_manifest" | grep -x "D\\.\\.\\..*$fdir")" ] && [ "$fdir" != "/" ]; then
			new_dir=$(create_dir "$version_path"/files)
			add_to_manifest -p "$bundle_manifest" "$new_dir" "$fdir"
			# add each one of the directories of the path if they are not in the manifest already
			while [ "$(dirname "$fdir")" != "/" ]; do
				fdir=$(dirname "$fdir")
				if [ ! "$(sudo cat "$bundle_manifest" | grep -x "D\\.\\.\\..*$fdir")" ]; then
					add_to_manifest -p "$bundle_manifest" "$new_dir" "$fdir"
				fi
			done
			# Add the dir to the delta-pack
			add_to_pack "$bundle" "$new_dir"
			add_to_pack "$bundle" "$new_dir" "$oldversion"
		fi
		contentsize=$(awk '/contentsize/ { print $2 }' "$bundle_manifest")
		;;
	--delete | --ghost)
		# replace the first character of the line that matches with "."
		sudo sed -i "/\\t${fname////\\/}$/s/./\./1" "$bundle_manifest"
		sudo sed -i "/\\t${fname////\\/}\\t/s/./\./1" "$bundle_manifest"
		if [ "$option" = "--delete" ]; then
			# replace the second character of the line that matches with "d"
			sudo sed -i "/\\t${fname////\\/}$/s/./d/2" "$bundle_manifest"
			sudo sed -i "/\\t${fname////\\/}\\t/s/./d/2" "$bundle_manifest"
			# remove the related file(s) from the version dir (if there)
			sudo rm -f "$version_path"/files/"$fhash"
			sudo rm -f "$version_path"/files/"$fhash".tar
		else
			# replace the second character of the line that matches with "g"
			sudo sed -i "/\\t${fname////\\/}$/s/./g/2" "$bundle_manifest"
			sudo sed -i "/\\t${fname////\\/}\\t/s/./g/2" "$bundle_manifest"
		fi
		# replace the hash with 0s
		update_manifest -p "$bundle_manifest" file-hash "$fname" "$zero_hash"
		# calculate new contentsize (NOTE: filecount is not decreased)
		contentsize=$((contentsize - fsize))
		;;
	--update)
		# append random content to the file
		generate_random_content 1 20 | sudo tee -a "$version_path"/files/"$fhash" > /dev/null
		# recalculate hash and update file names
		new_fhash=$(sudo "$SWUPD" hashdump "$version_path"/files/"$fhash" 2> /dev/null)
		sudo mv "$version_path"/files/"$fhash" "$version_path"/files/"$new_fhash"
		create_tar "$version_path"/files/"$new_fhash"
		sudo rm -f "$oldversion_path"/files/"$fhash".tar
		# update the manifest with the new hash
		update_manifest -p "$bundle_manifest" file-hash "$fname" "$new_fhash"
		# calculate new contentsize
		new_fsize=$(stat -c "%s" "$version_path"/files/"$new_fhash")
		contentsize=$((contentsize + (new_fsize - fsize)))
		# update the zero-pack with the new file
		add_to_pack "$bundle" "$version_path"/files/"$new_fhash"
		# create the delta-file
		delta_name="$oldversion-$version-$fhash-$new_fhash"
		sudo bsdiff "$oldversion_path"/files/"$fhash" "$version_path"/files/"$new_fhash" "$version_path"/delta/"$delta_name"
		# create or add to the delta-pack
		add_to_pack "$bundle" "$version_path"/delta/"$delta_name" "$oldversion"
		;;
	--rename | --rename-legacy)
		validate_param "$new_name"
		# make sure new_name starts with a slash
		if [[ "$new_name" != "/"* ]]; then
			new_name=/"$new_name"
		fi
		new_fname="${new_name////\\/}"
		# renames need two records in the manifest, one with the
		# new name (F...) and one with the old one (.d..)
		# replace the first character of the old record with "."
		sudo sed -i "/\\t${fname////\\/}$/s/./\./1" "$bundle_manifest"
		sudo sed -i "/\\t${fname////\\/}\\t/s/./\./1" "$bundle_manifest"
		# replace the second character of the old record with "d"
		sudo sed -i "/\\t${fname////\\/}$/s/./d/2" "$bundle_manifest"
		sudo sed -i "/\\t${fname////\\/}\\t/s/./d/2" "$bundle_manifest"
		# add the new name to the manifest
		add_to_manifest -p "$bundle_manifest" "$oldversion_path"/files/"$fhash" "$new_name"
		if [ "$option" = "--rename" ]; then
			# replace the hash of the old record with 0s
			update_manifest -p "$bundle_manifest" file-hash "$fname" "$zero_hash"
		else
			# replace the fourth character of the old record with "r"
			sudo sed -i "/\\t${fname////\\/}$/s/./r/4" "$bundle_manifest"
			sudo sed -i "/\\t${fname////\\/}\\t/s/./r/4" "$bundle_manifest"
			# replace the fourth character of the new record with "r"
			sudo sed -i "/\\t$new_fname$/s/./r/4" "$bundle_manifest"
		fi
		# create the delta-file
		delta_name="$oldversion-$version-$fhash-$fhash"
		sudo bsdiff "$oldversion_path"/files/"$fhash" "$oldversion_path"/files/"$fhash" "$version_path"/delta/"$delta_name"
		# create or add to the delta-pack
		add_to_pack "$bundle" "$version_path"/delta/"$delta_name" "$oldversion"
		;;
	--header-only)
		# do nothing
		;;
	*)
		terminate "Please select a valid option for updating the bundle: --add, --delete, --ghost, --rename, --update, --header-only"
		;;
	esac

	# re-order items on the manifest so they are in the correct order based on version
	sudo sort -t$'\t' -k3 -s -h -o "$bundle_manifest" "$bundle_manifest"

	update_manifest -p "$bundle_manifest" contentsize "$contentsize"
	update_manifest -p "$bundle_manifest" timestamp "$(date +"%s")"

	# renew the manifest tar
	if [ "$partial" = false ]; then
		sudo rm -f "$bundle_manifest".tar
		create_tar "$bundle_manifest"
		# update the mom
		update_hashes_in_mom "$version_path"/Manifest.MoM
	fi

}

# Adds the specified file to the zero or delta pack for the bundle
# Parameters:
# - BUNDLE: the name of the bundle
# - ITEM: the file or directory to be added into the pack
# - FROM_VERSION: the from version for the pack, if not specified a zero pack is asumed
add_to_pack() {

	local bundle=$1
	local item=$2
	local version=${3:-0}
	local item_path
	local version_path
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    add_to_pack <bundle_name> <item> [from_version]
			EOM
		return
	fi

	item_path=$(dirname "$item")
	version_path=$(dirname "$item_path")

	# item should be a file from the "delta" or "files" directories
	# fullfiles are expected to be in the staged dir when extracted
	if [[ "$item" = *"/files"* ]]; then
		sudo tar -C "$item_path" -rf "$version_path"/pack-"$bundle"-from-"$version".tar --transform "s,^,staged/," "$(basename "$item")"
	elif [[ "$item" = *"/delta"* ]]; then
		sudo tar -C "$version_path" -rf "$version_path"/pack-"$bundle"-from-"$version".tar delta/"$(basename "$item")"
	else
		terminate "the provided file is not valid in a zero pack"
	fi

}

# Cleans up the directories in the state dir
# Parameters:
# - ENV_NAME: the name of the test environment to have the state dir cleaned up
clean_state_dir() {

	local env_name=$1
	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    clean_state_dir <environment_name>
			EOM
		return
	fi
	validate_path "$env_name"

	sudo rm -rf "$env_name"/state/{staged,download,delta,telemetry}
	sudo mkdir -p "$env_name"/state/{staged,download,delta,telemetry}
	sudo chmod -R 0700 "$env_name"/state

}

# Creates a new test case based on a template
# Parameters:
# - NAME: the name (and path) of the test to be generated
generate_test() {

	local name=$1
	local path

	# If no parameters are received show usage
	if [ $# -eq 0 ]; then
		cat <<-EOM
			Usage:
			    generate_test <test_name>
			EOM
		return
	fi
	validate_param "$name"

	path=$(dirname "$name")/
	name=$(basename "$name")

	{
		printf '#!/usr/bin/env bats\n\n'
		printf 'load "../testlib"\n\n'
		printf 'global_setup() {\n\n'
		printf '\t# global setup\n\n'
		printf '}\n\n'
		printf 'test_setup() {\n\n'
		printf '\t# create_test_environment "$TEST_NAME"\n'
		printf '\t# create_bundle -n <bundle_name> -f <file_1>,<file_2>,<file_N> "$TEST_NAME"\n\n'
		printf '}\n\n'
		printf 'test_teardown() {\n\n'
		printf '\t# destroy_test_environment "$TEST_NAME"\n\n'
		printf '}\n\n'
		printf 'global_teardown() {\n\n'
		printf '\t# global cleanup\n\n'
		printf '}\n\n'
		printf '@test "<test description>" {\n\n'
		printf '\trun sudo sh -c "$SWUPD <swupd_command> $SWUPD_OPTS <command_options>"\n\n'
		printf '\t# assert_status_is 0\n'
		printf '\t# expected_output=$(cat <<-EOM\n'
		printf '\t# \t<expected output>\n'
		printf '\t# EOM\n'
		printf '\t# )\n'
		printf '\t# assert_is_output "$expected_output"\n\n'
		printf '}\n\n'
	} > "$path$name".bats
	# make the test script executable
	chmod +x "$path$name".bats

}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# The section below contains test fixtures that can be used from tests to create and
# cleanup test dependencies, these functions can be overwritten in the test script.
# The intention of these is to try reducing the amount of boilerplate included in
# tests since all tests require at least the creation of a  test environment
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

setup() {

	# the first time setup runs, run the global_setup
	if [ "$BATS_TEST_NUMBER" -eq 1 ]; then
		global_setup
	fi
	# in case the env was created in global_setup set environment variables
	if [ -d "$TEST_NAME" ]; then
		set_env_variables "$TEST_NAME"
	fi
	test_setup

}

teardown() {

	test_teardown
	# if the last test just ran, run the global teardown
	if [ "$BATS_TEST_NUMBER" -eq "${#BATS_TEST_NAMES[@]}" ]; then
		global_teardown
	fi

}

global_setup() {

	# dummy value in case function is not defined
	return

}

global_teardown() {

	# dummy value in case function is not defined
	return

}

# Default test_setup
test_setup() {

	create_test_environment "$TEST_NAME"

}

# Default test_teardown
test_teardown() {

	if [ "$DEBUG_TEST" != true ]; then
		destroy_test_environment "$TEST_NAME"
	fi

}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# The section below contains functions useful for consistent test validation and output
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sep="------------------------------------------------------------------"

print_assert_failure() {

	local message=$1
	validate_param "$message"

	echo -e "\\nAssertion Failed"
	echo -e "$message"
	echo "Command output:"
	echo "------------------------------------------------------------------"
	echo "$output"
	echo "------------------------------------------------------------------"

}

use_ignore_list() {

	local ignore_enabled=$1
	local filtered_output
	validate_param "$ignore_enabled"

	# if selected, remove things in the ignore list from the actual output
	if [ "$ignore_enabled" = true ]; then
		# always remove blank lines and lines with only dots
		filtered_output=$(echo "$output" | sed -E '/^$/d' | sed -E '/^\.+$/d')
		# now remove lines that are included in any of the ignore-lists
		# there are 3 possible ignore-lists that the function is going
		# to recognize (in order of precedence):
		# - <functional_tests_directory>/<test_theme_directory>/<test_name>.ignore-list
		# - <functional_tests_directory>/<test_theme_directory>/ignore-list
		# - <functional_tests_directory>/ignore-list
		if [ -f "$THEME_DIRNAME"/"$TEST_NAME".ignore-list ]; then
			ignore_list="$THEME_DIRNAME"/"$TEST_NAME".ignore-list
		elif [ -f "$THEME_DIRNAME"/ignore-list ]; then
			ignore_list="$THEME_DIRNAME"/ignore-list
		elif [ -f "$FUNC_DIR"/ignore-list ]; then
			ignore_list="$FUNC_DIR"/ignore-list.global
		fi
		while IFS= read -r line; do
			# if the pattern from the file has a "/" escape it first so it does
			# not confuses the sed command
			line="${line////\\/}"
			filtered_output=$(echo "$filtered_output" | sed -E "/^$line$/d")
		done < "$ignore_list"
	else
		filtered_output="$output"
	fi
	echo "$filtered_output"

}

assert_status_is() {

	local expected_status=$1
	validate_param "$expected_status"

	if [ -z "$status" ]; then
		echo "The \$status environment variable is empty."
		echo "Please make sure this assertion is used inside a BATS test after a 'run' command."
		return 1
	fi

	if [ ! "$status" -eq "$expected_status" ]; then
		print_assert_failure "Expected status: $expected_status\\nActual status: $status"
		return 1
	else
		# if the assertion was successful show the output only if the user
		# runs the test with the -t flag
		echo -e "\\nCommand output:" >&3
		echo "------------------------------------------------------------------" >&3
		echo "$output" >&3
		echo -e "------------------------------------------------------------------\\n" >&3
	fi

}

assert_status_is_not() {

	local not_expected_status=$1
	validate_param "$not_expected_status"

	if [ -z "$status" ]; then
		echo "The \$status environment variable is empty."
		echo "Please make sure this assertion is used inside a BATS test after a 'run' command."
		return 1
	fi

	if [ "$status" -eq "$not_expected_status" ]; then
		print_assert_failure "Status expected to be different than: $not_expected_status\\nActual status: $status"
		return 1
	else
		# if the assertion was successful show the output only if the user
		# runs the test with the -t flag
		echo -e "\\nCommand output:" >&3
		echo "------------------------------------------------------------------" >&3
		echo "$output" >&3
		echo -e "------------------------------------------------------------------\\n" >&3
	fi

}

assert_dir_exists() {

	local vdir=$1
	validate_param "$vdir"

	if [ ! -d "$vdir" ]; then
		print_assert_failure "Directory $vdir should exist, but it does not"
		return 1
	fi

}

assert_dir_not_exists() {

	local vdir=$1
	validate_param "$vdir"

	if [ -d "$vdir" ]; then
		print_assert_failure "Directory $vdir should not exist, but it does"
		return 1
	fi

}

assert_file_exists() {

	local vfile=$1
	validate_param "$vfile"

	if [ ! -f "$vfile" ]; then
		print_assert_failure "File $vfile should exist, but it does not"
		return 1
	fi

}

assert_file_not_exists() {

	local vfile=$1
	validate_param "$vfile"

	if [ -f "$vfile" ]; then
		print_assert_failure "File $vfile should not exist, but it does"
		return 1
	fi

}

assert_in_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ ! "$actual_output" == *"$expected_output"* ]]; then
		print_assert_failure "The following text was not found in the command output:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_not_in_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ "$actual_output" == *"$expected_output"* ]]; then
		print_assert_failure "The following text was found in the command output and should not have:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_is_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ ! "$actual_output" == "$expected_output" ]]; then
		print_assert_failure "The following text was not the command output:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_is_not_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ "$actual_output" == "$expected_output" ]]; then
		print_assert_failure "The following text was the command output and should not have:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_regex_in_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ ! "$actual_output" =~ $expected_output ]]; then
		print_assert_failure "The following text (regex) was not found in the command output:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_regex_not_in_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ "$actual_output" =~ $expected_output ]]; then
		print_assert_failure "The following text (regex) was found in the command output and should not have:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_regex_is_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ ! "$actual_output" =~ ^$expected_output$ ]]; then
		print_assert_failure "The following text (regex) was not the command output:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_regex_is_not_output() {

	local actual_output
	local ignore_switch=true
	local ignore_list
	[ "$1" = "--identical" ] && { ignore_switch=false ; shift ; }
	local expected_output=$1
	validate_param "$expected_output"

	actual_output=$(use_ignore_list "$ignore_switch")
	if [[ "$actual_output" =~ ^$expected_output$ ]]; then
		print_assert_failure "The following text (regex) was the command output and should not have:\\n$sep\\n$expected_output\\n$sep"
		echo -e "Difference:\\n$sep"
		echo "$(diff -u <(echo "$expected_output") <(echo "$actual_output"))"
		return 1
	fi

}

assert_equal() {

	local val1=$1
	local val2=$2
	validate_param "$val1"
	validate_param "$val2"

	if [ "$val1" != "$val2" ]; then
		return 1
	fi

}

assert_not_equal() {

	local val1=$1
	local val2=$2
	validate_param "$val1"
	validate_param "$val2"

	if [ "$val1" = "$val2" ]; then
		return 1
	fi

}

assert_files_equal() {

	local val1=$1
	local val2=$2
	validate_item "$val1"
	validate_item "$val2"

	diff -q "$val1" "$val2"

}

assert_files_not_equal() {

	local val1=$1
	local val2=$2
	validate_item "$val1"
	validate_item "$val2"

	if diff -q "$val1" "$val2" > /dev/null; then
		echo "Files $val1 and $val2 are equal"
		return 1
	else
		return 0
	fi

}
