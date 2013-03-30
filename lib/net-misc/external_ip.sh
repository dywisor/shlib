# @private ~int external_ip__default_wget ( remote_uri, num_matches=1 )
#
#  Prints up to num_matches ip addresses read from remote_uri to stdout.
#
external_ip__default_wget() {
   ## the regex is a bit lenient but should suffice
   local d3='[[:digit:]]{1,3}'
   wget -U "" -q -O - -- "${1:?}" | \
      grep -E -o -m ${2:-1} -- "${d3}[.]${d3}[.]${d3}[.]${d3}"
}

# ~int print_external_ip ( impl="dyndns" )
#
#  Get your external ip address using the specified method/implementation.
#
#  Available get methods are:
#  * dyndns, 1, 0      -- get ip from dyndns.org
#  * wieistmeineip, 2  -- get ip from wieistmeineip.de
#
print_external_ip() {
   case "${1-}" in
      ''|'dyndns'|'1'|'0')
         external_ip__default_wget 'http://checkip.dyndns.org/index.html'
      ;;
      'wieistmeineip'|'2')
         external_ip__default_wget 'http://www.wieistmeineip.de'
      ;;
      *)
         if [ "${HAVE_MESSAGE_FUNCTIONS:-y}" = "y" ]; then
            eerror "unknown external_ip get() method '${1}'"
         else
            echo "unknown external_ip get() method '${1}'" 1>&2
         fi
         return 5
      ;;
   esac
}

# int get_external_ip ( impl=<try all until success>, **v0! )
#
#  Gets the external ip and stores it in %v0.
#  Returns 0 on success, else 1.
#
get_external_ip() {
   if [ -z "${1-}" ]; then
      get_external_ip "1" || get_external_ip "2"
   else
      v0=`print_external_ip "$@"`
      [ -n "${v0-}" ]
   fi
}
