#!/bin/bash

readonly RUNSCRIPT_EXE="$(readlink -f "${BASH_SOURCE}")"
: ${RUNSCRIPT_EXE:?}
readonly RUNSCRIPT_EXE_DIR="${RUNSCRIPT_EXE%/*}"
: ${RUNSCRIPT_EXE_DIR:?}

do_list_scripts=false
while [ ${#} -gt 0 ]; do
   case "${1}" in
      --)
         shift
         break
      ;;
      -l|--list-scripts)
         do_list_scripts=true
         shift
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

if [ -z "${SHLIB_ROOT}" ]; then
   SHLIB_ROOT="${RUNSCRIPT_EXE_DIR%/*}"
fi

SHLIB_SCRIPTS_DIR="${SHLIB_ROOT}/scripts"

if ${do_list_scripts}; then
   if cd "${SHLIB_SCRIPTS_DIR}" 2>/dev/null; then
      find . -type f -name '*.*sh' | \
         sed -nr -e 's,^[.]/(.*)[.].*?sh$,\1,p' | \
            sort -u
   else
      echo "scripts dir does not exist!" 1>&2
      exit 1
   fi

   exit 0
fi
unset -v do_list_scripts



if [ ${#} -eq 0 ] || [ -z "${1-}" ]; then
   echo "Usage: ${BASH_SOURCE##*/} [shell option...] <script relpath> [args...]" 1>&2
   exit 64
fi

RUNSCRIPT_SCRIPT_FILE=
f=
for f in \
   "${SHLIB_SCRIPTS_DIR}/${1}" \
   "${SHLIB_SCRIPTS_DIR}/${1}.bash" \
   "${SHLIB_SCRIPTS_DIR}/${1}.sh"
do
   if [ -f "${f}" ]; then
      RUNSCRIPT_SCRIPT_FILE="${f}"
      break
   fi
done
unset -v f

if [ -z "${RUNSCRIPT_SCRIPT_FILE}" ]; then
   echo "failed to locate script ${1} in ${SHLIB_SCRIPTS_DIR}!" 1>&2
   exit 240
fi

shift || exit
. "${RUNSCRIPT_EXE_DIR}/dynloader.bash" -- || exit 8
shlib_dynloader_runscript_inshell "${RUNSCRIPT_SCRIPT_FILE}" "${@}"
