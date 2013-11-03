VDR_RECORDMUX_PHASES="before after edited __null__ info"

VDR_FSPATH_VARS_ESSENTIAL="VDR_ROOT VDR_RECORD_HOOK_DIR"
VDR_FSPATH_VARS_UNSETOK="VDR_ROOT_DONE VDR_CHROOT_DIR LOGFILE"
VDR_FSPATH_VARS="${VDR_FSPATH_VARS_ESSENTIAL} ${VDR_FSPATH_VARS_UNSETOK}"
VDR_SCRIPT_VARS="${VDR_FSPATH_VARS_ESSENTIAL} VDR_RECORD_EXT"
VDR_SCRIPT_VARS_EMPTYOK="${VDR_SCRIPT_VARS_EMPTYOK-}"
VDR_SCRIPT_VARS_UNSETOK="${VDR_FSPATH_VARS_UNSETOK} VDR_KEEP_SORT"


### helper functions

# int get_all_vdr_script_vars ( **v0! )
#
#  Stores the names of all VDR_* script vars in %v0.
#
get_all_vdr_script_vars() {
   list_redux \
      ${VDR_RECORD_VARS?} \
      ${VDR_SCRIPT_VARS?} \
      ${VDR_SCRIPT_VARS_EMPTYOK?} \
      ${VDR_SCRIPT_VARS_UNSETOK?}
}


# int cd_to_any_of ( *dirs )
#
#  Changes the working directory to the first non-empty dir that exists.
#
cd_to_any_of() {
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ] && cd "${1}"; then
         return 0
      fi
      shift
   done
   return 1
}

# int vdr_chroot_dir ( **VDR_CHROOT_DIR= )
#
#  Changes the working directory to VDR_CHROOT_DIR, /tmp or /.
#
vdr_chroot_dir() {
   cd_to_any_of "${VDR_CHROOT_DIR-}" /tmp /
}

# @dont-override int run_cmd ( *cmdv )
#
#  Logs cmdv and executes it afterwards if %FAKE_MODE is disabled,
#  else prints the command to stdout.
#
NOT_OVERRIDING run_cmd
run_cmd() {
   if __faking__; then
      einfo "$*" "(cmd)"
   else
      ${LOGGER} --level=DEBUG "cmd: $*"
      "$@"
   fi
}

# @function_alias rmdir_if_empty ( *args ) renames rmdir()
#
#  Removes empty dirs.
#
rmdir_if_empty() {
   rmdir --ignore-fail-on-non-empty "$@"
}

# int vdr_remove_record_dir()
#
vdr_remove_record_dir() {
   # touch VDR_ROOT/.keep again (just to be sure)
   vdr_touch_keepfile "${VDR_ROOT}"

   if cd_to_any_of \
      "${VDR_ROOT}" "${VDR_RECORD_ROOT}" "${VDR_CHROOT_DIR-}" /tmp /
   then
      run_cmd rmdir_if_empty -p -- "${VDR_RECORD_DIR}" 2>>${DEVNULL}
   else
      run_cmd rmdir_if_empty -- "${VDR_RECORD_DIR}"
   fi
}

# int vdr_remove_record_dir_files ( *filenames )
#
vdr_remove_record_dir_files() {
   local fail=0
   local f

   while [ $# -gt 0 ]; do
      f="${VDR_RECORD_DIR}/${1#/}"
      if [ -f "${f}" ] || [ -h "${f}" ]; then
         run_cmd rm -- "${f}" || fail=$(( ${fail} + 1 ))
      fi
      shift
   done

## (retcode not correct if %fail > 255)
   return ${fail}
}

# int vdr_touch_keepfile ( *dirs )
#
vdr_touch_keepfile() {
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ] && [ ! -e "${1}/.keep" ]; then
         run_cmd touch -- "${1}/.keep" || \
            ${LOGGER} --level=WARN "failed to touch ${1}/.keep"
      fi
      shift
   done
}


### recordmux functions (not useful in hooks)

# @override void phasemux_enter()
#
#  Makes some vars readonly.
#
OVERRIDE_FUNCTION phasemux_enter
phasemux_enter() {
   readonly \
      S VDR_RECORDMUX_PHASES DEVNULL \
      ${VDR_FSPATH_VARS?} ${VDR_SCRIPT_VARS?} \
      ${VDR_SCRIPT_VARS_EMPTYOK?} ${VDR_SCRIPT_VARS_UNSETOK?}

   return 0
}

# @override int phasemux_hook_prepare ( **VDR_CHROOT_DIR= )
#
#  pre-phasefunc function that changes to working directory to
#  VDR_CHROOT_DIR if possible and to /tmp or / as fallback.
#
OVERRIDE_FUNCTION phasemux_hook_prepare
phasemux_hook_prepare() {
   vdr_chroot_dir
}

# int vdr_recordmux_run()
#
#  Calls phasemux_run_hook_dir().
#
vdr_recordmux_run() {
   local S="${VDR_RECORD_DIR}"
   vdr_touch_keepfile "${VDR_ROOT}"
   phasemux_run_hook_dir "${VDR_RECORD_STATE}" "${VDR_RECORD_HOOK_DIR}"
}

# int vdr_recordmux_main ( record_state, record_name, [record_new_name] )
#
vdr_recordmux_main() {
   phasedef_register ${VDR_RECORDMUX_PHASES}
   vdr_recordhook_main vdr_recordmux_run "$@"
}


vdr_recordmux_main "$@"
