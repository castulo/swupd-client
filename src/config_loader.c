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

#include "swupd.h"

#define strlen_const(_const) sizeof(_const) - 1
#define strncmp_const(_str, _const) strncmp(_str, _const, strlen_const(_const))

static bool eval_bool(const char *value)
{
	if (strcmp(value, "true") == 0) {
		return true;
	}
	/* return false for everything else */
	return false;

}

bool load_config_value(char *section, char *key, char *value) {

	/* check for global options first */
	if (!section) {

		if (strncmp_const(key, "path") == 0) {
			return load_global_config_value('p', value);
		} else if (strncmp_const(key, "url") == 0) {
			return load_global_config_value('u', value);
		} else if (strncmp_const(key, "port") == 0) {
			return load_global_config_value('P', value);
		} else if (strncmp_const(key, "contenturl") == 0) {
			return load_global_config_value('c', value);
		} else if (strncmp_const(key, "versionurl") == 0) {
			return load_global_config_value('v', value);
		} else if (strncmp_const(key, "format") == 0) {
			return load_global_config_value('F', value);
		} else if (strncmp_const(key, "statedir") == 0) {
			return load_global_config_value('S', value);
		} else if (strncmp_const(key, "certpath") == 0) {
			return load_global_config_value('C', value);
		} else if (strncmp_const(key, "max-parallel-downloads") == 0) {
			return load_global_config_value('W', value);
		} else if (strncmp_const(key, "max-retries") == 0) {
			return load_global_config_value('r', value);
		} else if (strncmp_const(key, "retry-delay") == 0) {
			return load_global_config_value('d', value);
		} else if (strncmp_const(key, "json_output") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('j', value);
			}
		} else if (strncmp_const(key, "ignore_time") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('I', value);
			}
		} else if (strncmp_const(key, "time") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('t', value);
			}
		}  else if (strncmp_const(key, "nosigcheck") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('n', value);
			}
		} else if (strncmp_const(key, "no_boot_update") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('b', value);
			}
		} else if (strncmp_const(key, "no_scripts") == 0) {
			if (eval_bool(value)) {
				return load_global_config_value('N', value);
			}
		}

	}

	return true;

}
