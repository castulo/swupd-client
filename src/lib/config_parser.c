/*
 *   Software Updater - client side
 *
 *      Copyright © 2012-2019 Intel Corporation.
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
 */

#define _GNU_SOURCE

#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "config_parser.h"
#include "log.h"
#include "macros.h"
#include "strings.h"

#define CONFIG_LINE_MAXLEN (PATH_MAX * 2)

bool config_parse(const char *filename, load_config_fn_t load_config_fn)
{
	FILE *config_file;
	char line[CONFIG_LINE_MAXLEN];
	char *line_ptr;
	char *section = NULL;
	char *key = NULL;
	char *value = NULL;
	bool ret = false;

	config_file = fopen(filename, "rbm");
	if (config_file == NULL) {
		error("Configuration file %s not found\n", filename);
		goto exit;
	}

	/* read the config file line by line */
	while (!feof(config_file)) {

		/* read next line */
		if (fgets(line, CONFIG_LINE_MAXLEN, config_file) == NULL) {
			break;
		}

		/* remove the line break from the current line */
		line_ptr = strchr(line, '\n');
		if (!line_ptr) {
			error("\ninvalid configuration file %s \n", filename);
			error("the following line is missing a line break: %s \n\n", line);
			goto close_and_exit;
		}
		*line_ptr = '\0';

		/* check the line to see if it is a comment (start with ; or #) */
		if (line[0] == ';' || line[0] == '#') {
			continue;
		}

		/* check the line to see if the line is a section */
		if (line[0] == '[' && *(line_ptr - 1) == ']') {
			*(line_ptr - 1) = '\0';
			section = strdup_or_die(line + 1);
		}

		/* check the line to see if it is a key/value pair */
		line_ptr = strchr(line, '=');
		if (!line_ptr) {
			/* this is probably a blank line or something unrecognized,
			 * ignore the line */
			continue;
		}
		*line_ptr = '\0';
		key = strdup_or_die(line);
		value = strdup_or_die(line_ptr + 1);

		/* load the configuration value read in the application */
		if (!load_config_fn(section, key, value)) {
			goto close_and_exit;
		}

	}

	/* we made it this far, config file parsed correctly */
	ret = true;

close_and_exit:
	free_string(&section);
	free_string(&key);
	free_string(&value);
	fclose(config_file);
exit:
	if (!ret) {
		error("there was a problem loading the values from the configuration file '%s'\n", filename);
		info("Please make sure the key/values are correct\n");
	}
	return ret;

}
