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



filter_bash_lines() { grep -vE -- "^[^#].*[.]bash([.]depend)?"; }

quote_args() {
   while [ $# -gt 0 ]; do
      echo -n " \"${1}\""
      shift
   done
}

echo_ftype() {
   echo "echo \"${1?}\" \"${2?}\""
}

# echo_dir ( dest )
echo_dir() {
   echo -n install -d ${dir_opts-} --
   quote_args "${1?}"
   echo
   echo_ftype D "${1?}"
}

# echo_file ( src, dest )
echo_file() {
   echo -n install -T ${file_opts-} --
   quote_args "${1?}" "${2?}"
   echo
   echo_ftype F "${2?}"
}

# echo_symlink ( src, dest )
echo_symlink() {
   echo -n cp -dpr --no-preserve=ownership ${symlink_cp_opts-} --
   quote_args "${1?}" "${2?}"
   echo
   echo_ftype L "${2?}"
}


# gen_install ( src_dir, dest_dir )
#
gen_install() {
   if [ -z "${1-}" ] || [ -z "${2+SET}" ]; then
      gen_failscript "gen_install(): bad usage"
   fi

   local files=
   local dirs=
   local symlinks=
   local f name

   for f in "${1}/"*; do
      name="${f##*/}"
      if [ -b "${f}" ] || [ -c "${f}" ] || [ -p "${f}" ]; then
         echo "cannot install special file '${f}'" 1>&2
      elif [ -h "${f}" ]; then
         symlinks="${symlinks}${NEWLINE}${name}"
      elif [ -f "${f}" ]; then
         files="${files}${NEWLINE}${name}"
      elif [ -d "${f}" ]; then
         dirs="${dirs}${NEWLINE}${name}"
      fi
   done

   # filter out empty dirs
   if [ -z "${files}${dirs}${symlinks}" ]; then
      return 0
   fi

   echo
   echo "# ----- ${1} -----"
   echo_dir "${2}"


   local OLDIFS="${IFS}"
   local IFS="${IFS}"

   if [ -n "${files}" ]; then
      echo
      echo "# files"
      IFS="${NEWLINE}"
      for name in ${files}; do
         if [ -n "${name}" ]; then
            echo_file "${1}/${name}" "${2}/${name}"
         fi
      done
      IFS="${OLDIFS}"
   fi

   if [ -n "${symlinks}" ]; then
      echo
      echo "# symlinks"
      IFS="${NEWLINE}"
      for name in ${symlinks}; do
         if [ -n "${name}" ]; then
            echo_symlink "${1}/${name}" "${2}/${name}"
         fi
      done
      IFS="${OLDIFS}"
   fi

   if [ -n "${dirs}" ]; then
      IFS="${NEWLINE}"
      for name in ${dirs}; do
         IFS="${OLDIFS}"
         if [ -n "${name}" ]; then
            gen_install "${1}/${name}" "${2}/${name}"
         fi
      done
      IFS="${OLDIFS}"
   fi
}

echo "#!/bin/sh
set -eu

readonly DESTROOT=\"\${1:-${2}}\""

if [ "${NO_BASH:-n}" = "y" ]; then
   gen_install "${src_root}" "\${DESTROOT}" | filter_bash_lines
else
   gen_install "${src_root}" "\${DESTROOT}"
fi
