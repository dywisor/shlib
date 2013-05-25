# void list_redux ( *list_item, **v0! )
#
#  Creates a new list %v0 that contains unique items taken from *list_item.
#  (One list iteration per item => O(n^2))
#
list_redux() {
   v0=
   while [ $# -gt 0 ]; do
      [ -z "${1}" ] || list_has "${1}" ${v0} || v0="${v0} ${1}"
      shift
   done
   v0="${v0# }"
}
