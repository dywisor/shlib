#@section functions

# @private void daemonize__setup (
#    **X_START_STOP_DAEMON!, **START_STOP_DAEMON_OPTS!,
##    **START_STOP_DAEMON_START_OPTS!, **START_STOP_DAEMON_STOP_OPTS!
# )
#
#  Sets some variables.
#
daemonize__setup() {
   if [ -z "${X_START_STOP_DAEMON-}" ]; then
      if [ -x /sbin/start-stop-daemon ]; then
         X_START_STOP_DAEMON=/sbin/start-stop-daemon
      elif [ -x /usr/sbin/start-stop-daemon ]; then
         X_START_STOP_DAEMON=/usr/sbin/start-stop-daemon
      elif [ -x /bin/busybox ]; then
         X_START_STOP_DAEMON="/bin/busybox start-stop-daemon"
      else
         X_START_STOP_DAEMON=start-stop-daemon
      fi
   fi
   : ${START_STOP_DAEMON_OPTS=-q}
##  : ${START_STOP_DAEMON_START_OPTS=}
##  : ${START_STOP_DAEMON_STOP_OPTS=}
   return 0
}

# int daemonize_ssd (
#    *argv, **X_START_STOP_DAEMON, **START_STOP_DAEMON_OPTS=
# )
#
#  Calls start-stop-daemon.
#
daemonize_ssd() {
   ${X_START_STOP_DAEMON:?} ${START_STOP_DAEMON_OPTS-} "$@"
}

# int daemonize_command ( pidfile, *argv )
#
#  Calls start-stop-daemon for starting a command that usually runs in
#  foreground. Passes --background, --make-pidfile, --pidfile to s-s-d.
#
#  %argv can contain arbitrary start-stop-daemon opts, e.g. --exec.
#
daemonize_command() {
   : "${1:?}"
   daemonize_ssd -S -m -b ${START_STOP_DAEMON_START_OPTS-} -p "$@"
}

# int daemonize_stop ( pidfile, *argv, **START_STOP_DAEMON_STOP_OPTS= )
#
#  Stops a daemonized command.
#
daemonize_stop() {
   : "${1:?}"
   daemonize_ssd -K ${START_STOP_DAEMON_STOP_OPTS-} -p "$@"
}

# int daemonize_check_running (
#    pidfile, *argv, **START_STOP_DAEMON_STOP_OPTS=
# )
#
daemonize_check_running() {
   : "${1:?}"
   daemonize_ssd -K -t ${START_STOP_DAEMON_STOP_OPTS-} -p "$@"
}

# int daemonize_command_simple (
#    pidfile, exe, *argv, **START_STOP_DAEMON_START_OPTS=
# )
#
#  Like daemonize_command(), but does accepts command only (and not
#  s-s-d options).
#
#  This is identical to calling
#    daemonize_command ( pidfile, '--exec', exe, '--', exe, *argv )
#
daemonize_command_simple() {
   local pidfile="${1:?}"
   local exe="${2:?}"
   shift 2
   daemonize_ssd -S -m -b ${START_STOP_DAEMON_START_OPTS-} -p "${pidfile}"  \
      --exec "${exe}" -- "$@"
}

# int daemonize_stop_simple ( pidfile, exe, **START_STOP_DAEMON_STOP_OPTS= )
#
daemonize_stop_simple() {
   daemonize_ssd -K ${START_STOP_DAEMON_STOP_OPTS} -p "${1:?}" --exec "${2:?}"
}


#@section module_init
# @implicit void main()
#
daemonize__setup
