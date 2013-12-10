#@section vars
CMDWRAPPER_INDENT="   "
CMDWRAPPER_INDENT_NOW=""

#@section functions

# @private @stdout int cmdwrapper__quote_n_args (
#    join_seq, n, *args
# ), raises die()
#
#  Quotes up to %num args using the given sequence for separating the args
#  and returns the number of quoted args.
#
#  Note: %num has to be < 256.
#
cmdwrapper__quote_n_args() {
   local seq="${1?}"
   local num="${2:?}"
   [ ${num} -gt 0 ] && shift 2 || function_die

   if [ ${num} -gt ${#} ]; then
      local ret=${#}
      while [ ${#} -gt 0 ]; do
         printf "${seq}\"${1}\""
         shift
      done
      return ${ret}
   else
      local low=$(( ${#} - ${num} ))
      while [ ${#} -gt ${low} ]; do
         printf "${seq}\"${1}\""
         shift
      done
      return ${num}
   fi
}

# @private @stdout void cmdwrapper__quote_args ( join_seq, *args )
#
#
cmdwrapper__quote_args() {
   local seq="${1?}"
   shift
   while [ ${#} -gt 0 ]; do
      printf "${seq}\"${1}\""
      shift
   done
}

# @private @stdout void cmdwrapper__quote_cmdv ( arg_join_seq, cmd, *args )
#
cmdwrapper__quote_cmdv() {
   : ${1?} ${2?}
   local seq="${1}"
   printf "${CMDWRAPPER_INDENT_NOW-}\"${2}\""
   shift 2
   while [ ${#} -gt 0 ]; do
      printf "${seq}\"${1}\""
      shift
   done
}

# @private int cmdwrapper__newline_seq_do ( func, *args )
#
#  Calls %func(<newline join seq>, *args) and returns the result.
#
cmdwrapper__newline_seq_do() {
   local func="${1:?}"
   shift
   "${func}" " \\${NEWLINE}${CMDWRAPPER_INDENT_NOW-}${CMDWRAPPER_INDENT?}" "$@"
}

# @stdout void quote_args ( *args )
#
quote_args() {
   while [ ${#} -gt 0 ]; do
      printf " \"${1}\""
      shift
   done
}

# @stdout int quote_n_args ( num, *args )
#
quote_n_args() {
   cmdwrapper__quote_n_args " " "$@"
}


# @stdout void quote_args_newline ( *args )
#
quote_args_newline() {
   cmdwrapper__newline_seq_do cmdwrapper__quote_args "$@"
}

# @stdout int quote_n_args_newline ( num, *args )
#
#  Quotes up to %num args, one per line and returns the number of quoted args.
#
#  Note: %num has to be < 256.
#
quote_n_args_newline() {
   cmdwrapper__newline_seq_do cmdwrapper__quote_n_args "$@"
}

# @stdout void quote_cmdv ( prog, *args )
#
quote_cmdv() {
   cmdwrapper__quote_cmdv " " "$@"
}

# @stdout void quote_cmdv_newline ( prog, *args )
#
quote_cmdv_newline() {
   cmdwrapper__newline_seq_do cmdwrapper__quote_cmdv "$@"
}
