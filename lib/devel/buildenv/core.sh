# buildenv -- run commands in a build environment,
# which is basically a restricted view of the current environment,
# but also includes actions like cd-ing into the build directory before
# running a command.
#
# quickref:
#
# void buildenv_prepare()   -- workdir, srcdir
# int buildenv_make()       -- *argv
# int buildenv_run()        -- *cmdv
# int buildenv_run_in_src() -- *cmdv
# int buildenv_prepare_do() -- workdir, srcdir, cmd, *argv
# int buildenv_printrun()   -- *cmdv
#
#
# Basic usage:
#
#  Run buildenv_prepare() to set up the build environment,
#  and call buildenv_make() or buildenv_run() afterwards.
#
#

# int buildenv_run ( *cmdv, **BUILDENV_WORKDIR, **BUILDENV_UNSET_VARS )
#
#  Runs cmdv in the build environment.
#
buildenv_run() {
   (
      __BUILDENV_SUBSHELL=y
      if [ -n "${BUILDENV_WORKDIR-}" ]; then
         cd -P "${BUILDENV_WORKDIR}" || exit
      fi
      unset -v ${BUILDENV_UNSET_VARS-}
      buildenv_printrun "$@"
   )
}

# @function_alias buildenv_run_in_work() renames buildenv_run()
buildenv_run_in_work() { buildenv_run "$@"; }

# int buildenv_run_in_src ( *cmdv, **BUILDENV_SRCDIR, **BUILDENV_UNSET_VARS )
#
#  Runs cmdv in the build environment's source dir.
#
buildenv_run_in_src() {
   (
      __BUILDENV_SUBSHELL=y
      if [ -n "${BUILDENV_SRCDIR-}" ]; then
         cd -P "${BUILDENV_SRCDIR}" || exit
      fi
      unset -v ${BUILDENV_UNSET_VARS-}
      buildenv_printrun "$@"
   )
}

# int buildenv_make (
#    *argv, **BUILDENV_WORKDIR, **BUILDENV_SRCDIR,
#    **BUILDENV_UNSET_VARS,
#    **BUILDENV_HOSTBUILD, **ARCH, **CROSS_COMPILE,
#    **BUILDENV_MAKE="make", **BUILDENV_MAKEOPTS
# )
#
#  Runs "make *argv" in the build environment.
#
buildenv_make() {
   (
      __BUILDENV_SUBSHELL=y
      if [ -n "${BUILDENV_WORKDIR-}" ]; then
         cd -P "${BUILDENV_WORKDIR}" || exit
      fi
      unset -v ${BUILDENV_UNSET_VARS-}

      if [ "${BUILDENV_HOSTBUILD:-n}" != "y" ]; then
         [ -z "${ARCH-}"          ] || export ARCH
         [ -z "${CROSS_COMPILE-}" ] || export CROSS_COMPILE
      else
         unset -v ARCH CROSS_COMPILE
      fi

      buildenv_printrun ${BUILDENV_MAKE:-make} O="${PWD}" \
         -C "${BUILDENV_SRCDIR:-${PWD}}/" ${BUILDENV_MAKEOPTS-} "$@"
   )
}

# void buildenv_prepare (
#    workdir=<PWD>, srcdir=<PWD>,
#    **BUILDENV_MAKEOPTS!, **BUILDENV_WORKDIR!, **BUILDENV_SRCDIR!
# )
#
#  Initializes buildenv-related variables.
#
buildenv_prepare() {
   BUILDENV_WORKDIR="${1:-${PWD}}"
   BUILDENV_SRCDIR="${2:-${PWD}}"
   if [ "x${BUILDENV_MAKEOPTS-A}" != "x${BUILDENV_MAKEOPTS-B}" ]; then
      local CPUCOUNT
      buildenv_get_cpucount && BUILDENV_MAKEOPTS="-j${CPUCOUNT}"
   fi
}

# int buildenv_prepare_do (
#    workdir=<PWD>, srcdir=<PWD>, cmd, *argv,
#    **BUILDENV_ONESHOT=n, **...
# )
#
#  Calls buildenv_prepare ( %workdir, %srcdir ) and then %cmd ( *argv ).
#
#  Globally sets BUILDENV_WORKDIR and BUILDENV_SRCDIR unless BUILDENV_ONESHOT
#  is set to 'y'.
#
buildenv_prepare_do() {
   [ $# -ge 3 ] || return
   local cmd="${3:?}"
   if [ "${BUILDENV_ONESHOT:-n}" = "y" ]; then
      local BUILDENV_WORKDIR BUILDENV_SRCDIR
   fi

   buildenv_prepare "${1}" "${2}" && \
   shift 3 && \
   ${cmd} "$@"
}


# int buildenv_get_cpucount()
#
#  Sets the CPUCOUNT variable to >= 1.
#
#  Returns 0 if the correct cpu count has been determined, else 1.
#
buildenv_get_cpucount() {
   CPUCOUNT=`grep -c -x -- \
      processor[[:blank:]][[:blank:]]*[:][[:blank:]]*[0-9][0-9]* \
      /proc/cpuinfo`
   if [ "${CPUCOUNT}" -gt 0 2>/dev/null ]; then
      return 0
   else
      CPUCOUNT=1
      return 1
   fi
}

# int buildenv_printrun ( *cmdv )
#
#  Prints cmdv using einfo() and runs it afterwards.
#
#  Note:
#   cmdv will not be run in the build environment.
#
buildenv_printrun() {
   if __quiet__; then
      "$@"
      return ${?}

   else
      if [ "${__BUILDENV_SUBSHELL:-n}" = "y" ]; then
         einfo "buildenv [subshell]: running command '$*'"
      else
         einfo "buildenv: running command '$*'"
      fi
      local rc=0

      "$@" || rc=$?
      if [ ${rc} -eq 0 ]; then
         veinfo "SUCCESS: '$*'"
         return 0
      else
         eerror "command '$*' returned ${rc}."
         return ${rc}
      fi
   fi
}
