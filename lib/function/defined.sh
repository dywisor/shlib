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
