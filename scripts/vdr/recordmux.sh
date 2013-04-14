# config keys
# * VDR_ROOT
# * VDR_ROOT_DONE
# * VDR_ROOT_ARRAY
# * VDR_RECORD_HOOK_DIR
#
readconfig /etc/vdr/recordhook.conf

VDR_ROOT=`readlink -f "${VDR_ROOT}"`
varcheck VDR_ROOT VDR_RECORD_HOOK_DIR

if [ -n "${VDR_ROOT_DONE-}" ]; then
   VDR_ROOT_DONE=`readlink -f "${VDR_ROOT_DONE}"`
   varcheck VDR_ROOT_DONE
fi

vdr_script_get_record_vars "$@"
VARCHECK_ALLOW_EMPTY=y varcheck ${VDR_RECORD_VARS}

readonly ${VDR_RECORD_VARS}

readonly S="${VDR_RECORD_DIR}"
readonly PHASE="${VDR_RECORD_STATE}"

# int vdr_chroot_dir ( **VDR_CHROOT_DIR= )
#
#  Changes the working directory to VDR_CHROOT_DIR, /tmp or /.
#
vdr_chroot_dir() {
   if [ -z "${VDR_CHROOT_DIR-}" ] || ! cd "${VDR_CHROOT_DIR}"; then
      cd /tmp || cd /
   fi
}

# int is_phase ( phase=**PHASE )
#
#  Returns 0 if phase is a phase.
#
is_phase() {
   case "${1-${PHASE}}" in
      'before'|'after'|'edited')
         return 0
      ;;
      *)
         return 1
      ;;
   esac
}


# int is_null_phase ( phase=**PHASE )
#
#  Returns 0 if phase is the null phase.
#
is_null_phase() { [ "${1-${PHASE}}" = "__null__" ]; }

if [ "${FAKE_MODE:-n}" = "y" ]; then
# void run_cmd ( *cmdv )
#
#  Echoes cmdv to stdout.
#
run_cmd() {
   einfo "$*" "(cmd)"
}
else
# void run_cmd ( *cmdv )
#
#  Logs cmdv and executes it.
#
run_cmd() {
   ${LOGGER} --level=DEBUG "cmd: $*"
   "$@"
}
fi

# int run_hooks ( **... )
#
#  Runs all vdr record hooks.
#
run_hooks() {
   is_phase || is_null_phase || return

   local hook hook_name
   for hook in "${VDR_RECORD_HOOK_DIR}/"*.sh; do
      hook_name="${hook##*/}"
      hook_name="${hook_name%.sh}"

      [ ! -f "${hook}" ] || \
      (
         readonly __SUBSHELL__=y

         PHASE_RESTRICT=

         unset -f before after edited __null__ any_phase

         ! is_null_phase || __null__() { echo "${hook_name}::__null__()"; }

         if ! . "${hook}"; then
            false

         elif list_has "${PHASE}" ${PHASE_RESTRICT}; then
            true

         elif function_defined "${PHASE}"; then
            vdr_chroot_dir
            ${PHASE}

         elif function_defined any_phase; then
            vdr_chroot_dir
            any_phase

         else
            true
         fi
      )
   done

}

vdr_chroot_dir
run_hooks
