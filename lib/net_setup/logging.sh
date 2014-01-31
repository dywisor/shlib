#@section functions

net_setup_log() {
   dolog +net_setup "$@"
}
net_setup_log_error() {
   dolog +net_setup "$@" --level=ERROR
}
net_setup_log_warn() {
   dolog +net_setup "$@" --level=WARN
}
net_setup_log_debug() {
   dolog +net_setup "$@" --level=DEBUG
}
net_setup_log_info() {
   dolog +net_setup "$@" --level=INFO
}
