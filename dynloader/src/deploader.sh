if [ -z "${__HAVE_SHLIB_DYNLOADER_DEP_LOADER__-}" ]; then

readonly __HAVE_SHLIB_DYNLOADER_DEP_LOADER__=y

# @private int shlib_dynloader__load_dependency (
#    identifier, relpath_root, **SHLIB_DYNLOADER_ON_ERROR
#
shlib_dynloader__load_dependency() {
   : ${1?<identifier> arg missing} ${2:?<relpath_root> arg missing or empty}

   local v0

   case "${1}" in

      ''|'#'*|'!'*)
         true
      ;;

      ./*|../*)
         shlib_dynloader__realpath "${2}/${1}" "dep relpath" || return ${?}

         # implemented by shloader
         shlib_dynloader__load_relpath_module "${v0}" || return
      ;;

      *)
         # implemented by shloader
         shlib_dynloader__load_library_module "${1}" || return
      ;;

   esac
}

# @private int shlib_dynloader__load_dependencies_from_file (
#    depfile, relpath_root
# )
#
shlib_dynloader__load_dependencies_from_file() {
   : ${1:?<depfile> arg missing or empty}
   : ${2:?<relpath_root> arg missing or empty}
   local dep

   if [ ! -f "${1}" ]; then
      shlib_dynloader__error
         "in shlib_dynloader__load_dependencies_from_file()" \
         "depfile '${1}' does not exist!"
      return ${?}
   fi

   while read -r dep; do
      shlib_dynloader__load_dependency "${dep}" "${2}" || return ${?}
   done < "${1}"
}

# @private int shlib_dynloader__load_dependencies_for_script_file (
#    script_file_abs
# )
#
shlib_dynloader__load_dependencies_for_script_file() {
   : ${1:?<script_file_abs> arg missing or empty>}

   local f

   for f in "${1}.depend" "${1%.*sh}.depend"; do
      if [ -f "${f}" ]; then
         shlib_dynloader__load_dependencies_from_file "${f}" "${1%/*}"
         return ${?}
      fi
   done

   shlib_dynloader__debug_print "${1} has no .depend file."
   return 0
}


fi # __HAVE_SHLIB_DYNLOADER_DEP_LOADER__
