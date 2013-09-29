#!/bin/sh

set -u
chainload_load_functions_file
chainload_load_script_file "$@"
