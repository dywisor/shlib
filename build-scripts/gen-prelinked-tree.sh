#!/bin/sh
#  gen-prelinked-tree <src root> <dest root>
#    [target_shlib_modules:=$SHLIB_STATICLOADER_MODULES_ROOT]
#    [target_prelinked:=$SHLIB_STATICLOADER_PRELINKED_ROOT]
#
#  Creates a "prelinked" module tree, used by the static loader.
set -u

if [ -z "${SRCFUNC_FILE-}" ]; then
   . "${0%/*}/src-functions.sh" || exit 4
   SRCFUNC_FILE="${0%/*}/src-functions.sh"
else
   . "${SRCFUNC_FILE}" || exit 3
fi

readonly DEFAULT_TARGET_PRELINK_DIR='${SHLIB_STATICLOADER_PRELINKED_ROOT:?}'
readonly DEFAULT_TARGET_MODULES_DIR='${SHLIB_STATICLOADER_MODULES_ROOT:?}'

readonly EX_DEPTREE_CIRCULAR_ERROR=250
readonly EX_UNDEF_STATUS_ERROR=251
readonly EX_SELFLOAD_ERROR=252
readonly EX_DEPLOAD_ERROR=253
readonly EX_MODLOAD_ERROR=254

parse_argv_remainder() {
   case "${1-}" in
      '')
         target_prelink_dir="${DEFAULT_TARGET_PRELINK_DIR}"
      ;;
      @|_|-)
         target_prelink_dir="${dst_root:?}"
      ;;
      *)
         target_prelink_dir="${1}"
      ;;
   esac

   case "${2-}" in
      '')
         target_modules_dir="${DEFAULT_TARGET_MODULES_DIR}"
      ;;
      @|_|-)
         target_modules_dir="${src_root:?}"
      ;;
      *)
         target_modules_dir="${2}"
      ;;
   esac

   prelink_suffix="${3:-.prelink.sh}"
}

prelink_file_filter() {
   shfile_filter || return

   case "${relname}" in
      'liram/manage/main.sh')
         echo "EXCLUDING: ${relname} [dummy/blocker]" 1>&2
         return 1
      ;;
   esac

   return 0
}

prelink_handle_dir() {
   : ${target_prelink_dir:?}
   local ivar ivar_ref modload_block

   if [ -e "${1:?}/__all__.sh" ]; then
      echo "source dir ${1} has __all__.sh, cannot prelink dir!" 1>&2
      return 10
   fi

   mkdir -- "${2}" || return

   ivar=__shlib_dirdep
   ivar_ref="\${${ivar}}"

   modload_block="\
   for ${ivar} in \"${target_prelink_dir%/}/${3:+${3%/}}/\"*; do
      if [ -f \"${ivar_ref}/__all__${prelink_suffix}\" ]; then
         . \"${ivar_ref}/__all__${prelink_suffix}\" || exit ${EX_DEPLOAD_ERROR:?}
      elif [ -f \"${ivar_ref}\" ] && [ \"\${${ivar}%${prelink_suffix}}\" != \"${ivar_ref}\" ]; then
         . \"${ivar_ref}\" || exit ${EX_DEPLOAD_ERROR:?}
      fi
   done"

cat << EOF > "${2}/__all__${prelink_suffix}"
if [ -z "\${${ivar}__is_toplevel-}" ]; then
   ${ivar}__is_toplevel=true

   case "\$-" in
      *f*)
         ${ivar}__restore_noglob=true
         set +f
      ;;
      *)
         ${ivar}__restore_noglob=
      ;;
   esac

   ${modload_block#   }

   [ -z "\${${ivar}__restore_noglob-}" ] || set -f
   unset -v ${ivar}__restore_noglob
   unset -v ${ivar}__is_toplevel

else
   ${modload_block#   }
fi
EOF

}

prelink_handle_file() {
   case "${4}" in
      'experimental'|'EXPERIMENTAL')
         true
#         cp -- "${1}" "${2}" || return
      ;;
      *)
         prelink_shfile "$@" || return
      ;;
   esac
}

prelink_shfile__gen_includes() {
   local dep resolved_dep
   while read -r dep; do
      case "${dep}" in
         ''|[\#\!]*)
            # blockers could be implemented
            true
         ;;
         *)
            resolved_dep="${src_root}/${dep}"
            if [ -f "${resolved_dep}.sh" ]; then
               includes="${includes} ${dep}${prelink_suffix}"

            elif [ -d "${resolved_dep}" ]; then
               echo "WARN: dirdep ${resolved_dep}, needs to be resolved at runtime" 1>&2
               includes="${includes} ${resolved_dep}/__all__${prelink_suffix}"

            else
               echo "WARN: could not locate ${dep}, included by ${relname}" 1>&2
               includes="${includes} ${dep}${prelink_suffix}"
            fi
         ;;
      esac
   done < "${depfile}"
}

prelink_shfile() {
   : ${target_modules_dir:?} ${target_prelink_dir:?}

   local safe_name guardian guardian_ref includes_str I depfile
   local includes iter includes_str prelink_file

   safe_name="$(echo "${relname%.sh}" | sed -r -e 's@[/-]+@__@g')"
   : ${safe_name:?}
   guardian="__SHLIB_HAVE_${safe_name}__"
   guardian_ref="\${${guardian}-}"

   I="      "

   if [ -f "${src}.depend" ]; then
      depfile="${src}.depend"
   elif [ -f "${src%.sh}.depend" ]; then
      depfile="${src%.sh}.depend"
   else
      depfile=
   fi

   if [ -n "${depfile}" ]; then
      includes=
      if ! prelink_shfile__gen_includes "${depfile}"; then
         echo "failed to parse depfile ${depfile}" 1>&2
         return 9
      fi

      includes_str=
      for iter in ${includes}; do
         includes_str="\
${includes_str}${NEWLINE}${I}\
. \"${target_prelink_dir%/}/${iter}\" || exit ${EX_DEPLOAD_ERROR:?}"
      done

   else
      #includes_str="${NEWLINE}${I}# no deps"
      includes_str="${I}# no deps"
   fi

   ${Q} echo "processing ${relname} ..."

   prelink_file="${dst%.*sh}${prelink_suffix}"


cat << EOF > "${prelink_file}" || return
# module ${relname}
case "${guardian_ref}" in
   '')
      ${guardian}=depload
${includes_str}

      ${guardian}=loading
      . "${target_modules_dir%/}/${relname}" || exit ${EX_MODLOAD_ERROR:?}

      ${guardian}=loaded
   ;;
   loaded)
      true
   ;;
   loading)
      echo "module loads itself?" 1>&2
      exit ${EX_SELFLOAD_ERROR:?}
   ;;
   depload)
      echo "circular deptree for ${relname}!" 1>&2
      exit ${EX_DEPTREE_CIRCULAR_ERROR:?}
   ;;
   *)
      echo "unknown module status '${guardian_ref}' for module ${relname}!" 1>&2
      exit ${EX_UNDEF_STATUS_ERROR:?}
   ;;
esac
EOF
   foreach_test_shell "${prelink_file}" || return
}


F_ITER_FILTER_FILE=prelink_file_filter
F_ITER_FILTER_ROOT_DIR=true

F_ITER_HANDLE_FILE=prelink_handle_file
F_ITER_HANDLE_DIR=prelink_handle_dir
F_ITER_HANDLE_ROOT_DIR=iter_makedir_parent

default_main_func "$@"
