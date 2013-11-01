: ${VDR_RECORDHOOK_CONFFILE=/etc/vdr/recordhook.conf}

# ~int vdr_recordhook_main (
#    main_func, record_state, record_name, [record_new_name], *args
#    **$VDR_RECORD_VARS!
# )
#
vdr_recordhook_main() {
   local v0
   fspath_bind_functions_if_required

   if [ -n "${VDR_RECORDHOOK_CONFFILE-}" ]; then
      readconfig "${VDR_RECORDHOOK_CONFFILE}"
   fi

   if [ -n "${VDR_ROOT-}" ]; then
      get_fspath "${VDR_ROOT-}"
      VDR_ROOT="${v0}"
   fi

   if [ -n "${VDR_ROOT_DONE-}" ]; then
      get_fspath "${VDR_ROOT_DONE-}"
      VDR_ROOT_DONE="${v0}"
   fi

   local MAIN_FUNC="${1:?}"

   if \
      vdr_script_get_record_vars "${2-}" "${3-}" "${4-}" && \
      vdr_validate_record_vars
   then
      local S="${VDR_RECORD_DIR}"
      local PHASE="${VDR_RECORD_STATE}"
      shift 4
      ${MAIN_FUNC} "$@"
   else
      function_die \
         "error ${?} while getting record vars" "vdr_recordhook_main"
   fi
}
