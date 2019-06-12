#ifndef __CONFIG_PARSER__
#define __CONFIG_PARSER__

/**
 * @file
 * @brief TBD
 */

#include <stdio.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief TBD
 */
typedef bool (*load_config_fn_t)(char *section, char *key, char *value);

/**
 * @brief TBD
 */
bool config_parse(const char *filename, load_config_fn_t load_config_fn);

#ifdef __cplusplus
}
#endif
#endif
