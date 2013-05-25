#!/bin/sh
# compat wrapper that calls dobuild-ng (which will soon be renamed to dobuild)
#
NEXT="${0%/*}/build-scripts/buildvars.sh"
case "${1?}" in
   '-f'|'--force')
      a0="${1?}"; a1="${2?}"; a2="${3?}"; shift 3
      exec "${NEXT}" "${a0}" "${a1}" "${a2}" --chainload dobuild-ng "$@"
   ;;
   *)
      a0="${1?}"; a1="${2?}"; shift 2
      exec "${NEXT}" "${a0}" "${a1}" --chainload dobuild-ng "$@"
   ;;
esac
