#@section functions

# @extern int fnmatch ( str, pattern )
#
#  Returns 0 if %str matches %pattern, else 1.
#

# int fnmatch_any ( str, *patterns )
#
#  Returns 0 if %str matches any of the given patterns, else 1.
#
fnmatch_any() {
   local word

   word="${1?}"; shift

   while [ $# -gt 0 ]; do
      if fnmatch "${word}" "${1}"; then
         return 0
      fi
      shift
   done

   return 1
}

# int fnmatch_in_any ( str, *pattern_list )
#
#  Returns 0 if %str matches any of the given patterns in any of the
#  given pattern lists, else 1.
#
#  This is identical to
#   fnmatch_any(%str, %plist) for each %plist in %pattern_lists,
#  but handles globbing (set -f/+f).
#
fnmatch_in_any() {
   local word must_unset_noglob

   word="${1:?}"; shift

   if check_globbing_enabled; then
      set -f
      must_unset_noglob=true
   else
      must_unset_noglob=false
   fi

   while [ ${#} -gt 0 ]; do
      if fnmatch_any "${word}" ${1}; then
         ! ${must_unset_noglob} || set +f
         return 0
      fi
      shift
   done

   ! ${must_unset_noglob} || set +f
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
   local word

   word="${1?}"; shift

   while [ $# -gt 0 ]; do
      if ! fnmatch "${word}" "${1}"; then
         return 1
      fi
      shift
   done

   return 0
}
