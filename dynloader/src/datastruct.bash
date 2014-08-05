if [ -z "${__HAVE_SHLIB_DYNLOADER_DATASTRUCT__-}" ]; then

readonly __HAVE_SHLIB_DYNLOADER_DATASTRUCT__=y

# using namespace shlib_dynloader
# using namespace shlib_dynloader_datastruct

# file key (file path without .*sh) => file path
declare -A SHLIB_DYNLOADER__MODULES=()
# lib module name => file path
declare -A SHLIB_DYNLOADER__LIB_MODULES=()

unset -v SHLIB_DYNLOADER__DEPTREE

# <SHLIB_DYNLOADER__MODULES>
# @private int shlib_dynloader__has_module ( module_file_key )
#
shlib_dynloader__has_module() {
   [ -n "${SHLIB_DYNLOADER__MODULES[${1:?}]+SET}" ]
}

# <SHLIB_DYNLOADER__MODULES>
# @private void shlib_dynloader__register_module ( filepath )
#
shlib_dynloader__register_module() {
   : ${1:?}
   SHLIB_DYNLOADER__MODULES["${1%.*sh}"]="${1}"
}

# <SHLIB_DYNLOADER__LIB_MODULES>
# @private int shlib_dynloader__has_lib_module ( name )
#
shlib_dynloader__has_lib_module() {
   [ -n "${SHLIB_DYNLOADER__LIB_MODULES[${1:?}]+SET}" ]
}

# <SHLIB_DYNLOADER__LIB_MODULES>
# <SHLIB_DYNLOADER__MODULES>
# @private int shlib_dynloader__register_lib_module ( name, filepath )
#
shlib_dynloader__register_lib_module() {
   : ${1:?} ${2:?}

   shlib_dynloader__register_module "${2}" && \
   SHLIB_DYNLOADER__LIB_MODULES["${1}"]="${2}"
}

# @private int shlib_dynloader__deptree_has_module ( module_file_key )
#
shlib_dynloader__deptree_has_module() {
   [ -n "${SHLIB_DYNLOADER__DEPTREE[${1:?}]+SET}" ]
}

# @private @stderr int shlib_dynloader__add_module_to_deptree (
#    module_file_key, filepath_abs|NULL, SHLIB_DYNLOADER_ON_ERROR=exit
# )
shlib_dynloader__add_module_to_deptree() {
   : ${1:?<module_file_key> arg missing or empty}
   : ${2:?<filepath_abs> arg missing or empty}

   if shlib_dynloader__deptree_has_module "${1}"; then

      shlib_dynloader__print "*** CIRCULAR MODULE DEPENDENCY DETECTED ***"
      shlib_dynloader__print ">>> ${*} <<<"
      1>&2 declare -p SHLIB_DYNLOADER__DEPTREE
      shlib_dynloader__print "-------------------------------------------"

      shlib_dynloader__error \
         "add_module_to_deptree(): circular dependency" 20

   else
      SHLIB_DYNLOADER__DEPTREE["${1}"]="${2}"
      return 0
   fi
}

shlib_dynloader__init_deptree() {
   declare -gA SHLIB_DYNLOADER__DEPTREE=()
}

shlib_dynloader__unset_deptree() {
   unset -v SHLIB_DYNLOADER__DEPTREE
}

fi # __HAVE_SHLIB_DYNLOADER_DATASTRUCT__
