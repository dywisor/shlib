#@section functions

# @private void newline_list__filter_add ( ^func, item, *args, **filter_func, **item, **v0! )
#
newline_list__filter_add() {
   ! ${filter_func:?} "$@" || v0="${v0-}${v0:+${NEWLINE}}${item}"
}

# @private int newline_list__has_kw ( *values, **kw )
#
newline_list__has_kw() {
   #@varcheck_emptyok kw
   while [ ${#} -gt 0 ]; do
      [ "${1}" != "${kw}" ] || return 0
      shift
   done
   return 1
}

# void newline_list_init ( varname, **$varname! )
#
newline_list_init() {
   : ${1:?}
   eval : "\${${1}=}"
}

# void newline_list_init_empty ( varname, **$varname! )
#
newline_list_init_empty() {
   : ${1:?}
   eval "${1}="
}

# void newline_list_unset ( varname, **$varname! )
#
newline_list_unset() {
   unset -v ${1:?}
}

# void newline_list_copy ( src_list, dest_list="v0", **$dest_list! )
#
newline_list_copy() {
   eval ${2:-v0}="\${${1:?}?}"
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

# void newline_list_add_list ( varname, list_name )
#
newline_list_add_list() {
   : ${1:?}
   local __newline_list_tmplist

   if eval test -z "\${${1}:+NOTEMPTY}"; then
      newline_list_copy "${2:?}" "${1}"
   else
      newline_list_copy "${2:?}" __newline_list_tmplist
      eval "${1}=\"${__newline_list_tmplist}${NEWLINE}\${${1}-}\""
   fi
}

# void newline_list_append_list ( varname, list_name )
#
newline_list_append_list() {
   : ${1:?}
   local __newline_list_tmplist

   if eval test -z "\${${1}:+NOTEMPTY}"; then
      newline_list_copy "${2:?}" "${1}"
   else
      newline_list_copy "${2:?}" __newline_list_tmplist
      eval "${1}=\"\${${1}}${NEWLINE?}${__newline_list_tmplist}\""
   fi
}

# void newline_list_add ( varname, *values )
#
newline_list_add() {
   local v0
   local varname="${1:?}"
   shift

   if newline_list_join "$@"; then
      eval "${1}=\"${v0}${NEWLINE}\${${1}-}\""
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
      eval "${varname}=\"\${${varname}}${NEWLINE?}${v0}\""
   else
      eval : "\${${varname}=}"
   fi

   return 0
}

# int newline_list_foreach (
#    varname, ^func, *args, (**item!), (**index!), **F_ITER_ON_ERROR=return
# )
#
newline_list_foreach() {
   local index
   local item
   local my_list
   local OLDIFS="${IFS}"
   local func="${2:?}"

   newline_list_copy "${1:?}" my_list

   shift 2 || return

   index=0
   local IFS="${IFS_NEWLINE?}"
   for item in ${my_list}; do
      IFS="${OLDIFS}"
      ${func} "${item}" "$@" || ${F_ITER_ON_ERROR:-return}
      index=$(( ${index} + 1 ))
   done
   IFS="${OLDIFS}"
}

# void newline_list_filter_to_v0 ( varname, ^func, *args, **v0! )
#
newline_list_filter_to_v0() {
   v0=
   local src_list_name="${1:?}"
   local filter_func="${2:?}"
   shift 2 || return
   newline_list_foreach "${src_list_name}" "newline_list__filter_add" "$@"
}

# void newline_list_filter ( varname, ^func, *args, **$varname! )
#
#  Filters %varname and stores the resulting list in %varname.
#
newline_list_filter() {
   local v0
   newline_list_filter_to_v0 "$@"
   eval "${1:?}=\"${v0?}\""
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

# int newline_list_has ( word, varname )
#
newline_list_has() {
   ##linelist_has $1 $$2
   local kw="${1?}"
   newline_list_call newline_list__has_kw "${2:?}"
}

# int newline_list_get ( varname, index, **v0! )
#
newline_list_get() {
   v0=

   local OLDIFS="${IFS}"
   local my_list index
   index=$(( ${2:?} + 1 )) || return
   newline_list_copy "${1:?}" my_list

   local IFS="${IFS_NEWLINE}"
   set -- ${my_list}
   IFS="${OLDIFS}"

   if [ ${index} -le ${#} ]; then
      eval "v0=\"\${${index}?}\""
      return 0
   else
      return 1
   fi
}

# void newline_list_print ( varname )
#
newline_list_print() {
   local OLDIFS="${IFS}"
   local my_list list_name

   list_name="${1:?}"
   newline_list_copy "${list_name}" my_list
   IFS="${IFS_NEWLINE?}"
   set -- ${my_list}
   IFS="${OLDIFS}"

   echo "${list_name} = list<${*}>"
}
