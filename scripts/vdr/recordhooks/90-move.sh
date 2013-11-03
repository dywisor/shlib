# int vdr_recordhook_move_get_destdir ( **v0! )
#
vdr_recordhook_move_get_destdir() {
   : ${VDR_RECORD_NAME:?}
   v0=
   if [ -n "${VDR_ROOT_DONE-}" ]; then
      v0="${VDR_ROOT_DONE}/${VDR_RECORD_NAME}"
   else
      v0="${VDR_RECORD_ROOT}"
   fi
}

# int vdr_recordhook_move_get_recfile ( **v0! )
#
#  (1) use "all.<vdr record ext>" if available
#  (2) use any *.<vdr record ext> if there's exactly one such file
#  (3) abort otherwise
#
vdr_recordhook_move_get_recfile() {
   local v1
   v0=
   if [ -f "${VDR_RECORD_DIR?}/all.${VDR_RECORD_EXT#.}" ]; then
      v0="${VDR_RECORD_DIR}/all.${VDR_RECORD_EXT#.}"

   elif vdr_get_record_files && [ -n "${v1}" ] && [ ${v1} -eq 1 ]; then
      v0="${VDR_RECORD_DIR}/${v0}"

   else
      local err_msg="cannot move files from ${VDR_RECORD_DIR}"

      case "${v1}" in
         '')
            err_msg="${err_msg}: error while getting record files"
         ;;
         0)
            err_msg="${err_msg}: no record files found"
         ;;
         *)
            if [ ${v1} -gt 0 2>/dev/null ]; then
               err_msg="${err_msg}: too many record files found (${v1})"
            else
               err_msg="${err_msg}: undefined record file count '${v1}'"
            fi
         ;;
      esac

      ${LOGGER} --level=WARN "${err_msg}"
      return 2
   fi
}

# int vdr_recordhook_move_get_destfile ( destdir, **v0! )
#
#  destdir/(VDR_RECORD_DATE|VDR_RECORD_NAME)[-[0-9]+]VDR_RECORD_EXT
#
vdr_recordhook_move_get_destfile() {
   v0=
   local destfile destfile_next i i_prev

   destfile="${1:?}/${VDR_RECORD_DATE}"
   ${LOGGER} --level=DEBUG "VDR_RECORD_LEVEL=${VDR_RECORD_LEVEL-}"
#   if [ ${VDR_RECORD_LEVEL} -eq 1 ]; then
#      # one-time recording, usually a movie
#      destfile="${1:?}/${VDR_RECORD_NAME}"
#   else
#      destfile="${1:?}/${VDR_RECORD_DATE}"
#   fi

   i=0
   destfile_next="${destfile}"
   while [ -e "${destfile_next}.${VDR_RECORD_EXT#.}" ]; do
      destfile_next="${destfile}-${i}"

      i_prev=${i}
      i=$(( ${i} + 1 ))
      # check for overflow / wrap-around
      [ ${i} -gt ${i_prev} ] || die overflow
   done
   v0="${destfile_next}.${VDR_RECORD_EXT#.}"
}

# int vdr_recordhook_move_get_vars ( **recfile!, **destdir!, **destfile! )
#
vdr_recordhook_move_get_vars() {
   destdir=
   recfile=
   destfile=

   local v0

   vdr_recordhook_move_get_destdir || return
   destdir="${v0}"

   vdr_recordhook_move_get_recfile || return
   recfile="${v0}"

   vdr_recordhook_move_get_destfile "${destdir}" || return
   destfile="${v0}"
}


after() {
   local recfile destdir destfile
   vdr_recordhook_move_get_vars || return
   : ${recfile:?} ${destdir:?} ${destfile:?}

   ${LOGGER} --level=INFO "moving: ${recfile} => ${destfile}"
   if \
      run_cmd dodir_clean "${destfile%/*}" && \
      run_cmd mv -T -n -- "${recfile}" "${destfile}"
   then
      case "${VDR_RECORD_EXT#.}" in
         'vdr')
            vdr_remove_record_dir_files info.vdr index.vdr
            vdr_remove_record_dir
         ;;
         'ts')
            vdr_remove_record_dir_files info index

            if [ "${VDR_KEEP_SORT:-n}" != "y" ]; then
               run_cmd rm -f -- "${VDR_RECORD_ROOT}/.sort"
            fi

            vdr_remove_record_dir
         ;;
         *)
            ${LOGGER} --level=INFO \
               "Please clean up ${VDR_RECORD_DIR} manually."
         ;;
      esac
      return 0
   else
      return 40
   fi
}

info() {
   local recfile destdir destfile
   vdr_recordhook_move_get_vars || return
   : ${recfile:?} ${destdir:?} ${destfile:?}

   einfo "Would move ${recfile} => ${destfile}"
}
