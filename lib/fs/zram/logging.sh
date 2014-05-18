#@section functions

# @logger zram_log ( <var args>, **ZRAM_DEV= )
#
zram_log() {
   ${LOGGER} +zram.${ZRAM_DEV:-main} "${@}"
}

# @logger INFO zram_log_info ( <var args>, **ZRAM_DEV= )
#
zram_log_info() {
   zram_log "${@}" --level=INFO
}

# @logger ERROR zram_log_error ( <var args>, **ZRAM_DEV= )
#
zram_log_error() {
   zram_log "${@}" --level=ERROR
}
