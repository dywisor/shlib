#@section module_init_vars
: ${__PRINTCMD_FD:=2}

#@section functions

print_cmd_to_stdout() {
   local v0
   get_cmd_str "$@" && printf "%s\n" "${v0}"
}

print_cmd() {
   print_cmd_to_stdout "$@" 1>&${__PRINTCMD_FD:?}
}


setup_print_cmd() {
   local k
   __PRINTCMD_FD="${2:-3}"

   case "${__PRINTCMD_FD}" in
      0|1|2)
         return 130
      ;;
      *[0-9])
         eval "exec ${__PRINTCMD_FD}>&-" || return
      ;;
   esac


   case "${1-}" in
      stdout|1)
         __PRINTCMD_FD=1
      ;;
      ''|stderr|2)
         __PRINTCMD_FD=2
      ;;
      /proc/self/fd/*)
         eval "exec ${__PRINTCMD_FD}>>\"${1}\""
      ;;
      '+'*/*)
         k="${1#+}"
         mkdir -p -- "${k%/*}" && \
         eval "exec ${__PRINTCMD_FD}>>\"${k}\""
      ;;
      '+'?*)
         eval "exec ${__PRINTCMD_FD}>>\"./${1#+}\""
      ;;
      */*)
         mkdir -p -- "${1%/*}" && \
         eval "exec ${__PRINTCMD_FD}>\"${1}\""
      ;;
      *)
         eval "exec ${__PRINTCMD_FD}>\"./${1}\""
      ;;
   esac
}
