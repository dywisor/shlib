# this module provides one (or more) algorithms for sorting lists
#
# The default implementation is available via list_sort() (tries to determine
# a suitable comparator) and list_sort_comp() (uses first arg as comparator).
#
# Note: the default implementation uses a _stable_ sorting algorithm.
#
# Basic usage:
#
# list_sort 9 5 5 3 2 -> [ 2 3 5 5 9 ]
#
# function MY_COMP() { [ "${1%[a-z]}" -lt "${2%[a-z]}" ]; }
# list_sort_comp MY_COMP 9a 5b 5c 3d 2e -> [ 2e 3d 5b 5c 9a ]
#
#
## TODO: move generic list_* (len,partition,...) to a new module
#

# @funcdef shbool @sort_compare <function name> ( left, right )
#
#  sort_compare :: ( A, B ) -> Bool
#
#  Returns true if a is less than b, else false.
#

# @funcdef void @list_sort <function name> (
#    *list_item, **v0!, **F_SORT_COMPARE
# )
#
#  Sorts a list and stores the result in %v0.
#


# void list_len ( *list_item, **v0! )
#
#  Determines the length of the given list.
#
list_len() { v0="$#"; }

# void list_partition ( first_right_index, *list_item, **v0!, **v1! )
#
#  Splits the given list into two parts, with the right part
#  starting at first_right_index.
#
list_partition() {
   local M="${1:?}"
   shift
   v0=
   v1=
   local i=0
   while [ $# -gt 0 ] && [ ${i} -lt ${M} ]; do
      v0="${v0} ${1}"
      i=$(( ${i} + 1 ))
      shift
   done
   v0="${v0# }"
   v1="${*}"
}

# void list_split ( *list_item, **v0!, **v1! )
#
#  Splits a list into two lists of equal size, with the left
#  one having one element more on uneven list length.
#
list_split() {
   v0=
   list_len "$@"
   list_partition $(( ( ${#} + 1 ) / 2 )) "$@"
}

# void mergesort__sub ( *list_item, **__MERGESORT!, **F_SORT_COMPARE )
#
#  Performs the mergesort sorting algorithm on the given list.
#  The resulting list is stored in the %__MERGESORT variable.
#
#  For meaningful results, F_SORT_COMPARE has to be a @sort_compare function.
#
mergesort__sub() {
   if [ $# -lt 2 ]; then
      __MERGESORT="${*}"
   else
      local v0
      local v1
      list_split "$@"

      mergesort__sub ${v0}
      v0="${__MERGESORT}"

      mergesort__sub ${v1}
      v1="${__MERGESORT}"

      __MERGESORT=

      if [ -z "${v0-}" ]; then
         __MERGESORT="${v1-}"
      elif [ -z "${v1-}" ]; then
         __MERGESORT="${v0-}"
      else

         local item_v0
         local item_v1

         item_v1="${v1%% *}"
         for item_v0 in ${v0}; do
            while [ -n "${item_v1}" ] && \
               ${F_SORT_COMPARE} "${item_v1}" "${item_v0}"
            do
               __MERGESORT="${__MERGESORT} ${item_v1}"
               if [ "${item_v1}" = "${v1}" ]; then
                  # last item appended
                  v1=
                  item_v1=
               else
                  v1="${v1#* }"
                  item_v1="${v1%% *}"
               fi
            done

            __MERGESORT="${__MERGESORT} ${item_v0}"
         done

         if [ -n "${v1}" ]; then
            __MERGESORT="${__MERGESORT} ${v1}"
         fi
         __MERGESORT="${__MERGESORT# }"
      fi
   fi
}

# @sort_compare list_sort__int_compare :: ( int, int ) -> Bool
#
list_sort__int_compare() { [ ${1} -lt ${2} ]; }


# @list_sort mergesort ( *list_item, **v0!, **F_SORT_COMPARE )
#
mergesort() {
   v0=
   local __MERGESORT
   mergesort__sub "$@"
   v0="${__MERGESORT}"
}

# @list_sort list_sort_comp ( comparator, *list_item, **v0! )
#
#  Sorts a list using the given comparator function.
#
list_sort_comp() {
   local F_SORT_COMPARE="${1:?}"
   shift
   mergesort "$@"
}

# @list_sort list_sort ( comparator, *list_item, **v0! )
#
#  In addition to the list_sort_comp(),
#  this function supports symbolic comparator names and inferred comparators.
#
#  Comparator name mapping:
#
#  * int -> list_sort__int_compare()
#
#
#  Inferred comparators:
#
#  * first list item is an int -> list_sort__int_compare()
#
#
list_sort() {
   if [ "x${1-}" = "xint" ]; then
      shift
      local F_SORT_COMPARE=list_sort__int_compare
   elif is_int "${1-}"; then
      local F_SORT_COMPARE=list_sort__int_compare
   else
      local F_SORT_COMPARE="${1:?}"
      shift
   fi

   mergesort "$@"
}
