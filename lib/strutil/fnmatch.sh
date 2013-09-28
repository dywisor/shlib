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

# int fnmatch_any ( str, *patterns )
#
#  Returns 0 if %str matches any of the given patterns, else 1.
#
fnmatch_any() {
   local word="${1?}"
   shift
   local pattern
   for pattern; do
      case "${word}" in
         ${pattern:?})
            return 0
         ;;
      esac
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
      case "${word}" in
         ${pattern:?})
            true
         ;;
         *)
            return 1
         ;;
      esac
   done
   return 0
}
