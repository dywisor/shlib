#!/bin/bash

readonly RUNSCRIPT_EXE="$(readlink -f "${BASH_SOURCE}")"
: ${RUNSCRIPT_EXE:?}
readonly RUNSCRIPT_EXE_DIR="${RUNSCRIPT_EXE%/*}"
: ${RUNSCRIPT_EXE_DIR:?}


while [ ${#} -gt 0 ]; do
   case "${1}" in
      --)
         shift
         break
      ;;
      -*)
         set "${1}"
         shift
      ;;
      *)
         break
      ;;
   esac
done

if [ -z "${SHLIB_ROOT-}" ]; then
   SHLIB_ROOT="${RUNSCRIPT_EXE_DIR%/*}"
fi

if [ ${#} -eq 0 ] || [ -z "${1-}" ]; then
   echo "Usage: ${BASH_SOURCE##*/} [shell option...] <script file> [args...]" 1>&2
   exit 64
fi

. "${RUNSCRIPT_EXE_DIR}/dynloader.bash" -- || exit 8
shlib_dynloader_runscript_inshell "${@}"
