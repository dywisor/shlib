#@section functions

# int dir_empty ( dir )
#
#  Returns true if the given directory is empty, else false.
#
dir_empty() {
   ! dir_not_empty "$@"
}

# int dir_not_empty ( dir )
#
#  Returns true if the given directory is not empty, else false.
#
dir_not_empty() {
   ls -A -1 -- "$@" | grep -q .
}
