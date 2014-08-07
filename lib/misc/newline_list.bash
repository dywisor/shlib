#@section functions

# @private int newline_list__check_if_set ( varname, do_init="" )
#
newline_list__check_if_set() {
   : ${1:?}

   local is_set

   eval "is_set=\"\${${1:?}[*]+YES}\""
   if [[ -n "${is_set}" ]]; then
      return 0
   else
      [[ -z "${2-}" ]] || declare -ga "${1}"
      return 1
   fi
}

# @private int newline_list__check_is_empty_but_set ( varname )
#
newline_list__check_is_empty_but_set() {
   : ${1:?}

   local is_set
   is_set="$(declare -p -- "${1}" 2>&-)"
   [[ ${?} -eq 0 ]] || return 2

   case "${is_set}" in
      'declare -a '"${1}"\=\'\(\)\'|\
      'declare -a'*' '"${1}"\=\'\(\)\')
         return 0
      ;;
      '')
         #@debug echo "BUG: successful declare should not produce empty %is_set" 1>&2
         return 3
      ;;
   esac

   return 1
}

# @private void newline_list__get_keys ( varname, **keys! )
#
newline_list__get_keys() {
   eval "keys=\"\${!${1:?}[@]}\""
}

# void newline_list_init ( varname, **$varname! )
#
newline_list_init() {
   declare -ga ${1:?}
}

# void newline_list_init_empty ( varname, **$varname! )
#
newline_list_init_empty() {
   declare -ga ${1:?} && eval "${1}=()"
}

# void newline_list_unset ( varname, **$varname! )
#
newline_list_unset() {
   unset -v ${1:?}
}

# void newline_list_copy ( src_list, dest_list="v0", **$dest_list! )
#
newline_list_copy() {
   if newline_list__check_if_set "${1}" y; then
      eval "${2:-v0}=( \"\${${1:?}[@]?}\" )"
   else
      newline_list_init_empty "${2:-v0}"
   fi
}

# void newline_list_join ( *values, **v0! )
#
newline_list_join() {
   newline_list_init v0
   v0=( "$@" )
}

# void newline_list_add_list ( varname, list_name )
#
newline_list_add_list() {
   newline_list_init ${1:?}

   if newline_list__check_is_empty_but_set "${2}"; then
      true
   elif newline_list__check_if_set "${1}" y; then
      eval "${1}=(  \"\${${2:?}[@]?}\" \"\${${1:?}[@]?}\" )"
   else
      eval "${1}=(  \"\${${2:?}[@]?}\" )"
   fi
   return 0
}

# void newline_list_append_list ( varname, list_name )
#
newline_list_append_list() {
   newline_list_init ${1:?}
   if ! newline_list__check_is_empty_but_set "${2}"; then
      eval "${1}+=( \"\${${2:?}[@]?}\" )"
   fi
   return 0
}

# void newline_list_add ( varname, *values )
#
newline_list_add() {
   local varname="${1:?}"
   shift

   newline_list_init ${varname}
   if newline_list__check_if_set "${varname}" y; then
      eval "${varname}=( \"\${@}\" \"\${${varname:?}[@]?}\" )"
   else
      eval "${varname}=( \"\${@}\" )"
   fi
   return 0
}

# void newline_list_append ( varname, *values )
#
newline_list_append() {
   local varname="${1:?}"
   shift

   newline_list_init ${varname}
   eval "${varname}+=( \"\${@}\" )"
   return 0
}

# int newline_list_foreach (
#    varname, ^func, *args, (**item!), (**index!), **F_ITER_ON_ERROR=return
# )
#
newline_list_foreach() {
   local -i index
   local item
   local list_name="${1:?}"
   local func="${2:?}"
   local -a f_args

   shift 2 || return
   newline_list__check_if_set "${list_name}" || return 0

   index=0
   if [[ ${#} -gt 0 ]]; then
      f_args=( "$@" )
      eval "set -- \"\${${list_name}[@]?}\""
      for item; do
         ${func} "${item}" "${f_args[@]}" || ${F_ITER_ON_ERROR:-return}
         ((index++)) || true
      done
   else
      eval "set -- \"\${${list_name}[@]?}\""
      for item; do
         ${func} "${item}" || ${F_ITER_ON_ERROR:-return}
         ((index++)) || true
      done
   fi
}

# void newline_list_filter_to_v0 ( varname, ^func, *args, **v0! )
#
newline_list_filter_to_v0() {
   newline_list_init v0
   v0=()

   local k
   local func="${2:?}"

   newline_list_copy "${1}" v0

   shift 2 || return

   for k in "${!v0[@]}"; do
      if ! ${func} "${v0[${k}]?}" "$@"; then
         unset -v "v0[${k}]"
      fi
   done
   return 0
}

# void newline_list_filter ( varname, ^func, *args, **$varname! )
#
newline_list_filter() {
   local k
   local keys
   local item
   local src_list_name="${1:?}"
   local func="${2:?}"

   shift 2 || return

   newline_list__get_keys "${src_list_name}"

   for k in ${keys}; do
      eval "item=\"\${${src_list_name}[${k}]?}\""
      if ! ${func} "${item}" "$@"; then
         unset -v "${src_list_name}[${k}]"
      fi
   done
   return 0
}

# ~int newline_list_call ( func, varname )
#
#  Calls %func ( <unpacked list> ) and returns the result.
#
newline_list_call() {
   local -a __list
   newline_list_copy "${2:?}" __list
   if [[ -n "${__list[*]+SET}" ]]; then
      set -- ${1:?} "${__list[@]}"
   else
      set -- ${1:?}
   fi
   unset -v __list
   "$@"
}

# int newline_list_has ( word, varname )
#
newline_list_has() {
   : ${1:?}
   local kw="${1?}"

   if newline_list__check_if_set "${2}"; then
      set -- "\${${2:?}[@]?}"
      while [[ ${#} -gt 0 ]]; do
         [[ "${1}" != "${kw}" ]] || return 0
         shift
      done
   fi
   return 1
}

# int newline_list_get ( varname, index, **v0! )
#
newline_list_get() {
   unset -v v0
   v0=
   local keys index_ref arr_index list_name

   list_name="${1?}"
   index_ref=$(( ${2:?} + 1 )) || return

   newline_list__get_keys "${list_name}"
   set -- ${keys}

   if [[ ${index_ref} -le ${#} ]]; then
      eval "arr_index=\"\${${index_ref}?}\""
      set -- "\${${list_name}[${arr_index}]?}"

      eval "v0=\"${1}\""
      return 0
   else
      return 1
   fi
}

newline_list_print() {
   : ${1:?}
   local list_str
   eval "list_str=\"\${${1:?}[*]-}\""
   echo "${1} = list<${list_str}>"
}
