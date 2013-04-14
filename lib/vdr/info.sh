: ${VDR_RECORD_EXT=ts}

VDR_RECORD_VARS="
VDR_INITIAL_PWD
VDR_RECORD_STATE
VDR_RECORD_NEW_DIR
VDR_RECORD_DIR
VDR_RECORD_ROOT
VDR_RECORD_ROOT_ALT
VDR_RECORD_DATE
VDR_RECORD_DATE_APPEND
VDR_RECORD_NAME
VDR_RECORD_EXT
"

# void vdr_get_record_vars (
#    record_dir,
#    **VDR_INITIAL_PWD!, **VDR_RECORD_STATE!, **VDR_RECORD_NEW_DIR!,
#    **VDR_RECORD_DIR!,
#    **VDR_RECORD_ROOT!, **VDR_RECORD_ROOT_ALT!,
#    **VDR_RECORD_DATE!, VDR_RECORD_DATE_APPEND!, **VDR_RECORD_NAME!
# )
#
#  Sets all vdr record_dir-related variables.
#
vdr_get_record_vars() {
   : ${1:?}
   # zap vars
   VDR_INITIAL_PWD="${PWD}"
   VDR_RECORD_STATE=
   VDR_RECORD_NEW_DIR=

   VDR_RECORD_DIR=`readlink -f "${1}"`

   # @ASSERT fs_level ( VDR_RECORD_DIR ) > 1

   if [ -d "${VDR_RECORD_DIR}" ]; then
      local n="${VDR_RECORD_DIR##*/}"
      VDR_RECORD_DATE="${n%%.*rec}"
      VDR_RECORD_DATE_APPEND="${n#*.}"
      VDR_RECORD_DATE_APPEND="${VDR_RECORD_DATE_APPEND%.rec}"

      n="${VDR_RECORD_DIR%/*}"
      case "${n##*/}" in
         '')
            VDR_RECORD_ROOT=
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_NAME=
            return 50
         ;;
         '_')
            VDR_RECORD_ROOT="${n%/*}"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;
         *)
            VDR_RECORD_NAME="${n##*/}"
            # this function cannot know which RECORD_ROOT is correct
            VDR_RECORD_ROOT="${n%/*}"

            if [ -n "${VDR_ROOT-}" ]; then
               if [ "${VDR_ROOT}" = "${VDR_RECORD_ROOT}" ]; then
                  VDR_RECORD_ROOT="${n}"
                  VDR_RECORD_ROOT_ALT=
               else
                  VDR_RECORD_ROOT_ALT="${n}"
               fi
            else
               VDR_RECORD_ROOT_ALT="${n}"
            fi
         ;;
      esac

      case "${VDR_RECORD_DATE}" in
         [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
            # should be a date
            true
         ;;
         *)
            VDR_RECORD_DATE=
            VDR_RECORD_DATE_APPEND=
         ;;
      esac

      local v0

      if \
         [ -n "${VDR_ROOT-}" ] && \
         get_fslevel_diff "${VDR_RECORD_DIR}" "${VDR_ROOT}"
      then
         VDR_RECORD_LEVEL="${v0}"
      else
         VDR_RECORD_LEVEL=-1
      fi

   else
      VDR_RECORD_ROOT=
      VDR_RECORD_ROOT_ALT=
      VDR_RECORD_DATE=
      VDR_RECORD_DATE_APPEND=
      VDR_RECORD_NAME=
      VDR_RECORD_LEVEL=-10
   fi
}

# void vdr_script_get_record_vars (
#    record_state, record_dir, [record_new_dir]
# )
#
#  Sets all vdr record hook variables.
#
vdr_script_get_record_vars() {
   vdr_get_record_vars "${2:?}"

   VDR_RECORD_STATE="${1-}"
   if [ -n "${3-}" ]; then
      VDR_RECORD_NEW_DIR=`readlink -f "${3}"`
   else
      VDR_RECORD_NEW_DIR=
   fi

}

# @private void vdr__print_record_file_names (
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT
# )
#
vdr__print_record_file_names() {
   (
      cd "${VDR_RECORD_DIR}" && \
      case "${VDR_RECORD_EXT#.}" in
         'ts')
            echo [0-9][0-9][0-9][0-9][0-9]*.ts
         ;;
         'vdr')
            echo [0-9][0-9][0-9]*.vdr
         ;;
         *)
            echo *.${VDR_RECORD_EXT#.}
         ;;
      esac
   )
}

# void vdr_get_record_files (
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT, **v0!, **v1!
# )
#
#  Searches for record files in VDR_RECORD_DIR and stores their name in v0.
#  Also counts the # of record files and stores the result in v1.
#
vdr_get_record_files() {
   : ${VDR_RECORD_DIR?} ${VDR_RECORD_EXT?}
   v0=
   v1=
   set -- `vdr__print_record_file_names`
   local f i=0
   for f; do
      [ -f "${VDR_RECORD_DIR}/${f}" ] || return 1
      i=$(( ${i} + 1 ))
   done
   v0="$*"
   v1="${i}"
}
