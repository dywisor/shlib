if [ -z "${__HAVE_SHLIB_DEFSYM__:-}" ]; then
readonly __HAVE_SHLIB_DEFSYM__=y

: ${DEVNULL:=/dev/null}

: ${LOGGER:=true}

readonly IFS_DEFAULT="${IFS}"
readonly IFS_NEWLINE='
'

readonly EX_OK=0
readonly EX_ERR=1
readonly EX_USAGE=64

fi
