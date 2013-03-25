if [ -z "${__HAVE_SHLIB_DEFSYM__:-}" ]; then
readonly __HAVE_SHLIB_DEFSYM__=y

: ${DEVNULL:=/dev/null}

: ${LOGGER:=true}

readonly IFS_DEFAULT="${IFS}"
readonly IFS_NEWLINE='
'

fi
