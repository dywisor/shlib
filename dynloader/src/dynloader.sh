if [ -z "${__HAVE_SHLIB_DYNLOADER_MAIN__-}" ]; then

readonly __HAVE_SHLIB_DYNLOADER_MAIN__=y

# int shlib_dynloader_load_deps ( *dependencies )
#
shlib_dynloader_load_deps() {
   shlib_dynloader_setup_if_required || return
   shlib_dynloader__init_deptree || return

   local ret=0

   while [ ${#} -gt 0 ]; do
      if \
         shlib_dynloader__load_dependency "${1}" \
            "${SHLIB_DYNLOADER_RELPATH_ROOT:-${PWD}}"
      then
         true
      else
         ret=${?}
         break
      fi
      shift
   done

   shlib_dynloader__unset_deptree
   return ${ret}
}

# int shlib_dynloader_load_depfile ( depfile )
#
shlib_dynloader_load_depfile() {
   : ${1:?<depfile> arg missing or empty}

   local v0 depfile ret

   shlib_dynloader_setup_if_required || return

   shlib_dynloader__realpath "${1}" || return
   depfile="${v0}"

   if [ ! -f "${depfile}" ]; then
      shlib_dynloader__error "no such file: ${1} (${depfile}?)"
      return ${?}
   fi

   shlib_dynloader__init_deptree || return

   v0="${depfile%.depend}"
   v0="${v0%.*sh}"

   if ! shlib_dynloader__add_module_to_deptree "${v0}" __maindep__; then
      shlib_dynloader__error \
         "BUG: add_module_to_deptree() failed on first insertion!"
      exit 200
   fi

   ret=0
   shlib_dynloader__load_dependencies_from_file \
      "${depfile}" "${depfile%/*}" || ret=$?

   shlib_dynloader__unset_deptree
   return ${ret}
}

# int shlib_dynloader_load_script_deps ( script_file, **script_file! )
#
shlib_dynloader_load_script_deps() {
   : ${1:?<script_file> arg missing or empty}
   script_file=

   local v0 ret

   shlib_dynloader_setup_if_required || return

   shlib_dynloader__realpath "${1}" || return
   script_file="${v0}"

   if [ ! -f "${script_file}" ]; then
      shlib_dynloader__error "no such file: ${1} (${script_file}?)"
      return ${?}
   fi

   shlib_dynloader__init_deptree || return

   if ! shlib_dynloader__add_module_to_deptree \
      "${script_file%.*sh}" __main__
   then
      shlib_dynloader__error \
         "BUG: add_module_to_deptree() failed on first insertion!"
      exit 200
   fi

   ret=0
   shlib_dynloader__load_dependencies_for_script_file \
      "${script_file}" || ret=${?}

   shlib_dynloader__unset_deptree
   return ${ret}
}

# @private int shlib_dynloader__runscript_exec ( *args, **script_file )
#
shlib_dynloader__runscript_exec() {
   eval_scriptinfo "${script_file:?}" || return

   script_file=

   . "${SCRIPT_FILE:?}" "${@}"
}

# @private int shlib_dynloader__runscript_exec_subshell ( *args, **script_file )
#
shlib_dynloader__runscript_exec_subshell() (
   eval_scriptinfo "${script_file:?}" || return

   unset -v script_file

   . "${SCRIPT_FILE:?}" "${@}"
)

# @private int shlib_dynloader__runscript (
#    script_file, *args, **F_SHLIB_DYNLOADER_RUNSCRIPT_EXEC
# )
#
shlib_dynloader__runscript() {
   : ${1:?<script_file> arg missing or empty}
   local script_file

   shlib_dynloader_load_deps scriptinfo    || return
   shlib_dynloader_load_script_deps "${1}" || return

   shift && \
   shlib_dynloader__runscript_${F_SHLIB_DYNLOADER_RUNSCRIPT_EXEC:?} "${@}"
}

# @subshell int shlib_dynloader_runscript ( script_file, *args )
#
shlib_dynloader_runscript() {
   local F_SHLIB_DYNLOADER_RUNSCRIPT_EXEC=exec_subshell
   shlib_dynloader__runscript "${@}"
}

# int shlib_dynloader_runscript_inshell ( script_file, *args )
#
shlib_dynloader_runscript_inshell() {
   local F_SHLIB_DYNLOADER_RUNSCRIPT_EXEC=exec
   shlib_dynloader__runscript "${@}"
}

fi # __HAVE_SHLIB_DYNLOADER_MAIN__
