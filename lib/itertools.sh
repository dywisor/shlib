
# void generic_iterator (
#    item_separator, *words,
#    **F_ITER=echo, **ITER_SKIP_EMPTY=y, **ITER_UNPACK_ITEM=n,
#    **F_ITER_ON_ERROR=return
#
# )
# DEFINES @iterator <item_separator> <iterator_name>
#
#  Iterates over a list of items separated by item_separator.
#  All words are interpreted as "one big list".
#
#  Calls F_ITER ( item ) for each item and F_ITER_ON_ERROR() if F_ITER
#  returns a non-zero value.
#  The items will be unpacked if ITER_UNPACK_ITEM is set to 'y',
#  otherwise the item is interpreted as one word (default 'n').
#
#  Empty items will be ignored if ITER_SKIP_EMPTY is set to 'y', which
#  is the default behavior.
#
#  Examples: see the specific iterator functions below.
#
generic_iterator() {
   local IFS="${1?}"
   shift
   set -- $*
   IFS="${IFS_DEFAULT?}"
   local item
   for item; do
      if [ -z "${item}" ] && [ "${ITER_SKIP_EMPTY:-y}" = "y" ]; then
         true
      elif [ "${ITER_UNPACK_ITEM:-n}" = "y" ]; then
         ${F_ITER:-echo} ${item}   || ${F_ITER_ON_ERROR:-return}
      else
         ${F_ITER:-echo} "${item}" || ${F_ITER_ON_ERROR:-return}
      fi
   done
   return 0
}
# --- end of generic_iterator (...) ---

# void itertools_print_item ( *items )
#
#  Prints a string representation of zero or more items.
#  Meant for testing.
#
itertools_print_item() {
   if [ "x${*}" = "x${1:-}" ]; then
      echo "item<${*}>"
   else
      echo "items<${*}>"
   fi
}

# void eval_iterator ( func_name, item_separator )
#
#  Creates @iterator functions.
#
eval_iterator() {
   eval "${1:?}() { generic_iterator \"${2?}\" \"\$@\"; }"
}

# @iterator <newline> line_iterator
line_iterator() {
   generic_iterator "${IFS_NEWLINE?}" "$@"
}
# @iterator "," list_iterator
list_iterator() {
   generic_iterator "," "$@"
}
# @iterator ":" colon_iterator
colon_iterator() {
   generic_iterator ":" "$@"
}
# @iterator "." dot_iterator
dot_iterator() {
   generic_iterator "." "$@"
}
# @iterator <default> default_iterator
default_iterator() {
   generic_iterator "${IFS_DEFAULT?}" "$@"
}


# void generic_list_join (
#    item_separator, *items,
#    **LIST_JOIN_STDOUT=n, **LIST_JOIN_SKIP_EMPTY=y
# )
# DEFINES @list_join <item_separator> <function_name>
#
#  Joins zero or more items and stores the resulting list in %v0
#  if LIST_JOIN_STDOUT is not set to 'y', else echoes it.
#
generic_list_join() {
   local sep="${1?}" result=""
   shift
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ] || [ "${LIST_JOIN_SKIP_EMPTY:-y}" != "y" ]; then
         if [ -n "${result}" ]; then
            result="${result}${sep}${1}"
         else
            result="${1}"
         fi
      fi
      shift
   done
   if [ "${LIST_JOIN_STDOUT:-n}" = "y" ]; then
      echo "${result}"
   else
      v0="${result}"
   fi
}


# void eval_list_join ( func_name, item_separator )
#
#  Creates @list_join functions.
#
eval_list_join() {
   eval "${1:?}() { generic_iterator \"${2?}\" \"\$@\"; }"
}
