#!/bin/sh
# Usage:
#   generate... <src root> <dest root>
#               [<file install opts> [[<symlink cp opts> [<dir install opts>]]]
#
# Creates a script that recursively installs <src root> to <dest root>.
#
#
set -u
readonly IFS_DEFAULT="${IFS}"
readonly NEWLINE='
'
: ${INSTALL_MAXARGS:=30}
readonly INSTALL_MAXARGS


# @stdout void removes_slashes ( fspath )
#
remove_slashes() {
   echo "${1}" | sed -r -e 's,[/]+$,,' -e 's,[/]+,/,g'
}

gen_failscript() {
   local msg="${1-}"
   [ -n "${msg}" ] || msg="failed to create install script"
echo "#!/bin/sh
echo \"${msg}\" 1>&2
exit ${2:-2}"

   echo "${msg}" 1>&2
   exit ${2:-2}
}


if [ -z "${1-}" ] || [ -z "${2-}" ]; then
   gen_failscript "bad usage: missing src root and/or dest root"
fi

src_root="$(remove_slashes "${1}")"
: ${src_root:=/}
readonly src_root

dest_root="$(remove_slashes "${2}")"
: ${dest_root:=/}
readonly dest_root

readonly file_opts="${3:--m 644}"
readonly symlink_cp_opts="${4:-}"
readonly dir_opts="${5:--m 755}"


# int qoute_n_args_newline ( num, *argv )
#
#  Quotes up to %num args, one per line and returns the number of quoted args.
#
#  Note: %num has to be < 256
#
quote_n_args_newline() {
   local num="${1:?}"
   [ ${num} -gt 0 ] && shift || gen_failscript "invalid %num"

   if [ ${num} -gt ${#} ]; then
      local ret=${#}
      while [ ${#} -gt 0 ]; do
         echo -n " \\${NEWLINE}   ${1}"
         shift
      done
      return ${ret}

   else
      local low=$(( ${#} - ${num} ))
      while [ ${#} -gt ${low} ]; do
         echo -n " \\${NEWLINE}   ${1}"
         shift
      done
      return ${num}
   fi
}


# echo_command_with_destdir ( cmd, destdir, *src_list, **INSTALL_MAXARGS )
#
echo_command_with_destdir() {
   local cmd="${1:?}"
   local destdir="${2:?}"
   shift 2

   local IFS="${NEWLINE}"
   set -- ${*?}
   IFS="${IFS_DEFAULT}"

   while [ $# -gt 0 ]; do
      echo
      echo -n ${cmd} -t "\"${destdir}\"" --
      if quote_n_args_newline ${INSTALL_MAXARGS} "$@" || ! shift ${?}; then
         echo
         gen_failscript "out of bounds"
      else
         echo
      fi
   done
}


if [ "${NO_BASH:-n}" != "y" ]; then
gen_install__handle_item() {
   case "${name}" in
      'experimental'|'EXPERIMENTAL'|'no_install')
         return 1
      ;;
   esac
   if [ -b "${f}" ] || [ -c "${f}" ] || [ -p "${f}" ]; then
      echo "excluding ${f}: special file" 1>&2
   elif [ -h "${f}" ]; then
      symlinks="${symlinks}${NEWLINE}${f}"
   elif [ -f "${f}" ]; then
      files="${files}${NEWLINE}${f}"
   elif [ -d "${f}" ]; then
      dirs="${dirs}${NEWLINE}${name}"
   fi
}
else
gen_install__handle_item() {
   case "${name}" in
      'experimental'|'EXPERIMENTAL'|'no_install')
         return 1
      ;;
      *'.bash'|*'.bash.depend')
         true
      ;;
   esac
   if [ -b "${f}" ] || [ -c "${f}" ] || [ -p "${f}" ]; then
      echo "excluding ${f}: special file" 1>&2
   elif [ -h "${f}" ]; then
      symlinks="${symlinks}${NEWLINE}${f}"
   elif [ -f "${f}" ]; then
      files="${files}${NEWLINE}${f}"
   elif [ -d "${f}" ]; then
      dirs="${dirs}${NEWLINE}${name}"
   fi
}
fi # NO_BASH

# gen_install ( src_dir, dest_dir )
#
gen_install() {
   if [ -z "${1-}" ] || [ -z "${2+SET}" ]; then
      gen_failscript "gen_install(): bad usage"
   fi

   # symlink/file paths
   local symlinks=
   local files=
   # dir names
   local dirs=

   local f name
   for f in "${1}/"*; do
      name="${f##*/}"
      if ! gen_install__handle_item; then
         echo "excluding ${1}: blocked" 1>&2
         return 0
      fi
   done

   # filter out empty dirs
   if [ -z "${dirs}${files}${symlinks}" ]; then
      return 0
   fi


   echo
   echo "# ----- ${1} -----"
   echo INSTALL_DIRS "\"${2}\""

   if [ -n "${files}" ]; then
      echo_command_with_destdir INSTALL_FILES "${2}" "${files}"
   fi

   if [ -n "${symlinks}" ]; then
      echo_command_with_destdir INSTALL_SYMLINKS "${2}" "${symlinks}"
   fi

   if [ -n "${dirs}" ]; then
      local OLDIFS="${IFS}"
      local IFS="${NEWLINE}"
      for name in ${dirs}; do
         IFS="${OLDIFS}"
         if [ -n "${name}" ]; then
            gen_install "${1}/${name}" "${2}/${name}"
         fi
      done
      IFS="${OLDIFS}"
   fi
}



REF_ARGV="\"\${@}\""

echo "#!/bin/sh
set -eu
readonly DESTROOT=\"\${1:-${2}}\"
readonly LOGFILE=\"\${INSTALL_LOGFILE-}\"

die() { echo \"\${1:-died.}\" 1>&2; exit \${2:-2}; }

if [ -n \"\${LOGFILE}\" ]; then
: > \"\${LOGFILE}\"
run() {
   echo \"+ \${*}\" >> \"\${LOGFILE}\"
   ${REF_ARGV} || die \"command '\$*' returned \$?\" \$?
}
else
run() { ${REF_ARGV} || die \"command '\$*' returned \$?\" \$?; }
fi

INSTALL_DIRS() {
   run install -d ${dir_opts-} -- ${REF_ARGV}
}
INSTALL_FILES() {
   run install ${file_opts-} ${REF_ARGV}
}
INSTALL_SYMLINKS() {
   run cp -dpr --no-preserve=ownership ${symlink_cp_opts-} ${REF_ARGV}
}
"

gen_install "${src_root}" "\${DESTROOT}"
