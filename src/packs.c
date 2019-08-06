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
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "config.h"
#include "signature.h"
#include "swupd.h"
#include "swupd_build_variant.h"

/* hysteresis thresholds */
/* TODO: update MAX_XFER after bug #562 is fixed.
 *
 * MAX XFER is the number of simultaneous downloads to be performed at the same
 * time. This value is set to 1 because of a bug that causes a download problem
 * when extrating a large file while other is being downloaded. Set this value
 * to a larger number, to be defined by tests, after bug is fixed.
*/
#define MAX_XFER 1

static struct list *missing_packs = NULL;
static int count = 0;

struct pack_data {
	char *url;
	char *filename;
	const char *module;
	int newversion;
};

static int finalize_pack_download(const char *module, int newversion, const char *filename)
{
	FILE *tarfile = NULL;
	int err;

	debug("\nExtracting %s pack for version %i\n", module, newversion);
	err = archives_extract_to(filename, globals.state_dir);

	unlink(filename);

	if (err == 0) {
		/* make a zero sized file to prevent redownload */
		tarfile = fopen(filename, "w");
		if (tarfile) {
			fclose(tarfile);
		}
	}

	return err;
}

static void download_free_data(void *data)
{
	struct pack_data *pack_data = data;

	if (!data) {
		return;
	}

	free_string(&pack_data->url);
	free_string(&pack_data->filename);
	free(pack_data);
}

static bool download_error(enum download_status status, void *data)
{
	struct pack_data *pack_data = data;
	char *url;

	if (!data) {
		return false;
	}

	if (status == DOWNLOAD_STATUS_NOT_FOUND) {
		// instead of sending the record here to telemetry we can add it to
		// a list so we can send a few missing packs in the same record to
		// reduce the number of records (sometimes we have over a hundred for
		// a single update)
		//telemetry(TELEMETRY_WARN, "packmissing", "%s", missing_packs_str);
		count++;
		debug("Missing pack: %s\n", pack_data->url);
		string_or_die(&url, "url=%s\n", pack_data->url);
		missing_packs = list_prepend_data(missing_packs, url);
		return true;
	}

	return false;
}

static bool download_successful(void *data)
{
	struct pack_data *pack_data = data;

	if (!pack_data) {
		return false;
	}

	return finalize_pack_download(pack_data->module, pack_data->newversion, pack_data->filename) == 0;
}

static int download_pack(struct swupd_curl_parallel_handle *download_handle, int oldversion, int newversion, char *module, int is_mix)
{
	char *url = NULL;
	int err = -1;
	char *filename;

	string_or_die(&filename, "%s/pack-%s-from-%i-to-%i.tar", globals.state_dir, module, oldversion, newversion);

	if (is_mix) {
		string_or_die(&url, "%s/%i/pack-%s-from-%i.tar", MIX_STATE_DIR, newversion, module, oldversion);
		err = link(url, filename);
		if (err) {
			free_string(&filename);
			free_string(&url);
			return err;
		}
		info("Linked %s to %s\n", url, filename);

		err = finalize_pack_download(module, newversion, filename);
		free_string(&url);
		free_string(&filename);
	} else {
		struct pack_data *pack_data;

		string_or_die(&url, "%s/%i/pack-%s-from-%i.tar", globals.content_url, newversion, module, oldversion);

		pack_data = calloc(1, sizeof(struct pack_data));
		ON_NULL_ABORT(pack_data);

		pack_data->url = url;
		pack_data->filename = filename;
		pack_data->module = module;
		pack_data->newversion = newversion;

		err = swupd_curl_parallel_download_enqueue(download_handle, url, filename, NULL, pack_data);
	}

	return err;
}

static double packs_query_total_download_size(struct list *subs, struct manifest *mom)
{
	long size = 0;
	long total_size = 0;
	struct sub *sub = NULL;
	struct list *list = NULL;
	struct file *bundle = NULL;
	char *url = NULL;
	int count = 0;

	for (list = list_head(subs); list; list = list->next) {
		sub = list->data;

		/* if it is a pack from a mix, we won't download it */
		bundle = search_bundle_in_manifest(mom, sub->component);
		if (!bundle) {
			debug("The manifest for bundle %s was not found in the MoM", sub->component);
			return -SWUPD_INVALID_BUNDLE;
		}
		if (bundle->is_mix) {
			continue;
		}

		string_or_die(&url, "%s/%i/pack-%s-from-%i.tar", globals.content_url, sub->version, sub->component, sub->oldversion);
		size = swupd_curl_query_content_size(url);
		if (size != -1) {
			total_size += size;
		} else {
			debug("The pack header for bundle %s could not be downloaded\n", sub->component);
			free_string(&url);
			return -SWUPD_COULDNT_DOWNLOAD_FILE;
		}

		count++;
		debug("Pack: %s (%.2lf Mb)\n", url, (double)size / 1000000);
		free_string(&url);
	}

	debug("Number of packs to download: %d\n", count);
	debug("Total size of packs to be downloaded: %.2lf Mb\n", (double)total_size / 1000000);
	return total_size;
}

