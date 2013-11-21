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
