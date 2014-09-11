#@section functions

# int fnmatch ( str, pattern )
#
#  Returns 0 if %str matches %pattern, else 1.
#
fnmatch() {
   [[ "${1}" == ${2:?} ]]
}
