# @private int chainload__locate_file (
#    filenames, file_extensions=, *dirs=[**SCRIPT_DIR,], **v0!
# )
#
# Returns 2 if no filenames given.
#
chainload__locate_file() {
   v0=
   [ -n "${1-}" ] || return 2

   local fnames="${1}"
   local fexts

   shift

   if [ $# -gt 0 ]; then
      fexts="${1?}"
      shift
   fi

   [ $# -gt 0 ] || set -- "${SCRIPT_DIR:?}"

   local dirpath fname fext k

   # O(dirs*names*fexts)
   for dirpath; do
      for fname in ${fnames}; do
         k="${dirpath%/}/${fname}"
         if [ -f "${k}" ]; then
            v0="${k}"
            return 0
         else
            for fext in ${fexts-}; do
               if [ -f "${k}.${fext#.}" ]; then
                  v0="${k}.${fext#.}"
                  return 0
               fi
            done
         fi
      done
   done

   return 1
}

# @private int chainload__prefer_bash ( **CHAINLOAD_PREFER_BASH=<auto> )
#
chainload__prefer_bash() {
   if [ -z "${CHAINLOAD_PREFER_BASH:+X}" ]; then
      case "${SHELL:-X}" in
         bash|*/bash)
            CHAINLOAD_PREFER_BASH=y
            return 0
         ;;
         *)
            CHAINLOAD_PREFER_BASH=n
            return 1
         ;;
      esac
   fi

   [ "${CHAINLOAD_PREFER_BASH}" = "y" ]
}

# int chainload_load_functions_file (
#    filenames=["shlib", "functions"], *dirs=[**SCRIPT_DIR,],
#    **CHAINLOAD_PREFER_BASH=<auto>
# )
#
#
chainload_load_functions_file() {
   local v0
   local fnames="shlib functions"
   if [ $# -gt 0 ]; then
      [ -z "${1}" ] || fnames="${1}"
      shift
   fi

   local fexts
   if chainload__prefer_bash; then
      fexts="bash sh"
   else
      fexts="sh"
   fi

   if chainload__locate_file "${fnames}" "${fexts}" "$@"; then
      . "${v0}" || \
         die "errors occured while loading functions file '${v0:-UNDEF}'."
   else
      die "could not find functions file '${fnames}'"
   fi
}


# int chainload_locate_script_file (
#    filename, *dirs=[**SCRIPT_DIR,], **CHAINLOAD_PREFER_BASH=<auto>,
#    **v0!
# ), raises die()
#
chainload_locate_script_file() {
   v0=
   local fname="${1:?}"
   shift

   local fexts
   if chainload__prefer_bash; then
      fexts="bash sh"
   else
      fexts="sh"
   fi

   chainload__locate_file "${fname}" "${fexts}" "$@" || \
      die "cannot locate script file '${fname}'."
}

# int chainload_load_script_file (
#    filename, *args, **SCRIPT_DIR, **CHAINLOAD_PREFER_BASH=<auto>
# ), raises die()
#
chainload_load_script_file() {
   local v0
   [ -n "${1-}" ] || \
      die "Usage: ${SCRIPT_NAME} <script> [<arg>...]" ${EX_USAGE}

   chainload_locate_script_file "${1}"
   local CHAINLOAD_SCRIPT="${v0}"
   shift
   eval_scriptinfo "${CHAINLOAD_SCRIPT}"
   . "${CHAINLOAD_SCRIPT}" "$@"
}
