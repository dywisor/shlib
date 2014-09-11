#@section functions

# @extern int fnmatch        ( str, pattern )
# @extern int fnmatch_any    ( str, *patterns )
# @extern int fnmatch_in_any ( str, *pattern_list )
# @extern int fnmatch_none   ( str, *patterns )
# @extern int fnmatch_all    ( str, *patterns )


# int if_fnmatch_do ( value, pattern_list, func, *args )
#
#  Calls func(*args) uf fnmatch_in_any(value,pattern_list) evaluates to true.
#
if_fnmatch_do() {
   : ${1:?} ${2?} ${3:?}

   if fnmatch_in_any "${1}" "${2?}"; then
      shift 2 || die
      "$@"    || return ${?}
   fi

   return 0
}

# int if_fnmatch_var_do ( varname, pattern_list, func, *args )
#
#  Same as if_fnmatch_do(), but takes a variable name as first arg.
#
if_fnmatch_var_do() {
   : ${1:?}
   local __value
   eval "__value=\"\${${1}?}\""

   if fnmatch_in_any "${__value}" "${2?}"; then
      shift 2
      "$@" || return ${?}
   fi

   return 0
}
