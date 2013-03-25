# void print_functrace ( message_function=**F_FUNCTRACE_MSG=ewarn )
#
#  Prints the function backtrace (this function excluded)
#  using a message function (see the message module).
#
print_functrace() {
   local ftrace="${FUNCNAME[*]}" kw
   ftrace=" ${ftrace#${FUNCNAME} } "
   for kw in 'source'; do
      ftrace="${ftrace// ${kw} / ((${kw})) }"
   done
   ftrace="${ftrace# }"
   ${1:-${F_FUNCTRACE_MSG:-ewarn}} "${ftrace}" "[FUNCTRACE]"
}
