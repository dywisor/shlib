if [ -z "${__HAVE_SHLIB_DYNLOADER_MOD_LOADER__-}" ]; then

readonly __HAVE_SHLIB_DYNLOADER_MOD_LOADER__=y


# @private int shlib_dynloader__source_file ( fspath )
#
shlib_dynloader__source_file() {
   : ${1:?<fspath> arg missing or empty}

   shlib_dynloader__debug_print "Loading file ${1}"

   if [ -n "${SHLIB_DYNLOADER_DEPTRACE-}" ]; then
      printf "%s\n" "${1}" >> "${SHLIB_DYNLOADER_DEPTRACE}" || true
   fi

   if . "${1}" --; then
      return 0
   else
      shlib_dynloader__error "failed to source file ${1} (rc=${?})" ${?}
      return ${?}
   fi
}

# @private int shlib_dynloader__locate_file_in_path (
#    PATH, *relpath_variants, **v0!
# )
#
shlib_dynloader__locate_file_in_path() {
   v0=
   : ${1?}

   local path path_iter relpath_iter

   path="${1}"; shift

   shlib_dynloader__debug_print "trying to locate <${*-???}> in ${path}"

   local IFS=":"
   for path_iter in ${path}; do
      IFS="${SHLIB_DYNLOADER__DEFAULT_IFS}"

      [ -z "${path}" ] || \
      for relpath_iter; do

         if [ -f "${path_iter}/${relpath_iter}" ]; then

            shlib_dynloader__debug_print "found ${relpath_iter} in ${path_iter}"

            shlib_dynloader__realpath "${path_iter}/${relpath_iter}"
            return ${?}
         fi

      done

   done

   IFS="${SHLIB_DYNLOADER__DEFAULT_IFS}"

   shlib_dynloader__debug_print "nothing found"
   return 1
}

# @private int shlib_dynloader__locate_shfile_in_shlib_path (
#    base_name, **v0!, **SHLIB_DYNLOADER_PATH
# )
#
shlib_dynloader__locate_shfile_in_shlib_path() {
   local base_name="${1?}"

   set -- "${base_name}.sh"
   [ "${USE_BASH:-n}" != "y" ] || set -- "${base_name}.bash" "${@}"

   shlib_dynloader__locate_file_in_path "${SHLIB_DYNLOADER_PATH}" "${@}"
}


# @private shlib_dynloader__load_relpath_module ( identifier )
#
shlib_dynloader__load_relpath_module() {
   : ${1:?<identifier> arg missing or empty}
   local fbase f

   fbase="${1}"

   if shlib_dynloader__has_module "${fbase}"; then
      shlib_dynloader__debug_print "relpath module ${fbase} already loaded ;)"
      return 0
   fi

   set -- "${fbase}.sh"
   [ "${USE_BASH:-n}" != "y" ] || set -- "${fbase}.bash" "${@}"

   for f; do
      [ -f "${f}" ] || continue

      # COULDFIX: more correct mod register/load/... cycle
      #
      # * add mod to deptree || die
      # * load/resolve mod's dependencies
      # * remove mod from deptree
      # * register module
      # * load it
      # <done>
      #
      # [also in shlib_dynloader__load_library_module()]
      #

      shlib_dynloader__add_module_to_deptree "${f%.*sh}" "${f}" && \
      shlib_dynloader__register_module "${f}"                   && \
      shlib_dynloader__load_dependencies_for_script_file "${f}" && \
      shlib_dynloader__source_file "${f}"

      return ${?}
   done

   shlib_dynloader__error "failed to locate relpath module ${fbase}"
}

# @private shlib_dynloader__load_library_module ( name )
#
shlib_dynloader__load_library_module() {
   : ${1:?<name> arg missing or empty}

   local v0 modfile modfile_key

   if shlib_dynloader__has_lib_module "${1}"; then
      shlib_dynloader__debug_print "lib module ${1} already loaded ;)"
      return 0
   fi

   shlib_dynloader__locate_shfile_in_shlib_path "${1}" || return
   modfile="${v0:?}"
   modfile_key="${modfile%.*sh}"

   if shlib_dynloader__has_module "${modfile_key}"; then
      shlib_dynloader__debug_print \
         "lib module file ${modfile_key} already loaded ;)"
      return 0
   fi

   shlib_dynloader__add_module_to_deptree "${modfile_key}" "${modfile}" && \
   shlib_dynloader__register_lib_module "${1}" "${modfile}"             && \
   shlib_dynloader__load_dependencies_for_script_file "${modfile}"      && \
   shlib_dynloader__source_file "${modfile}"

   return ${?}
}



fi # __HAVE_SHLIB_DYNLOADER_MOD_LOADER__
