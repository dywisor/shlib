#!/bin/sh
#@section header
#
#  Usage:
#     make-shlibcc-wrapper <type> <shlib> [<shlibcc> [<shell>]]
#
#    * type is one of
#    -> shlibcc/default -- shlibcc wrapper (shlibcc -S <shlib>)
#    -> scriptgen/make  -- script creation wrapper (shlibcc -S <shlib> -D --main)
#
#    * shlib is the path to shlib's lib root
#
#    * shlibcc defaults to /usr/bin/shlibcc
#
#    * shell defaults to sh and can be sh, ash, bash or dash
#
#
#  Environment variables that have an effect on wrapper creation:
#
#  * SHLIBCC_PYTHONPATH,
#     the wrapper script export PYTHONPATH if this var is not empty
#
#

#@section functions

# void die_usage ( message, exit_code=64 )
#
die_usage() {
   echo "${1?}" 1>&2
   exit ${2:-64}
}

# @stdout void quote_args ( *args )
#
quote_args() {
   while [ $# -gt 0 ]; do
      echo -n " \"${1}\""
      shift
   done
}

# @stdout void quote_cmdv ( cmd, *args )
#
quote_cmdv() {
   : ${1?}
   echo -n "\"${1?}\""
   shift
   quote_args "$@"
   echo
}

# @stdout void gen_wrapper (
#    *args,
#    **X_SHLIBCC, **SHLIB_DIR,
#    **WRAPPER_SHELL="/bin/sh", **SHLIBCC_PYTHONPATH=, **SHLIBCC_SHELL="sh"
# )
#
gen_wrapper() {
   echo "#!${WRAPPER_SHELL:-/bin/sh}"
   if [ -n "${SHLIBCC_PYTHONPATH-}" ]; then
      echo "export PYTHONPATH=\"${SHLIBCC_PYTHONPATH}\${PYTHONPATH:+:}\${PYTHONPATH-}\""
   fi
   quote_cmdv "exec" "${X_SHLIBCC}" \
      -S "${SHLIB_DIR}" --shell "${SHLIBCC_SHELL:-sh}" "$@" "\${@}"
}

# @stdout void removes_slashes ( fspath )
#
remove_slashes() {
   echo "${1}" | sed -r -e 's,[/]+$,,' -e 's,[/]+,/,g'
}

# void check_path_allowed ( fspath, name ), raises die_usage()
#
check_path_allowed() {
   if [ -z "${1?}" ]; then
      die_usage "\$${2:?} must not be /"
   elif [ "${1#/}" = "${1}" ]; then
      die_usage "\$${2:?} must be an absolute filesystem path"
   fi
}


set -u

: ${SHLIBCC_PYTHONPATH=}
SHLIB_DIR="${2:?}"
SHLIB_DIR="$( remove_slashes "${SHLIB_DIR}" )"
check_path_allowed "${SHLIB_DIR}" SHLIB_DIR

if [ -n "${3-}" ]; then
   X_SHLIBCC="$( remove_slashes "${3}" )"
   check_path_allowed "${X_SHLIBCC}" shlibcc
else
   X_SHLIBCC="/usr/bin/shlibcc"
fi



: ${WRAPPER_SHELL=}
case "${4-}" in
   ''|'sh'|'bash')
      SHLIBCC_SHELL="${4:-sh}"
      #WRAPPER_SHELL="/bin/${SHLIBCC_SHELL}"
   ;;
   *'/sh'|*'/bash')
      SHLIBCC_SHELL="${4##*/}"
      #WRAPPER_SHELL="${4}"
   ;;
   'ash'|'busybox ash')
      SHLIBCC_SHELL="ash"
      WRAPPER_SHELL="/bin/busybox ash"
   ;;
   *'/busybox ash'|*'/ash')
      SHLIBCC_SHELL="ash"
      WRAPPER_SHELL="${4}"
   ;;
   'dash')
      SHLIBCC_SHELL="sh"
      #WRAPPER_SHELL="/bin/dash"
   ;;
   *'/dash')
      SHLIBCC_SHELL="sh"
      #WRAPPER_SHELL="${4}"
   ;;
   /*)
      echo "unknown shell ${4}, using --shell sh" 1>&2
      SHLIBCC_SHELL="sh"
      #WRAPPER_SHELL="${4}"
   ;;
   *)
      die_usage "unknown shell ${4}: must be an absolute path"
   ;;
esac



case "${1:?}" in
   'default'|'shlibcc')
      gen_wrapper --stable-sort
   ;;
   'make'|'scriptgen')
      gen_wrapper --stable-sort --shell-opts u --depfile --main
   ;;
   *)
      die_usage "unknown wrapper type '${1}'"
   ;;
esac

