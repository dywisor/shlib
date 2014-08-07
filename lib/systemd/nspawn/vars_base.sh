#@section module_vars

SYSTEMD_NSPAWN__LIST_NAMESPACE="systemd_nspawn_"
SYSTEMD_NSPAWN__LIST_VARS="bind tmpfs net misc"

#@section functions

# void systemd_nspawn_zap_vars ( **... )
#
systemd_nspawn_zap_vars() {
   local iter

   for iter in ${SYSTEMD_NSPAWN__LIST_VARS?}; do
      newline_list_init_empty "${SYSTEMD_NSPAWN__LIST_NAMESPACE}${iter}"
   done

   SYSTEMD_NSPAWN_ROOT_DIR=
   SYSTEMD_NSPAWN_ROOT_IMAGE=
}

# void eval_systemd_nspawn_list_var_functions ( *list_name )
#
eval_systemd_nspawn_list_var_functions() {
   local iter

   for iter; do
      # void systemd_nspawn_zap_<list_name>()
      eval "\
systemd_nspawn_zap_${iter}() {
   newline_list_init_empty \"\${SYSTEMD_NSPAWN__LIST_NAMESPACE}${iter}\"
}"

      # @private void systemd_nspawn__append_<list_name>(*items)
      eval "\
systemd_nspawn__append_${iter}() {
   newline_list_append \"\${SYSTEMD_NSPAWN__LIST_NAMESPACE}${iter}\" \"\${@}\"
}"

   done
}

# void systemd_nspawn_concat_call_args ( *list_name, **v0! )
#
systemd_nspawn_concat_call_args() {
   newline_list_init_empty v0

   if [ ${#} -eq 0 ] || [ "${1}" = "all" ]; then
      set -- ${SYSTEMD_NSPAWN__LIST_VARS?}
   fi

   while [ ${#} -gt 0 ]; do
      case "${1}" in
         ''|'none')
            true
         ;;
         *)
            newline_list_append_list v0 ${SYSTEMD_NSPAWN__LIST_NAMESPACE}${1}
         ;;
      esac
      shift
   done
}

# void systemd_nspawn_forge_call_args ( list_names, *args, **v0! )
#
systemd_nspawn_forge_call_args() {
   systemd_nspawn_concat_call_args "${1-}"

   if [ ${#} -gt 1 ]; then
      shift
      newline_list_append v0 "${@}"
   fi

   return 0
}

# int systemd_nspawn_call_forged ( func, **v0 )
#
systemd_nspawn_call_forged() {
   newline_list_call "${1:?}" v0
}


#@section module_init

eval_systemd_nspawn_list_var_functions ${SYSTEMD_NSPAWN__LIST_VARS}
systemd_nspawn_zap_vars
