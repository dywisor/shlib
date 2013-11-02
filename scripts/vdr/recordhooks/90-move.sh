after() {
   local v0 v1 recfile destfile destfile_next destdir i i_prev

   # set %recfile
   # (1) use "all.<vdr record ext>" if available
   # (2) use any *.<vdr record ext> if there's exactly one such file
   # (3) abort otherwise
   #

   if [ -f "${VDR_RECORD_DIR?}/all.${VDR_RECORD_EXT#.}" ]; then
      recfile="${VDR_RECORD_DIR}/all.${VDR_RECORD_EXT#.}"

   elif vdr_get_record_files && [ "${v1}" -eq 1 ]; then
      recfile="${VDR_RECORD_DIR}/${v0}"

   else
      ${LOGGER} --level=WARN "cannot move files from ${VDR_RECORD_DIR}"
      return 2
   fi


   # set %destdir
   #
   #  TODO: describe how %destdir is set (and/or fix the code below)
   #

   if [ -n "${VDR_ROOT_DONE-}" ]; then
      if [ ${VDR_RECORD_LEVEL} -lt 3 ] || [ -z "${VDR_RECORD_ROOT_ALT-}" ]; then
         destdir="${VDR_ROOT_DONE}/${VDR_RECORD_NAME}"
      else
         destdir="${VDR_ROOT_DONE}/${VDR_RECORD_ROOT##*/}"
      fi
   else
      destdir="${VDR_RECORD_ROOT}"
   fi


   # set %destfile
   #  destdir/(VDR_RECORD_DATE|VDR_RECORD_NAME)[-[0-9]+]VDR_RECORD_EXT
   #

   destfile="${destdir}/${VDR_RECORD_DATE}"
   ${LOGGER} --level=DEBUG "VDR_RECORD_LEVEL=${VDR_RECORD_LEVEL-}"
#   if [ ${VDR_RECORD_LEVEL} -eq 1 ]; then
#      # one-time recording, usually a movie
#      destfile="${destdir}/${VDR_RECORD_NAME}"
#   else
#      destfile="${destdir}/${VDR_RECORD_DATE}"
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
   destfile="${destfile_next}.${VDR_RECORD_EXT#.}"

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
            ${LOGGER} --level=INFO "Please clean up ${VDR_RECORD_DIR} manually."
         ;;
      esac
      return 0
   else
      return 40
   fi
}
