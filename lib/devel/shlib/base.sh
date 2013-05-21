# @extern void print_command ( exe, *argv, **PRINTCMD_... )
# @extern void print_pwd     ( [message], **PWD, **PRINTCMD_... )
#
# @extern :: from message: einfo(),ewarn(),eerror(),veinfo(),printvar()
# @extern :: all from autodie
# @extern :: all from die
# @extern :: all from devel/shlib/defsym
# @extern :: all from devel/shlib/scriptvars
# @extern :: all from devel/shlib/wrapper
#

# @noreturn OUT_OF_BOUNDS(), raises die()
#
#  die() wrapper for failing shift commands.
#
OUT_OF_BOUNDS() { die "shift returned non-zero (${?})." 22; }

# void set_build_dir ( dirpath, **BUILD_ROOT, **BUILD_DIR! )
#
set_build_dir() {
   case "${1:?}" in
      //*)
         BUILD_DIR="${1#/}"
      ;;
      *)
         BUILD_DIR="${BUILD_ROOT:?}/${1#/}"
      ;;
   esac
   print_command INTO "${BUILD_DIR:?}"
}

remove_destfile() {
   if [ ! -e "${dest:?}" ]; then
      [ ! -h "${dest:?}" ] || autodie rm -- "${dest}"
      return 0
   elif [ -f "${dest:?}" ]; then
      if [ "${SCRIPT_OVERWRITE:-n}" = "y" ]; then
         print_command "+ OVERWRITE" "${dest}"
         autodie rm -- "${dest}"
      else
         die "destfile '${dest}' exists."
      fi
   else
      die "destfile '${dest}' exists and cannot be overwritten (not a file?)."
   fi
}

destfile_done() {
   : ${dest:?}

   [ -f "${dest}" ] || \
      die "dest file '${dest}' does not exist (but it should)."

   [ "${SCRIPT_AUTO_VERIFY:-n}" != "y" ] || verify_script "${dest}"

   if \
      [ -n "${DESTFILE_CHMOD-}" ] && [ "${SCRIPT_AUTO_CHMOD:-n}" = "y" ]
   then
      print_command CHMOD "${dest} (${DESTFILE_CHMOD})"
      autodie chmod -- ${DESTFILE_CHMOD} "${dest}"
   fi
   if \
      [ -n "${DESTFILE_CHOWN-}" ] && [ "${SCRIPT_AUTO_CHOWN:-n}" = "y" ]
   then
      print_command CHOWN "${dest} (${DESTFILE_CHOWN})"
      autodie chown -- ${DESTFILE_CHOWN} "${dest}"
   fi
}


# void verify_script ( *shfile, **SCRIPT_USE_BASH, **BUSYBOX_ASH )
#
verify_script() {
   print_command VERIFY "$*"
   local shfile
   local any_interpreter

   if [ "${SCRIPT_USE_BASH:?}" = "y" ] || [ -n "${BUSYBOX_ASH-}" ]; then
      true
   elif [ -x /bin/busybox ] && /bin/busybox --list | grep -qx ash; then
      local BUSYBOX_ASH="/bin/busybox ash"
   fi

   for shfile; do
      any_interpreter=

      if [ -x /bin/bash ]; then
         autodie /bin/bash -n "${shfile}" && any_interpreter=bash
      elif [ "${SCRIPT_USE_BASH}" = "y" ]; then
         die "/bin/bash not available and SCRIPT_USE_BASH=y."
      fi

      if [ "${SCRIPT_USE_BASH}" != "y" ]; then
         if [ -x /bin/dash ]; then
            autodie /bin/dash -n "${shfile}" && any_interpreter=dash
         fi

         if [ -n "${BUSYBOX_ASH-}" ]; then
            autodie ${BUSYBOX_ASH} -n "${shfile}" && \
               any_interpreter="${BUSYBOX_ASH}"
         fi
      fi

      if [ -z "${any_interpreter-}" ]; then
         die "cannot test '${shfile}': no interpreter found."
      fi
   done
}

# @build_wrapper verify_script VERIFY()
VERIFY() { autodie scriptvars_noleak verify_script "${@}"; }
