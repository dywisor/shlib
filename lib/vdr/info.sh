: ${VDR_RECORD_EXT=ts}

VDR_RECORD_VARS_NONEMPTY="
VDR_INITIAL_PWD
VDR_RECORD_STATE
VDR_RECORD_DIR
VDR_RECORD_ROOT
VDR_RECORD_DATE
VDR_RECORD_EXT
VDR_RECORD_NAME"

VDR_RECORD_VARS_EMPTYOK="
VDR_RECORD_NEW_DIR
VDR_RECORD_ROOT_ALT
VDR_RECORD_DATE_APPEND
VDR_RECORD_LEVEL"

VDR_RECORD_VARS="${VDR_RECORD_VARS_NONEMPTY}
${VDR_RECORD_VARS_EMPTYOK}"



# @extern int vdr_get_record_files (
#    type="default"
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT, **v0!, **v1!
# )
#
#  Searches for record files in VDR_RECORD_DIR and stores their names in v0.
#  Also counts the # of record files and stores the result in v1.
#

# void vdr_validate_record_vars(), raises die()
#
vdr_validate_record_vars() {
   local badvars=
   local v0 vname

   for vname in ${VDR_RECORD_VARS_NONEMPTY?}; do
      var_is_set_nonempty "${vname}" || badvars="${badvars} ${vname}"
   done

   for vname in ${VDR_RECORD_VARS_EMPTYOK?}; do
      var_is_set "${vname}" || badvars="${badvars} ${vname}"
   done

   if [ -n "${badvars# }" ]; then
      function_die \
         "invalid vars detected:${badvars}" "vdr_validate_record_vars"
   else
      return 0
   fi
}


# int vdr_guess_record_root_vars (
#   record_dir, **VDR_ROOT,
#   **VDR_RECORD_ROOT!, **VDR_RECORD_ROOT_ALT!, **VDR_RECORD_NAME!
# )
#
vdr_guess_record_root_vars() {
   local record_parent_dir="${VDR_RECORD_DIR%/*}"
   local need_record_root_fallback=0

   if [ -n "${VDR_ROOT-}" ]; then
      case "${record_parent_dir}" in
         ''|/)
            # (a) invalid
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#a"
            return 50
         ;;
         "${VDR_ROOT}")
            # (b) <vdr root>/<record dir>
            #
            #  Not likely.
            #
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#b"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_ROOT="${VDR_RECORD_DIR}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         #"${VDR_ROOT}"/?*/?*/_)
         #   # (c) <vdr root>/{.../}/_/<record dir>
         #   # handle differently
         #;;

         "${VDR_ROOT}"/?*/_)
            # <vdr root>/{.../}/_/<record dir>
            #
            # (d) common case: <vdr root>/<record root>/_/<record dir>
            #
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#d"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_ROOT="${record_parent_dir%/*}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         "${VDR_ROOT}"/?*/?*)
            # (e) <vdr root>/.../.../<record dir>
            #
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#e"
            VDR_RECORD_ROOT_ALT="${record_parent_dir%/*}"
            VDR_RECORD_ROOT="${record_parent_dir}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         "${VDR_ROOT}"/?*)
            # (f) <vdr root>/.../<record dir> (depth=1)
            #
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#f"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_ROOT="${record_parent_dir}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         *)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): VDR_ROOT#fail"
            need_record_root_fallback=1
         ;;
      esac
   else
      need_record_root_fallback=1
   fi

   if [ ${need_record_root_fallback} -eq 1 ]; then
      case "${record_parent_dir}" in
         ''|/)
            # (a)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): FALLBACK#a"
            return 51
         ;;

         ?*/?*/_)
            # (d)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): FALLBACK#d"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_ROOT="${record_parent_dir%/*}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         ?*/?*/?*)
            # (e)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): FALLBACK#e"
            VDR_RECORD_ROOT_ALT="${record_parent_dir%/*}"
            VDR_RECORD_ROOT="${record_parent_dir}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         ?*/?*)
            # (f)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): FALLBACK#f"
            VDR_RECORD_ROOT_ALT=
            VDR_RECORD_ROOT="${record_parent_dir}"
            VDR_RECORD_NAME="${VDR_RECORD_ROOT##*/}"
         ;;

         *)
            ${LOGGER} --level=DEBUG "vdr_guess_record_root_vars(): FALLBACK#fail"
            return 52
         ;;
      esac
   fi

   return 0
}

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
   local v0

   # zap vars
   VDR_INITIAL_PWD="${PWD}"
   VDR_RECORD_STATE=
   VDR_RECORD_NEW_DIR=
   #VDR_RECORD_DIR=
   VDR_RECORD_ROOT=
   VDR_RECORD_ROOT_ALT=
   VDR_RECORD_DATE=
   VDR_RECORD_DATE_APPEND=
   VDR_RECORD_NAME=

   get_fspath "${1}"
   VDR_RECORD_DIR="${v0}"

   # @ASSERT fs_level ( VDR_RECORD_DIR ) > 1

   if \
      [ -d "${VDR_RECORD_DIR}" ] && \
      vdr_guess_record_root_vars "${VDR_RECORD_DIR}"
   then
      # <yyyy-mm-dd>.<HH.MM._-_>.rec
      #
      #  <VDR_RECORD_DATE>.[<VDR_RECORD_DATE_APPEND>.][.rec]
      #
      v0="${VDR_RECORD_DIR##*/}"
      VDR_RECORD_DATE="${v0%%.*rec}"
      v0="${v0#*.}"
      VDR_RECORD_DATE_APPEND="${v0%.rec}"

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

      if \
         [ -n "${VDR_ROOT-}" ] && \
         get_fslevel_diff "${VDR_ROOT}" "${VDR_RECORD_DIR}"
      then
         VDR_RECORD_LEVEL="${v0}"
      else
         VDR_RECORD_LEVEL=
      fi

   else
      # zap vars that might have been set, just to be sure
      # (vdr_guess_record_root_vars() doesn't set these vars if there is
      #  an error, so zapping here is not neccessary)
      #
      VDR_RECORD_ROOT=
      VDR_RECORD_ROOT_ALT=
      VDR_RECORD_NAME=
   fi
}

# void vdr_script_get_record_vars (
#    record_state, record_dir, [record_new_dir],
#    **VDR_RECORD_STATE!, **VDR_RECORD_NEW_DIR!
# )
#
#  Sets all vdr record hook variables.
#
vdr_script_get_record_vars() {
   local v0
   vdr_get_record_vars "${2:?}"

   VDR_RECORD_STATE="${1-}"
   if [ -n "${3-}" ]; then
      get_fspath "${3}"
      VDR_RECORD_NEW_DIR="${v0}"
   else
      VDR_RECORD_NEW_DIR=
   fi

}