/* pull in packs for base and any subscription */
int download_subscribed_packs(struct list *subs, struct manifest *mom, bool required)
{
	struct list *iter;
	struct list *need_download = NULL;
	struct sub *sub = NULL;
	struct stat stat;
	struct file *bundle = NULL;
	struct download_progress download_progress = { 0, 0 };
	int err;
	unsigned int list_length;
	unsigned int complete = 0;
	struct swupd_curl_parallel_handle *download_handle;
	char *packs_size;
	int ret;
	char *missing_packs_str;

	/* make a new list with only the bundles we actually need to download packs for */
	for (iter = list_head(subs); iter; iter = iter->next) {
		char *targetfile;
		sub = iter->data;

		if (!is_installed_bundle(sub->component)) {
			/* if the bundle is not installed in the system but is in the subs list it
			 * means it was recently added as a dependency, so we need to fix the oldversion
			 * in the subscription so we download the correct pack */
			sub->oldversion = 0;
		}

		if (sub->oldversion == sub->version) {
			/* the bundle didn't change, we don't need to download */
			continue;
		}

		if (sub->oldversion > sub->version) {
			/* this condition could happen if for example the bundle does not exist
			 * anymore, so it was removed from the MoM in a latter version */
			continue;
		}

		/* make sure the file is not already in the client system */
		string_or_die(&targetfile, "%s/pack-%s-from-%i-to-%i.tar", globals.state_dir, sub->component, sub->oldversion, sub->version);
		if (lstat(targetfile, &stat) != 0 || stat.st_size != 0) {
			need_download = list_append_data(need_download, sub);
		}

		free_string(&targetfile);
	}

	if (!need_download) {
		/* no packs needs to be downloaded */
		info("No packs need to be downloaded\n");
		progress_complete_step();
		return 0;
	}

	/* we need to download some files, so set up curl */
	download_handle = swupd_curl_parallel_download_start(get_max_xfer(MAX_XFER));
	swupd_curl_parallel_download_set_callbacks(download_handle, download_successful, download_error, download_free_data);

	/* get size of the packs to download */
	download_progress.total_download_size = packs_query_total_download_size(need_download, mom);
	if (download_progress.total_download_size > 0) {
		swupd_curl_parallel_download_set_progress_callbacks(download_handle, swupd_progress_callback, &download_progress);
	} else {
		debug("Couldn't get the size of the packs to download, using number of packs instead\n");
		download_progress.total_download_size = 0;
	}

	/* show the packs size only if > 1 Mb */
	string_or_die(&packs_size, "(%.2lf Mb) ", (double)download_progress.total_download_size / 1000000);
	info("Downloading packs %sfor:\n", ((double)download_progress.total_download_size / 1000000) > 1 ? packs_size : "");
	free_string(&packs_size);
	for (iter = list_head(need_download); iter; iter = iter->next) {
		sub = iter->data;

		info(" - %s\n", sub->component);
	}

	list_length = list_len(need_download);
	for (iter = list_head(need_download); iter; iter = iter->next) {
		sub = iter->data;

		bundle = search_bundle_in_manifest(mom, sub->component);
		if (!bundle) {
			debug("The manifest for bundle %s was not found in the MoM", sub->component);
			return -SWUPD_INVALID_BUNDLE;
		}

		err = download_pack(download_handle, sub->oldversion, sub->version, sub->component, bundle->is_mix);

		/* fall back for progress reporting when the download size
		* could not be determined */
		if (download_progress.total_download_size == 0) {
			complete++;
			progress_report(complete, list_length);
		}
		if (err < 0 && required) {
			swupd_curl_parallel_download_cancel(download_handle);
			return err;
		}
	}
	list_free_list(need_download);
	info("Finishing packs extraction...\n");

	ret = swupd_curl_parallel_download_end(download_handle, NULL);

	/* report missing packs to telemetry */
	if (missing_packs) {
		// there is a lot of extra code here that is meant just to
		// make it easier where the problem is, it will be removed
		// once this is working
		info("\n\nNumber of packs missing: %d\n", count);
		info("\nMissing packs:\n");
		struct list *iter;
		for (iter = list_head(missing_packs); iter; iter = iter->next) {
			char *pack = iter->data;
			info("- %s", pack);
		}
		info("\n");
		// here we can (and should) send missing packs in groups of 10?
		// instead of just adding them all at once
		missing_packs_str = string_join("", missing_packs);
		info("Here is the list of missing packs:\n");
		info("%s", missing_packs_str);
		info("Length: %d\n", strlen(missing_packs_str));
		// here we would send to telemetry
		//telemetry(TELEMETRY_WARN, "packmissing", "%s", missing_packs_str);
		free_string(&missing_packs_str);
		// I tried freeing the list of missing_packs here, but that causes a
		// memory leak for a reason I don't get:
		// Direct leak of 253 byte(s) in 2 object(s) allocated from:
		// in __interceptor_malloc ../../../../gcc-9.1.0/libsanitizer/asan/asan_malloc_linux.cc:144
		// in __vasprintf_internal /usr/src/debug/glibc-2.29/libio/vasprintf.c:71
		//list_free_list(missing_packs);
	}

	return ret;
}
