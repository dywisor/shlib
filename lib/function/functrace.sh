# void print_functrace ( message_function=**F_FUNCTRACE_MSG=ewarn )
#
#  Function stub since %FUNCNAME is not available in sh.
#
print_functrace() {
   ${1:-${F_FUNCTRACE_MSG:-eerror}} "not available" "[FUNCTRACE]"
}

readonly FUNCTRACE_AVAILABLE=n
