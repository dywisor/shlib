#@section functions

# void pack_zap_target_vars()
#
pack_zap_target_vars() {
   PACK_NAME=
   PACK_SRC=
   PACK_TYPE=tar
   PACK_DESTFILE=
   PACK_TARGET_IS_VIRTUAL=
   zap_exclude_list
}

# void pack_register_target ( *target_name, **PACK_TARGETS! ), raises die()
#
#  Adds zero or more pack targets to the PACK_TARGETS variable.
#  Also verifies that the respective pack functions exist.
#
pack_register_target() {
   while [ ${#} -gt 0 ]; do
      if ! function_defined "pack_target_${1}"; then
         function_die "missing pack function for target '${1}'."
      elif list_has "${1}" ${PACK_TARGETS?}; then
         function_die "pack target '${1}' already registered."
      else
         PACK_TARGETS="${PACK_TARGETS}${PACK_TARGETS:+ }${1}"
      fi
      shift
   done
}

# void pack_declare_target ( *target ), raises die()
#
#  Ensures that pack functions for the given targets exist.
#
pack_declare_target() {
   while [ $# -gt 0 ]; do
      if ! function_defined "pack_target_${1}"; then
         function_die "missing pack function for target '${1}'."
      fi
      shift
   done
}

# void pack_init_target ( src_dir, <varargs> )
#
pack_init_target() {
   local rc=0
   local v0
   local doshift
   local exclude_sub_mounts=n

   pack_zap_target_vars
   pack_set_src_dir "${1?}"
   shift

   while [ $# -gt 0 ]; do
      doshift=1

      case "${1}" in
         'as'|'type')
            if [ -n "${2+SET}" ]; then
               pack_set_type "${2-}"
            else
               function_die "pack_init_target: expected arg for '${1}'."
            fi
            doshift=2
         ;;
         'name')
            if [ -n "${2-}" ]; then
               PACK_NAME="${2}"
            else
               function_die \
                  "pack_init_target: expected non-empty arg for '${1}'."
            fi
            doshift=2
         ;;
         '--no-xdev'|'+x')
            exclude_sub_mounts=n
         ;;
         '--xdev'|'-x')
            exclude_sub_mounts=y
         ;;
         *)
            function_die "unknown option/arg '${1}'"
         ;;
      esac
      [ ${doshift} -eq 0 ] || shift ${doshift}
   done

   : ${PACK_NAME:="${PACK_SRC##*/}"}

   pack_exclude_image_dir

   if [ "${exclude_sub_mounts}" = "y" ]; then
      pack_exclude_sub_mounts
   fi

   pack_get_destfile
   PACK_DESTFILE="${v0}"

   return 0
}

# void pack_virtual_target_done (
#    retcode=<auto>, **dopack_rc!, **PACK_TARGET_IS_VIRTUAL!
# )
pack_virtual_target_done() {
   local prev_rc=${?}
   dopack_rc="${1:-${prev_rc}}"
   PACK_TARGET_IS_VIRTUAL=y
}
