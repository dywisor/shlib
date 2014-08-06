#@section functions

# @logger zram_log ( <var args>, **ZRAM_NAME= )
#
zram_log() {
   ${LOGGER} +zram.${ZRAM_NAME:-main} "${@}"
}

# @logger DEBUG zram_log_debug ( <var args>, **ZRAM_NAME= )
#
zram_log_debug() {
   zram_log "${@}" --level=DEBUG
}

# @logger INFO zram_log_info ( <var args>, **ZRAM_NAME= )
#
zram_log_info() {
   zram_log "${@}" --level=INFO
}

# @logger WARN zram_log_warn ( <var args>, **ZRAM_NAME= )
#
zram_log_warn() {
   zram_log "${@}" --level=WARN
}

# @logger ERROR zram_log_error ( <var args>, **ZRAM_NAME= )
#
zram_log_error() {
   zram_log "${@}" --level=ERROR
}

# @logger "/dev/null" zram_log_null ( *ignored, **ZRAM_NAME= )
#
zram_log_null() {
   return 0
}
