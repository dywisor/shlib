#@section functions

liram_manage_please_dont_die() {
   local LIRAM_MANAGE_PLEASE_DONT_DIE=y
   "$@"
}


# int liram_manage_die ( message=, exit_code=, ... )
liram_manage_die() {
   if [ "${LIRAM_MANAGE_PLEASE_DONT_DIE:-n}" = "y" ]; then
      liram_manage_log_error "nonfatal-die: ${1:-<unknown>}"
      return ${2:-2}
   else
      die "$@"
   fi
}

# int liram_manage_autodie ( *cmdv, ... )
liram_manage_autodie() {
   if "$@"; then
      return 0
   else
      liram_manage_die "command '$*' returned ${?}." ${?}
   fi
}
