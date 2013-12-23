#@section functions

# int get_functrace ( **ftrace! )
#
get_functrace() {
   ftrace=
   set -- ${FUNCNAME[*]}
   while [[ ${#} -gt 1 ]] && shift; do
      case "${1}" in
         source|die__minimal|die__extended|die__function|die__autodie)
            ftrace+=" ((${1}))"
         ;;
         main)
            if [[ ${#} -eq 1 ]]; then
               ftrace+=" ((${1}))"
            else
               ftrace+=" ${1}"
            fi
         ;;
         *)
            ftrace+=" ${1}"
         ;;
      esac
   done
   ftrace="${ftrace# }"
   return 0
}

# void print_functrace ( message_function=**F_FUNCTRACE_MSG=ewarn )
#
#  Prints the function backtrace (this function excluded)
#  using a message function (see the message module).
#
print_functrace() {
   local ftrace
   get_functrace
   ${1:-${F_FUNCTRACE_MSG:-ewarn}} "${ftrace#print_functrace }" "[FUNCTRACE]"
}

#@section module_features
readonly FUNCTRACE_AVAILABLE=y
