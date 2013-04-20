after() {
   local v0 v1 recfile destfile destfile_next destdir i

   if vdr_get_record_files && [ "${v1}" -eq 1 ]; then
      recfile="${VDR_RECORD_DIR}/${v0}"
   elif [ -f "${VDR_RECORD_DIR?}/all.${VDR_RECORD_EXT#.}" ]; then
      recfile="${VDR_RECORD_DIR}/all.${VDR_RECORD_EXT#.}"
   else
      ${LOGGER} --level=WARN "cannot move files from ${VDR_RECORD_DIR}"
      return 2
   fi

   if [ -n "${VDR_ROOT_DONE-}" ]; then
      if [ ${VDR_RECORD_LEVEL} -lt 3 ] || [ -z "${VDR_RECORD_ROOT_ALT-}" ]; then
         destdir="${VDR_ROOT_DONE}/${VDR_RECORD_NAME}"
      else
         destdir="${VDR_ROOT_DONE}/${VDR_RECORD_ROOT##*/}"
      fi
   else
      destdir="${VDR_RECORD_ROOT}"
   fi


   destfile="${destdir}/${VDR_RECORD_DATE}"
   ${LOGGER} --level=DEBUG "VDR_RECORD_LEVEL=${VDR_RECORD_LEVEL-}"
#   if [ ${VDR_RECORD_LEVEL} -eq 1 ]; then
#      destfile="${destdir}/${VDR_RECORD_NAME}"
#   else
#      destfile="${destdir}/${VDR_RECORD_DATE}"
#   fi

   i=0
   destfile_next="${destfile}"
   while [ -e "${destfile_next}.${VDR_RECORD_EXT#.}" ]; do
      destfile_next="${destfile}-${i}"
      i=$(( ${i} + 1 ))
   done
   destfile="${destfile_next}.${VDR_RECORD_EXT#.}"

   ${LOGGER} --level=INFO "moving: ${recfile} => ${destfile}"
   if \
      run_cmd dodir_clean "${destfile%/*}" && \
      run_cmd mv -T -n -- "${recfile}" "${destfile}"
   then
      case "${VDR_RECORD_EXT#.}" in
         'vdr')
            (
               run_cmd rm -f -- "${VDR_RECORD_DIR}/info.vdr" "${VDR_RECORD_DIR}/index.vdr"
               if cd "${VDR_ROOT}" || cd "${VDR_RECORD_ROOT}"; then
                  run_cmd rmdir -p -- "${VDR_RECORD_DIR}"
               else
                  run_cmd rmdir -- "${VDR_RECORD_DIR}"
               fi
            ) || true
         ;;
         'ts')
            (
               run_cmd rm -f -- "${VDR_RECORD_DIR}/info" "${VDR_RECORD_DIR}/index"
               [ "${VDR_KEEP_SORT:-n}" = "y" ] || \
                  run_cmd rm -f -- "${VDR_RECORD_ROOT}/.sort"
               [ -e "${VDR_ROOT}/.keep" ] || run_cmd touch -- "${VDR_ROOT}/.keep"
               if cd "${VDR_ROOT}" || cd /tmp || cd /; then
                  run_cmd rmdir -p --ignore-fail-on-non-empty -- "${VDR_RECORD_DIR}" 2>/dev/null
               else
                  run_cmd rmdir --ignore-fail-on-non-empty -- "${VDR_RECORD_DIR}"
               fi
            ) || true
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
