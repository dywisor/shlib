#@section functions

# int fnmatch ( str, pattern )
#
#  Returns 0 if %str matches %pattern, else 1.
#
fnmatch() {
   case "${1}" in
      ${2:?})
         return 0
      ;;
      *)
         return 1
      ;;
   esac
}
