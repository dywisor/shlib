#@section functions

# int function_defined ( *func )
#
# Returns true if all listed functions are defined (as function), else
# false.
#
function_defined() {
   while [ $# -gt 0 ]; do
      if [ -n "${1-}" ]; then
         case $(LANG=C LC_ALL=C command -V "${1}" 2>/dev/null) in
            "${1} is a"*" function"*)
               # works with dash/ash/bash
               true
            ;;
            *)
               return 1
            ;;
         esac
      fi
      shift
   done
   return 0
}

# ~int call_if_defined ( func, *args )
#
#  Calls func( *args ) and passes its return value if %func is defined,
#  else returns 0.
#
#  %func must not be empty.
#
call_if_defined() {
   function_defined "${1:?}" || return 0
   "$@"
}

# ~int call_if_defined_else_false ( func, *args )
#
#  Calls func( *args ) and passes its return value if %func is defined,
#  else returns 1.
#
#  %func must not be empty.
#
call_if_defined_else_false() {
   function_defined "${1:?}" || return 1
   "$@"
}
