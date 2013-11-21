#@section functions

# int list_has ( word, *list_items )
#
#  Returns true if word is in list_items, else false.
#
list_has() {
   local kw="${1:?}"

   while [ $# -gt 0 ] && shift; do
      [ "x${kw}" != "x${1:-}" ] || return 0
   done
   return 1
}
