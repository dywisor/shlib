#@section functions

# int unless_exists ( fs_item, *cmdv )
#
#  Runs cmdv if fs_item does not exist.
#
unless_exists() {
   if [ -e "${1:?}" ]; then
      return 0
   else
      shift
      "$@"
   fi
}

# int unless_exists_implicit ( *cmdv )
#
#  Runs cmdv if cmdv [1] (second arg) does not exist.
#
unless_exists_implicit() {
   [ -e "${2:?}" ] || "$@"
}
