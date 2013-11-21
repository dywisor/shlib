#@section functions

# void list_redux ( *list_item, **v0! )
#
#  Creates a new list %v0 that contains unique items taken from *list_item.
#  (One list iteration per item => O(n^2))
#
list_redux() {
   v0=
   local k
   local is_new

   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         is_new=1
         for k in ${v0}; do
            if [ "${k}" = "${1}" ]; then
               is_new=0
               break
            fi
         done
         [ ${is_new} -ne 1 ] || v0="${v0} ${1}"
      fi
      shift
   done
   v0="${v0# }"
}
