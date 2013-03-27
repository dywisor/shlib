# int dir_empty ( dir )
#
#  Returns true if the given directory is empty, else false.
#
dir_empty() {
   local tmp=`ls -A -1 -- "$@"`
   [ -z "${tmp}" ]
}

# int dir_not_empty ( dir )
#
#  Returns true if the given directory is not empty, else false.
#
dir_not_empty() {
   ! dir_empty "$@"
}
