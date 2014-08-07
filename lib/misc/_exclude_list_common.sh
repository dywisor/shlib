#@section funcdef

#@result_var EXCLUDE_LIST

#@section functions

# @abstract @private void exclude_list_add_items_to_v0 (
#    sh_newline_list<items>, **v0!
# )
#

# @abstract void zap_exclude_list ( **EXCLUDE_LIST! )
#
#  Clears the exclude list.
#


# int exclude_list_create_item ( value, **EXCLUDE_LIST_WORD=, **item )
#
exclude_list_create_item() {
   if [ -n "${1}" ]; then
      item="${EXCLUDE_LIST_WORD}${NEWLINE}${1}"
      return 0
   else
      return 1
   fi
}

# void exclude_list_make_list (
#    *values, **F_CREATE_EXCLUDE_ITEM=exclude_list_create_item, **v0!
# )
#
exclude_list_make_list() {
   newline_list_init v0
   local item


   if [ $# -eq 0 ]; then
      return 1

   elif \
      [ -n "${F_CREATE_EXCLUDE_ITEM-}" ] || [ -n "${EXCLUDE_LIST_WORD-}" ]
   then
      while [ $# -gt 0 ]; do
         item=
         if ${F_CREATE_EXCLUDE_ITEM:-exclude_list_create_item} "${1}"; then
            exclude_list_add_items_to_v0 "${item}"
         fi
         shift
      done

   else
      v0="${1}"
      shift
      while [ $# -gt 0 ]; do
         exclude_list_add_items_to_v0 "${1}"
         shift
      done
   fi
}

# void exclude_list_add ( *values, **EXCLUDE_LIST_WORD, **EXCLUDE_LIST! )
#
exclude_list_add() {
   local v0 ret
   v0=()

   if exclude_list_make_list "$@"; then
      newline_list_add_list EXCLUDE_LIST v0; ret=${?}
   else
      newline_list_init EXCLUDE_LIST; ret=${?}
   fi

   newline_list_unset v0
   return ${ret}
}

# void exclude_list_append ( *values, **EXCLUDE_LIST_WORD, **EXCLUDE_LIST! )
#
exclude_list_append() {
   local v0 ret

   if exclude_list_make_list "$@"; then
      newline_list_append_list EXCLUDE_LIST v0; ret=${?}
   else
      newline_list_init EXCLUDE_LIST; ret=${?}
   fi

   newline_list_unset v0
   return ${ret}
}

# ~int exclude_list_call ( func, **EXCLUDE_LIST )
#
#  Calls %func ( <unpacked EXCLUDE_LIST> ) and returns the result.
#
exclude_list_call() {
   newline_list_call "${1:?}" EXCLUDE_LIST
}
