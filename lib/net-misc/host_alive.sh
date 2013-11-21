#@section functions

# int host_alive ( [sync_dir], *host_spec, **HOST_ALIVE_WAIT=2 )
#
#  Calls host_alive_multi ( sync_dir, *host_spec ) if the first arg starts
#  with '/', else calls host_alive_serial ( *host_spec ).
#
#  In any case, returns 0 if all given hosts are alive, else 1.
#
host_alive() {
   case "${1-}" in
      /*)
         host_alive_multi "$@"
      ;;
      *)
         host_alive_serial "$@"
      ;;
   esac
}

# int host_alive_serial ( *host_spec, **HOST_ALIVE_WAIT=2 )
#
#  Returns true (0) if all given hosts are alive (respond to ping),
#  else false. Returns on first failure.
#
#  Waits up to **HOST_ALIVE_WAIT (=2) seconds per host, resulting in
#  really long worst-case time requirements.
#  Use host_alive_multi() if you expect "many" hosts to be down / not pingable
#
host_alive_serial() {
   local wait=${HOST_ALIVE_WAIT:-2}
   while [ $# -gt 0 ]; do
      [ -z "${1-}" ] || host_alive__ping "${1}" "n" || return
      shift
   done
}

# int host_alive_multi ( sync_dir, *host_spec, **HOST_ALIVE_WAIT=2 )
#
#  Runs several host_alive checks in parallel and uses a filesystem directory
#  for synchronization.
#
#  The worst-case time requirements for this function are
#   **HOST_ALIVE_WAIT (=2) seconds + k,
#    where k is small (setup_time + sync_time)
#
#  Returns 0 if all hosts are alive, else 1.
#
host_alive_multi() {
   local wait=${HOST_ALIVE_WAIT:-2} sync_dir="${1:?}"
   shift
   dodir_clean "${sync_dir}" || die "cannot create sync dir"

   if [ $# -eq 1 ] && [ -n "${1-}" ]; then

      host_alive__coproc "${1}" "${sync_dir}/${1}"
      [ -e "${sync_dir}/${1}" ] || return 1

   else
      local host pids=

      # launch processes
      for host; do
         host_alive__coproc "${host}" "${sync_dir}/${host}" &
         pids="${pids} $!"
      done

      # wait for them
      for host in ${pids}; do
         wait ${host} || true
      done

      # sync / collect the result(s)
      for host; do
         [ -e "${sync_dir}/${host}" ] || return 1
      done
   fi

   return 0
}

# int host_alive__ping ( host, no_stderr=n, **wait )
#
#  This function actually pings a host.
#  Suppresses stderr if no_stderr is set to 'y'.
#
#  Returns 0 if the host sent a reply, else 1.
#
host_alive__ping() {
   : ${wait:?}
   if [ "${2:-n}" = "y" ]; then
      ping -w${wait} -W${wait} -c1 "${1}" 1>/dev/null 2>/dev/null
   else
      ping -w${wait} -W${wait} -c1 "${1}" 1>/dev/null
   fi || return 1
}

# ~int host_alive__coproc ( host, sync_file )
#
#  host_alive_multi() coprocess routine.
#
#  Creates sync_file if the given host responds to ping, else removes it.
#
host_alive__coproc() {
   if host_alive__ping "${1}" "y"; then
      touch "${2}"
   elif [ -e "${2}" ]; then
      rm "${2}"
   fi
}
