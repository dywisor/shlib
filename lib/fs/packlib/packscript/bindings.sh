#@HEADER
# This module inherits all pack modules and provides shortcut functions
# like next() and ex().
#

#@section functions_export

#@export all from lib/fs/packlib/*

#@section functions

# @private pack_bindings__eval_function_alias (
#    func, func_alias
# ), raises die()
#
#  Creates a pack function alias.
#  The %func_alias must not already exist.
#
pack_bindings__eval_function_alias() {
   if function_defined "${2:?}"; then
      function_die "function ${2} is already defined" "pack_function_alias"
   elif eval "${2}() { ${1:?} \"\${@}\"; }"; then
      return 0
   else
      function_die \
         "failed to create function alias ${2} (bad syntax?)" \
         "pack_function_alias"
   fi
}

# @private pack_bindings__check_function_defined ( func ), raises die()
#
#  Ensures that a function exists.
#
pack_bindings__check_function_defined() {
   if ! function_defined "${1:?}"; then
      function_die \
         "undefined pack function ${func}" "${2:-pack_bindings::<global>}"
   fi
}

# void pack_function_alias (
#    pack_func_name, *names=%pack_func_name
# ), raises die
#
#  Creates function aliases for "pack_"%pack_func_name().
#
pack_function_alias() {
   : ${1:?}
   local fname="${1#pack_}"
   : ${fname:?}
   local func="pack_${fname}"
   shift

   pack_bindings__check_function_defined "${func}" "pack_function_alias"

   if [ ${#} -eq 0 ]; then
      pack_bindings__eval_function_alias "${func}" "${fname}"
   else
      while [ ${#} -gt 0 ]; do
         case "${1}" in
            ''|'_FNAME_')
               pack_bindings__eval_function_alias "${func}" "${fname}"
            ;;
            '_______')
               # len("_FNAME_")
               true
            ;;
            *)
               pack_bindings__eval_function_alias "${func}" "${1}"
            ;;
         esac
         shift
      done
   fi
}


#@section module_init

fspath_bind_functions_if_required

# core: none

# exclude
pack_function_alias exclude_file     _FNAME_ exf  ex
pack_function_alias exclude_file_abs _FNAME_ exfa exa
pack_function_alias exclude_dir      _FNAME_ exd
pack_function_alias exclude_dir_abs  _FNAME_ exda

## TODO, shlibcc: dynamic_functions @section?
pack_bindings__check_function_defined pack_exclude_prefix_foreach
ex_foreach() {
   if [ -n "${EX_FUNC+SET}" ]; then
      local F_PACK_EXCLUDE="${EX_FUNC}"
   fi
   pack_exclude_prefix_foreach "$@"
}
pack_bindings__eval_function_alias ex_foreach ex_prefix_foreach

# genscript: none

# target_setup
pack_function_alias setup            _FNAME_
pack_function_alias zap_target_vars  _FNAME_
pack_function_alias init_target      _FNAME_ next
pack_function_alias register_target  _FNAME_
pack_function_alias declare_target   _FNAME_

init_tarball()  { pack_init_target "$@" as tarball; }
init_squashfs() { pack_init_target "$@" as squashfs; }

# vars: none
