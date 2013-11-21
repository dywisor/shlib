#@section functions_public

# int fnmatch ( str, pattern )
#
#  Returns 0 if %str matches %pattern, else 1.
#
fnmatch() {
   [[ "${1}" == ${2:?} ]]
}

# int fnmatch_any ( str, *patterns )
#
#  Returns 0 if %str matches any of the given patterns, else 1.
#
fnmatch_any() {
   local word="${1?}"
   shift
   local pattern
   for pattern; do
      [[ "${word}" != ${pattern:?} ]] || return 0
   done
   return 1
}

# int fnmatch_none ( str, *patterns )
#
#  Returns 0 if %str matches none of the given patterns, else 1.
#
fnmatch_none() { ! fnmatch_any "$@"; }

# int fnmatch_all ( str, *patterns )
#
#  Returns 0 if %str matches all of the given patterns, else 1.
#
fnmatch_all() {
   local word="${1?}"
   shift
   local pattern
   for pattern; do
      [[ "${word}" == ${pattern:?} ]] || return 1
   done
   return 0
}
