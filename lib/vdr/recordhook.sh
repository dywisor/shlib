# @extern @noreturn die ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#

# @extern void get_fspath ( fspath, **v0! )
#
#  Stores the realpath of %fspath in %v0 if it is non-empty,
#  and the abspath otherwise.
#

# @extern int vdr_get_record_files (
#    type="default"
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT, **v0!, **v1!
# )
#
#  Searches for record files in VDR_RECORD_DIR and stores their names in v0.
#  Also counts the # of record files and stores the result in v1.
#

# @extern void vdr_get_record_vars (
#    record_dir,
#    **VDR_INITIAL_PWD!, **VDR_RECORD_STATE!, **VDR_RECORD_NEW_DIR!,
#    **VDR_RECORD_DIR!,
#    **VDR_RECORD_ROOT!, **VDR_RECORD_ROOT_ALT!,
#    **VDR_RECORD_DATE!, VDR_RECORD_DATE_APPEND!, **VDR_RECORD_NAME!
# )
#
#  Sets all vdr record_dir-related variables.
#

# @extern void vdr_script_get_record_vars (
#    record_state, record_dir, [record_new_dir],
#    **VDR_RECORD_STATE!, **VDR_RECORD_NEW_DIR!
# )
#
#  Sets all vdr record hook variables.
#

# @extern void vdr_validate_record_vars(), raises die()
#

# str|<empty> VDR_RECORDSCRIPT_CONFFILE
#
#  Config file that is loaded in vdr_recordscript_init().
#  The file has to exist.
#
#  Defaults to "/etc/vdr/recordhook.conf".
#
: ${VDR_RECORDSCRIPT_CONFFILE=/etc/vdr/recordhook.conf}

# list VDR_FSPATH_VARS
#
#  A whitespace-separated list of variables whose values should be converted
#  into absolute filesystem paths using get_fspath() from fs/path.
#
#
#  Defaults to "VDR_ROOT VDR_ROOT_DONE".
#
: ${VDR_FSPATH_VARS="VDR_ROOT VDR_ROOT_DONE"}

# list VDR_SCRIPT_VARS
#
#  A whitespace-separated list of variables that must be set and not empty
#  after loading VDR_RECORDSCRIPT_CONFFILE (even if no file loaded).
#
: ${VDR_SCRIPT_VARS=}

# list VDR_SCRIPT_VARS
#
#  A whitespace-separated list of variables that must be set and are allowed
#  to be empty after loading VDR_RECORDSCRIPT_CONFFILE
#  (even if no file loaded).
#
: ${VDR_SCRIPT_VARS_EMPTYOK=}

# void vdr_recordscript_init (
#    **VDR_RECORDSCRIPT_CONFFILE=,
#    **VDR_FSPATH_VARS=, **VDR_SCRIPT_VARS=, **VDR_SCRIPT_VARS_EMPTYOK=,
# ), raises die()
#
#  Reads %VDR_RECORDSCRIPT_CONFFILE and sets/validates variables.
#
vdr_recordscript_init() {
   local v0 varname
   fspath_bind_functions_if_required

   if [ -n "${VDR_RECORDSCRIPT_CONFFILE-}" ]; then
      readconfig "${VDR_RECORDSCRIPT_CONFFILE}"
   fi

   for varname in ${VDR_FSPATH_VARS-}; do
      loadvar_lazy "${varname}"
      if [ -n "${v0}" ]; then
         get_fspath "${v0}"
         setvar "${varname}" "${v0}"
      fi
   done

   if [ -n "${VDR_SCRIPT_VARS-}" ]; then
      varcheck_forbid_empty ${VDR_SCRIPT_VARS}
   fi

   if [ -n "${VDR_SCRIPT_VARS_EMPTYOK-}" ]; then
      varcheck_allow_empty ${VDR_SCRIPT_VARS_EMPTYOK}
   fi

   return 0
}

# ~int vdr_recordhook_main (
#    main_func, record_state, record_name, [record_new_name], *args
#    **$VDR_RECORD_VARS!
# ), raises function_die()
#
vdr_recordhook_main() {
   : ${1:?}
   vdr_recordscript_init

   if \
      vdr_script_get_record_vars "${2-}" "${3-}" "${4-}" && \
      vdr_validate_record_vars
   then
      local MAIN_FUNC="${1}"
      local S="${VDR_RECORD_DIR}"
      local PHASE="${VDR_RECORD_STATE}"
      shift 4
      ${MAIN_FUNC} "$@"
   else
      function_die \
         "error ${?} while getting record vars" "vdr_recordhook_main"
   fi
}
