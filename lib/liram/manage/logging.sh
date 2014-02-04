#@section functions

# @logger       liram_manage_log()
# @logger DEBUG liram_manage_log_debug()
# @logger INFO  liram_manage_log_info()
# @logger WARN  liram_manage_log_warn()
# @logger ERROR liram_manage_log_error()

liram_manage_log()       { dolog +liram.manage "$@"; }
liram_manage_log_debug() { dolog +liram.manage "$@" --level=DEBUG; }
liram_manage_log_info()  { dolog +liram.manage "$@" --level=INFO;  }
liram_manage_log_warn()  { dolog +liram.manage "$@" --level=WARN;  }
liram_manage_log_error() { dolog +liram.manage "$@" --level=ERROR; }



