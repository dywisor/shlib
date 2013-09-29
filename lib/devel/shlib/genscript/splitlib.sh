# makelib_split_standalone (
#    script_name, dest_name=<script_name>, *exclude_module,
#    **script!, **script_name!, **dest!, **dest_name!
# )
#
makelib_split() {
   print_command "MAKELIB [split]" "$*"
   printcmd_indent
   get_splitlibvars "$@" || shift ${?} || OUT_OF_BOUNDS
   remove_destfile

   if [ $# -gt 0 ]; then
      local k x=
      for k; do x="${x} -x ${k}"; done
      CC_splitlib ${x}
   else
      CC_splitlib
   fi

   destfile_done
   printcmd_outdent
}

SPLITLIB() { autodie splitlibvars_leak makelib_split "$@"; }
SPLITLIB_X() { SPLITLIB "${1:?}" "$@"; }

# change name asap
genscript_linked_splitlib() {
   print_command "LINK [split]" "$*"
   printcmd_indent
   get_scriptvars "$@" || shift ${?} || OUT_OF_BOUNDS

   local v0
   autodie get_target_splitlib_dest "${dest_name}"

   genscript_linked_create "$@" "${v0:?}"

   destfile_done
   printcmd_outdent
}

genscript_splitlib_append() {
   print_command "APPEND [splitlib]" "$*"
   printcmd_indent
   get_splitlibvars "$@" || shift ${?} || OUT_OF_BOUNDS

   genscript_linked_append "$@"
   printcmd_outdent
}

LINK_SPLITLIB() { autodie scriptvars_leak genscript_linked_splitlib "$@"; }
SPLITLIB_LINK() { LINK_SPLITLIB "$@"; }

LINK_SPLITLIB_STDLIB() { LINK_SPLITLIB "$@" "${TARGET_SHLIB_NAME:?}"; }
SPLITLIB_LINK_STDLIB() { LINK_SPLITLIB "$@" "${TARGET_SHLIB_NAME:?}"; }

SPLITLIB_SCRIPT() {
   splitlibvars_noleak SPLITLIB "$@"
   LINK_SPLITLIB "${1-}" "${2-}"
}
SPLITLIB_SCRIPT_X() {
   splitlibvars_noleak SPLITLIB_X "${1:?}" "$@"
   LINK_SPLITLIB "${1:?}" "${1:?}"
}

# SPLITLIB_APPEND ( script_name, dest_lib_name, *lib_name )
SPLITLIB_APPEND() { autodie splitlibvars_leak genscript_splitlib_append "$@"; }
