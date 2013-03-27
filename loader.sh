#!/bin/dash
if [ -z "${__HAVE_SHLIB_LOADER__:-}" ]; then
readonly __HAVE_SHLIB_LOADER__=y

# function file loader
#  this is what you should source in scripts that want to load shlib
#  modules dynamically.
#
#  In contrast to linked function files / scripts, this has a few drawbacks,
#  most notably:
#  * no dependency resolution (dependencies are loaded as soon
#    as they\'re from the dep file)
#  * no support for loading whole directories
#
# Note: you do not need this loader if you link the function files
#       "statically" (e.g. when using shlibcc --link)
#

if [ -d /usr/lib/shlib ]; then
   readonly DEFAULT_SHLIB_ROOT=/usr/lib/shlib
else
   readonly DEFAULT_SHLIB_ROOT=/usr/local/lib/shlib
fi

if [ -n "${1:-}" ]; then
   SHLIB_ROOT="${1}"
else
   SHLIB_ROOT="${DEFAULT_SHLIB_ROOT}"
fi

# @private void loader__run_depend (
#    module_name,
#    depend_file,
#    **LOADER_DEPTREE=
# ), raises exit()
#
#  Reads and loads all dependencies for a module.
#  Dies if a circular dependency is detected (error code 199).
#  !!! Dependencies on self (e.g. "depend on die" while loading die) are
#      an error, too
#
loader__run_depend() {
   local LOADER_DEPTREE="${LOADER_DEPTREE:-}${LOADER_DEPTREE:+ }${1?}"
   local dep iter
   while read dep; do
      # empty?, comment?
      if [ -n "${dep}" ] && [ "x${dep#\#}" = "x${dep}" ]; then
         for iter in ${LOADER_DEPTREE}; do
            if [ "x${dep}" = "x${iter}" ]; then
               echo "circular dependency found! This is critical." 1>&2
               echo "dep tree=<${LOADER_DEPTREE}>." 1>&2
               exit 199
            fi
         done
         loader_load "${dep}"
      fi
   done < "${2:?}"
}

# void loader_load (
#    *module_name,
#    **BASH_VERSION=,
#    **SHLIB_ROOT,
#    [**LOADER_DEPTREE]
#  ), raises exit()
#
#  Loads zero or more modules by name. Properly detects whether the current
#  shell interpreter is bash in which case bash files (.bash) are loaded
#  whenever available. Else loads normal shell files (.sh).
#  Also handles module dependencies.
#
# arguments:
# * *module_name     -- list of modules to be loaded
# * **BASH_VERSION   -- used to detect whether using bash
# * **SHLIB_ROOT      -- shlib root directory
# * **LOADER_DEPTREE -- the current module dependency tree,
#                        will passed to loader__run_depend()
#
loader_load() {
   local MODULE MODULE_COMMON
   while [ $# -gt 0 ]; do

      if [ -n "${1:-}" ]; then
         # locate module
         if [ -d "${SHLIB_ROOT}/${1}" ]; then
            echo "load module directory: not implemented." 1>&2
            exit 194

         elif \
            [ -n "${BASH_VERSION-}" ] && [ -f "${SHLIB_ROOT}/${1}.bash" ]
         then
            MODULE="${SHLIB_ROOT}/${1}.bash"

         elif [ -f "${SHLIB_ROOT}/${1}.sh" ]; then
            MODULE="${SHLIB_ROOT}/${1}.sh"

         else
            echo "module not found: '${1}'" 1>&2
            exit 193
         fi

         # load module dependencies, if any
         if [ -e "${MODULE}.depend" ]; then
            loader__run_depend "$1" "${MODULE}.depend"
         elif [ -e "${MODULE%.*sh}.depend" ]; then
            loader__run_depend "$1" "${MODULE%.*sh}.depend"
         fi

         # load module
         if ! . "${MODULE}" --as-lib; then
            echo "cannot load module '${1}'" 1>&2
            exit 192
         fi
      fi

      shift
   done
}

fi
