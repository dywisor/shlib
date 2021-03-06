if [ -z "${__HAVE_SHLIB_DYNLOADER_DATASTRUCT__-}" ]; then

# differences to the bash module:
# * no whitespace in file paths allowed -- and this file doesn't check for it
# * using newline/space-separated lists, making slower
# * NOTHING IMPLEMENTED SO FAR

RAISE_NOT_IMPLEMENTED() { echo "NOT IMPLEMENTED" 1>&2; exit 99; }


# <SHLIB_DYNLOADER__MODULES>
# @private int shlib_dynloader__has_module ( module_file_key )
#
shlib_dynloader__has_module() {
   RAISE_NOT_IMPLEMENTED
}

# <SHLIB_DYNLOADER__MODULES>
# @private void shlib_dynloader__register_module ( filepath )
#
shlib_dynloader__register_module() {
   : ${1:?}

   RAISE_NOT_IMPLEMENTED
}

# <SHLIB_DYNLOADER__LIB_MODULES>
# @private int shlib_dynloader__has_lib_module ( name )
#
shlib_dynloader__has_lib_module() {
   RAISE_NOT_IMPLEMENTED
}

# <SHLIB_DYNLOADER__LIB_MODULES>
# <SHLIB_DYNLOADER__MODULES>
# @private int shlib_dynloader__register_lib_module ( name, filepath )
#
shlib_dynloader__register_lib_module() {
   : ${1:?} ${2:?}

   RAISE_NOT_IMPLEMENTED
}

# @private int shlib_dynloader__deptree_has_module ( module_file_key )
#
shlib_dynloader__deptree_has_module() {
   RAISE_NOT_IMPLEMENTED
}

# @private @stderr int shlib_dynloader__add_module_to_deptree (
#    module_file_key, filepath_abs|NULL, SHLIB_DYNLOADER_ON_ERROR=exit
# )
shlib_dynloader__add_module_to_deptree() {
   : ${1:?<module_file_key> arg missing or empty}
   : ${2:?<filepath_abs> arg missing or empty}

   RAISE_NOT_IMPLEMENTED
}

shlib_dynloader__init_deptree() {
   RAISE_NOT_IMPLEMENTED
}

shlib_dynloader__unset_deptree() {
   RAISE_NOT_IMPLEMENTED
}


fi # __HAVE_SHLIB_DYNLOADER_DATASTRUCT__
