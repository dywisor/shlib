#!/bin/sh

readonly NEWLINE="
"
readonly IFS_DEFAULT="${IFS}"
readonly IFS_NEWLINE="${NEWLINE}"

TEST_SHELLS=
for shell_name in bash ash dash; do
   if command -v "${shell_name}" 1>/dev/null 2>&1; then
      TEST_SHELLS="${TEST_SHELLS} ${shell_name}"
   fi
done
TEST_SHELLS="${TEST_SHELLS# }"
: ${TEST_SHELLS:=${SHELL:=/bin/sh}}

if [ "${VERBOSE:-n}" != "y" ]; then
   Q=true
else
   Q=
fi

die() {
   echo "${1:+died: }${1:-died.}" 1>&2
   exit ${2:-2}
}

foreach_test_shell() {
   : ${1:?}
   local shell

   [ $# -gt 1 ] || [ ! -f "${1}" ] || set -- -n "$@"
   for shell in ${TEST_SHELLS-}; do
      "${shell}" "$@" || return
   done
}


# iter_module_tree ( src_dir, dest_dir, **... )
#
iter_module_tree() {
   set -- "${1:?}" "${2:?}" "" "/"
   if ${F_ITER_FILTER_ROOT_DIR:-true} "$@"; then
      ${F_ITER_HANDLE_ROOT_DIR:-true} "$@"
      iter_module_tree__inner "$@"
   fi
}

# iter_module_tree__inner (
#    src_dir, dest_dir, relpath, name,
#    **F_ITER_FILTER_FILE:=true,
#    **F_ITER_FILTER_SYM:=false,
#    **F_ITER_FILTER_DIR:=default_dir_filter,
#    **F_ITER_HANDLE_FILE,
#    **F_ITER_HANDLE_SYM,
#    **F_ITER_HANDLE_DIR:=true
#
# )
#
iter_module_tree__inner() {
   local src_dir dst_dir relbase
   src_dir="${1:?}"
   dst_dir="${2:?}"
   relbase="${3:+${3%/}/}"

   local f name relname src dst

   ${F_ITER_HANDLE_DIR:-true} "$@" || return

   for f in "${src_dir}/"*; do
      name="${f##*/}"
      src="${f}"
      dst="${dst_dir}/${name}"
      relname="${relbase}${name}"

      set -- "${src}" "${dst}" "${relname}" "${name}"

      if [ -h "${f}" ]; then
         if ${F_ITER_FILTER_SYM:-false} "$@"; then
            ${F_HANDLE_SYM:?} "$@" || return
         fi

      elif [ -d "${f}" ]; then
         if ${F_ITER_FILTER_DIR:-default_dir_filter} "$@"; then
            iter_module_tree__inner "$@" || return
         fi

      elif [ -f "${f}" ]; then
         if ${F_ITER_FILTER_FILE:-true} "$@"; then
            ${F_ITER_HANDLE_FILE:?} "$@" || return
         fi


      fi
   done
}

default_dir_filter() {
   [ ! -e "${1}/no_install" ]
}


shfile_filter() {
   case "${name}" in
      *.sh)
         return 0
      ;;
   esac

   return 1
}

iter_makedir_parent() {
   case "${2}" in
      *?/*)
        mkdir -p -- "${2%/*}"
      ;;
   esac
}

default_main_func() {
   src_root_arg="${1:?<src root>?}"
   dst_root_arg="${2:?<dst root>?}"

   src_root="$(readlink -f "${src_root_arg}")"
   dst_root="$(readlink -f "${dst_root_arg}")"

   if [ -z "${src_root}" ]; then
      case "${src_root_arg}" in
         /*)
            src_root="${src_root_arg}"
         ;;
         *)
            die "failed to get src root"
         ;;
      esac
   fi

   if [ -z "${dst_root}" ]; then
      case "${dst_root_arg}" in
         /*)
            dst_root="${dst_root_arg}"
         ;;
         *)
            die "failed to get dst root"
         ;;
      esac
   fi


   shift 2 || return

   parse_argv_remainder "$@"

   iter_module_tree "${src_root}" "${dst_root}"
}
