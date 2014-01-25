#@section functions

# @private int fs_walk__function_usable ( fname= )
#
fs_walk__function_usable() {
   case "${1-}" in
      ''|'true'|'false')
         return 1
      ;;
   esac
   return 0
}

# int fs_walk__visit (
#    **DIRPATH, **DIRNAMES, **FILENAMES,
#    **F_FS_WALK_VISIT, **F_FS_WALK_VISIT_FILE,
#    **F_FS_WALK_ON_ERROR,
# )
#
fs_walk__visit() {
   local rc=0
   local F_ITER_ON_ERROR="${F_FS_WALK_ON_ERROR?}"

   if fs_walk__function_usable "${F_FS_WALK_VISIT-}"; then
      ${F_FS_WALK_VISIT} "${DIRPATH}" || rc=1
   fi

   if fs_walk__function_usable "${F_FS_WALK_VISIT_FILE-}"; then
      newline_list_foreach FILENAMES "${F_FS_WALK_VISIT_FILE}" || \
         ${F_FS_WALK_ON_ERROR?}
   fi

   return ${rc}
}

# void fs_walk__get_visit_vars (
#    dir, parent, **DIRPATH!, **DIRNAMES!, **FILENAMES!, **DIRPATH_RELATIVE!
# )
#
fs_walk__get_visit_vars() {
   DIRPATH="${2-}${1:?}"
   case "${DIRPATH}" in
      "${FS_WALK_ROOT}")
         DIRPATH_RELATIVE='.'
      ;;
      *)
         DIRPATH_RELATIVE="${DIRPATH#${FS_WALK_ROOT%/}/}"
      ;;
   esac
   newline_list_init DIRNAMES
   newline_list_init FILENAMES

   ${F_FS_WALK_CHECK_RELPATH} "${DIRPATH_RELATIVE}" || return 1

   local fpath fname
   for fpath in "${DIRPATH}/"* "${DIRPATH}/."*; do
      fname="${fpath##*/}"
      case "${fname}" in
         '.'|'..')
            true
         ;;
         *)
            if [ -h "${fpath}" ]; then
               if [ ! -d "${fpath}" ]; then
                  newline_list_append FILENAMES "${fname}"
               elif [ "${FS_WALK_FOLLOW_SYMLINKS:?}" = "y" ]; then
                  newline_list_append DIRNAMES "${fname}"
               fi
            elif [ -d "${fpath}" ]; then
               newline_list_append DIRNAMES "${fname}"
            elif [ -e "${fpath}" ]; then
               newline_list_append FILENAMES "${fname}"
            fi
         ;;
      esac
   done
}

# int fs_walk__topdown ( dir, parent, (**DIRPATH!), (**DIRNAMES!), (**FILENAMES!) )
#
fs_walk__topdown() {
   local FS_WALK_DEPTH=$(( ${FS_WALK_DEPTH} + 1 ))
   local DIRPATH
   local DIRPATH_RELATIVE
   local DIRNAMES
   local FILENAMES

   fs_walk__get_visit_vars "$@" || return 0
   if fs_walk__visit; then
      newline_list_foreach DIRNAMES fs_walk__topdown "${DIRPATH%/}/" || ${F_FS_WALK_ON_ERROR?}
   fi
}

# int fs_walk__bottom_up ( dir, parent, (**DIRPATH!), (**DIRNAMES!), (**FILENAMES!) )
#
fs_walk__bottom_up() {
   local FS_WALK_DEPTH=$(( ${FS_WALK_DEPTH} + 1 ))
   local DIRPATH
   local DIRPATH_RELATIVE
   local DIRNAMES
   local FILENAMES

   fs_walk__get_visit_vars "$@" || return 0
   newline_list_foreach DIRNAMES fs_walk__bottom_up "${DIRPATH%/}/" || ${F_FS_WALK_ON_ERROR?}
   fs_walk__visit || true
}

# int fs_walk ( func=, top, topdown=y, onerror=true, followlinks=n, dir_relpath_filter=<none> )
#    (**F_ITER_ON_ERROR=%F_FS_WALK_ON_ERROR!)
#
fs_walk() {
   local F_FS_WALK_VISIT="${1:?}"
   local FS_WALK_ROOT="${2:?}"
   local topdown="${3:-y}"
   local F_FS_WALK_ON_ERROR="${4:-true}"
   local F_ITER_ON_ERROR="${F_FS_WALK_ON_ERROR}"
   local FS_WALK_FOLLOW_SYMLINKS="${5:-n}"
   local F_FS_WALK_CHECK_RELPATH="${6:-true}"

   local FS_WALK_DEPTH=-1

   if [ "${topdown}" = "y" ]; then
      with_globbing_do fs_walk__topdown "${FS_WALK_ROOT}"
   else
      with_globbing_do fs_walk__bottom_up "${FS_WALK_ROOT}"
   fi
}
