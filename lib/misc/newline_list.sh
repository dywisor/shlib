#@section functions

# void newline_list_init ( varname, **$varname! )
#
newline_list_init() {
   : ${1:?}
   eval : "\${${1}=}"
}


# void newline_list_join ( *values, **v0! )
#
newline_list_join() {
   v0=
   if [ $# -gt 0 ]; then
      v0="${1}"
      shift
      while [ $# -gt 0 ]; do
         v0="${v0}${NEWLINE?}${1}"
         shift
      done
      return 0
   else
      return 1
   fi
}

# void newline_list_add_list ( varname, list )
#
newline_list_add_list() {
   : ${1:?}
   if eval test -z "\${${1}:+NOTEMPTY}"; then
      eval "${1}=\"${2}\""
   else
      eval "${1}=\"${2}${NEWLINE}\${${1}-}\""
   fi
}

# void newline_list_append_list ( varname, list )
#
newline_list_append_list() {
   : ${1:?}
   if eval test -z "\${${1}:+NOTEMPTY}"; then
      eval "${1}=\"${2}\""
   else
      eval "${1}=\"\${${1}}${NEWLINE?}${2}\""
   fi
}


# void newline_list_add ( varname, *values )
#
newline_list_add() {
   local v0
   local varname="${1:?}"
   shift

   if newline_list_join "$@"; then
      newline_list_add_list "${varname}" "${v0}"
   else
      eval : "\${${varname}=}"
   fi

   return 0
}

# void newline_list_append ( varname, *values )
#
newline_list_append() {
   local v0
   local varname="${1:?}"
   shift

   if newline_list_join "$@"; then
      newline_list_append_list "${varname}" "${v0}"
   else
      eval : "\${${varname}=}"
   fi

   return 0
}


# ~int newline_list_call ( func, varname )
#
#  Calls %func ( <unpacked list> ) and returns the result.
#
newline_list_call() {
   : ${1:?} ${2:?}
   local __OLDIFS="${IFS}"
   local __func="${1}"
   local __list
   eval "__list=\"\${${2}-}\""

   local IFS="${IFS_NEWLINE?}"
   set -- ${__list}
   IFS="${__OLDIFS}"
   unset -v __list __OLDIFS
   ${__func} "$@"
}
