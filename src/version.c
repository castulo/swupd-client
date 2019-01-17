/*
 *   Software Updater - client side
 *
 *      Copyright © 2012-2016 Intel Corporation.
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, version 2 or later of the License.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *   Authors:
 *         Arjan van de Ven <arjan@linux.intel.com>
 *         Tim Pepper <timothy.c.pepper@linux.intel.com>
 *
 */

#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "config.h"
#include "swupd.h"

/* this function attempts to download the latest server version string file from
 * the preferred server to a memory buffer, returning either a negative integer
 * error code or >= 0 representing the server version
 *
 * if v_url is non-NULL the version at v_url is fetched. If v_url is NULL the
 * global version_url is used and the cached version may be used instead of
 * attempting to download the version string again. If v_url is the empty string
 * the global version_url is used and the cached version is ignored. */
int get_latest_version(char *v_url)
{
#define MAX_VERSION_CHARS 10
#define MAX_VERSION_STR_SIZE 11

	char *url = NULL;
	int ret = 0;
	int err;
	char version_str[MAX_VERSION_STR_SIZE];
	struct curl_file_data tmp_version = {
		MAX_VERSION_STR_SIZE, 0,
		version_str
	};
	static int cached_version = -1;

	if (cached_version > 0 && v_url == NULL) {
		return cached_version;
	}

	if (v_url == NULL || strcmp(v_url, "") == 0) {
		v_url = version_url;
	}

	string_or_die(&url, "%s/version/format%s/latest", v_url, format_string);

	ret = swupd_curl_get_file_memory(url, &tmp_version);
	if (ret) {
		goto out;
	} else {
		tmp_version.data[tmp_version.len] = '\0';
		err = strtoi_err(tmp_version.data, &ret);

		if (err != 0) {
			ret = -1;
		}
	}

out:
	free_string(&url);
	cached_version = ret;
	return ret;
}

int get_current_version(char *path_prefix)
{
	char line[LINE_MAX];
	FILE *file;
	int v = -1;
	int err;
	char *buildstamp;
	char *src, *dest;

	string_or_die(&buildstamp, "%s/usr/lib/os-release", path_prefix);
	file = fopen(buildstamp, "rm");
	if (!file) {
		free_string(&buildstamp);
		string_or_die(&buildstamp, "%s/etc/os-release", path_prefix);
		file = fopen(buildstamp, "rm");
		if (!file) {
			free_string(&buildstamp);
			return v;
		}
	}

	while (!feof(file)) {
		line[0] = 0;
		if (fgets(line, LINE_MAX, file) == NULL) {
			break;
		}
		if (strncmp(line, "VERSION_ID=", 11) == 0) {
			src = &line[11];
			/* Drop quotes and newline in value */
			dest = src;
			while (*src) {
				if (*src == '\'' || *src == '"' || *src == '\n') {
					++src;
				} else {
					*dest = *src;
					++dest;
					++src;
				}
			}
			*dest = 0;

			err = strtoi_err(&line[11], &v);
			if (err != 0) {
				v = -1;
			}
			break;
		}
	}

	free_string(&buildstamp);
	fclose(file);
	return v;
}

int read_versions(int *current_version, int *server_version, char *path_prefix)
{
	*current_version = get_current_version(path_prefix);
	*server_version = get_latest_version(NULL);

	if (*current_version < 0) {
		fprintf(stderr, "Error: Unable to determine current OS version\n");
		return SWUPD_CURRENT_VERSION_UNKNOWN;
	}
	if (*server_version < 0) {
		fprintf(stderr, "Error: Unable to determine the server version\n");
		return SWUPD_SERVER_CONNECTION_ERROR;
	}

	return 0;
}

int check_versions(int *current_version, int *server_version, int requested_version, char *path_prefix)
{
	if (read_versions(current_version, server_version, path_prefix) != 0) {
		return -1;
	}
	if (*current_version == 0) {
		fprintf(stderr, "Update from version 0 not supported yet.\n");
		return -1;
	}
	if (requested_version != -1) {
		if (requested_version <= *current_version) {
			fprintf(stderr, "Requested version for update (%d) must be greater than current version (%d)\n",
				requested_version, *current_version);
			return -1;
		}
		if (requested_version < *server_version) {
			*server_version = requested_version;
		}
	}

	return 0;
}

int read_mix_version_file(char *filename, char *path_prefix)
{
	char line[LINE_MAX];
	FILE *file;
	int v = -1;
	int err;
	char *buildstamp;

	string_or_die(&buildstamp, "%s%s", path_prefix, filename);
	file = fopen(buildstamp, "rm");
	if (!file) {
		free_string(&buildstamp);
		return v;
	}

	while (!feof(file)) {
		line[0] = 0;
		if (fgets(line, LINE_MAX, file) == NULL) {
			break;
		}

		/* Drop newline in value */
		char *c = strchr(line, '\n');
		if (c) {
			*c = '\0';
		}

		err = strtoi_err(line, &v);
		if (err != 0) {
			v = -1;
		}
	}
	free_string(&buildstamp);
	fclose(file);
	return v;
}

void check_mix_versions(int *current_version, int *server_version, char *path_prefix)
{
	*current_version = read_mix_version_file("/usr/share/clear/version", path_prefix);
	char *format_file;
	string_or_die(&format_file, MIX_STATE_DIR "version/format%s/latest", format_string);
	*server_version = read_mix_version_file(format_file, path_prefix);
	free_string(&format_file);
}

int update_device_latest_version(int version)
{
	FILE *file = NULL;
	char *path = NULL;

	string_or_die(&path, "%s/version", state_dir);
	file = fopen(path, "w");
	if (!file) {
		free_string(&path);
		return -1;
	}

	fprintf(file, "%i\n", version);
	fflush(file);
	fdatasync(fileno(file));
	fclose(file);
	free_string(&path);
	return 0;
}
