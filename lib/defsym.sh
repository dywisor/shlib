#@section vars
: ${DEVNULL:=/dev/null}
: ${LOGGER:=true}

#@section const
readonly IFS_DEFAULT="${IFS}"
readonly IFS_NEWLINE='
'
readonly NEWLINE="${IFS_NEWLINE}"

readonly EX_OK=0
readonly EX_ERR=1
readonly EX_USAGE=64
readonly ERR_FUNC_UNDEF=101

#@section functions

# int __run__ ( *cmdv )
#
#  Simply runs *cmdv.
#
__run__() { "$@"; }

# int __not__ ( *cmdv )
#
#  Runs *cmdv and returns the negated returncode (1 on success, else 0).
#
__not__() { ! "$@"; }
