# void genscript_linked ( script_name, dest_name=<script_name>, *lib_name )
#
#  Calls get_scriptvars( script_name, dest_name ) to set some variables
#  and writes a script linked to the given libs to %dest.
#
#  See genscript_linked__create() for details.
#  Leaks vars (see devel/shlib/base).
#
#  Note:
#    Not passing any lib_name results in linkage against **TARGET_SHLIB_NAME,
#    because this more common than not linking against anything.
#    Pass an empty string to disable this behavior.
#
genscript_linked() {
   print_command "LINK" "$*"
   printcmd_indent
   get_scriptvars "$@" || shift ${?} || OUT_OF_BOUNDS

   if [ $# -eq 0 ]; then
      genscript_linked_create "${TARGET_SHLIB_NAME:?}"
   else
      genscript_linked_create "$@"
   fi
   destfile_done
   printcmd_outdent
}

genscript_linked_lib() {
   print_command "LINK [splitlib]" "$*"
   printcmd_indent
   get_splitlibvars "$@" || shift ${?} || OUT_OF_BOUNDS

   if [ $# -eq 0 ]; then
      genscript_linked_create "${TARGET_SHLIB_NAME:?}"
   else
      genscript_linked_create "$@"
   fi
   destfile_done
   printcmd_outdent
}

genscript_linked_create() {
   [ $# -gt 0 ] || die "genscript_linked_create(): need >= 1 args."
   remove_destfile
   print_command "LINK [shared]" "${script_name}, $*"
   genscript_linked__create "$@" > "${dest}" || \
      die "failed to create '${dest}'" ${?}
}
genscript_linked_append() {
   print_command "LINK [append]" "${dest}${*:+, }${*}"
   genscript_linked__append "$@" >> "${dest}" || \
      die "failed to append ${script} to ${dest}" ${?}
}

# @build_wrapper genscript_linked LINK_SHARED()
#
LINK_SHARED() { autodie scriptvars_leak genscript_linked "$@"; }

LINK_SHARED_LIB() { autodie splitlibvars_leak genscript_linked_lib "$@"; }


# @stdout genscript_linked__create (
#    *lib_name=**TARGET_SHLIB_NAME,
#    **script,
#    **SCRIPT_INTERPRETER,
#     **SCRIPT_SET_U,
#    **TARGET_SHLIB_ROOT
# )
#
#  "Creates" a linked script and prints it stdout.
#  You should make sure that the script is actually creatable,
#  i.e. %script exists all vars are set.
#
genscript_linked__create() {
   : ${*:?}

   echo "#!${SCRIPT_INTERPRETER:?}"
   echo '# -*- coding: utf-8 -*-'
   echo '#'
   echo "# script ${script_name}"
   echo '#'
   [ "${SCRIPT_SET_U}" != "y" ] || echo "set -u"

   echo

   local any_lib v0 lib_name
   for lib_name; do
      if get_target_lib_dest "${lib_name}"; then
         echo ". \"${v0}\" -- || exit"
         any_lib="${v0}"
      fi
   done

   [ -z "${any_lib-}" ] || echo
   grep -v -- ^'#![[:blank:]]*/bin' "${script}"
}

genscript_linked__append() {
   echo
   echo "### begin APPEND ${script_name} ###"
   [ "${SCRIPT_SET_U}" != "y" ] || echo "set -u"
   echo

   local any_lib v0 lib_name
   for lib_name; do
      if get_target_lib_dest "${lib_name}"; then
         echo ". \"${v0}\" -- || exit"
         any_lib="${v0}"
      fi
   done

   [ -z "${any_lib-}" ] || echo
   grep -v -- ^'#![[:blank:]]*/bin' "${script}"
   echo "### end APPEND ${script_name} ###"
}
